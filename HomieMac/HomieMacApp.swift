import SwiftUI
import AppKit
import HomeKit

@main
struct HomieMacApp: App {
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Menu bar app
        MenuBarExtra {
            MacMenuBarView()
                .environmentObject(appDelegate.homeKitManager)
                .environmentObject(appDelegate.ruleEngine)
                .environmentObject(appDelegate.homieState)
                .environmentObject(appDelegate.appMonitor)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: appDelegate.homieState.securityCompromised ? "house.fill" : "house")
                    .symbolRenderingMode(.hierarchical)
                if appDelegate.homeKitManager.devices.filter({ $0.isOn }).count > 0 {
                    Text("\(appDelegate.homeKitManager.devices.filter({ $0.isOn }).count)")
                        .font(.caption2)
                }
            }
        }
        
        // Settings window
        Settings {
            MacSettingsView()
                .environmentObject(appDelegate.homeKitManager)
                .environmentObject(appDelegate.ruleEngine)
                .environmentObject(appDelegate.appMonitor)
        }
    }
}

// MARK: - Mac App Delegate

class MacAppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let homeKitManager = HomeKitManager()
    let appMonitor = MacAppMonitor()
    let ruleEngine: RuleEngine
    let homieState = HomieState()
    var httpServer: HTTPServer?
    
    override init() {
        self.ruleEngine = RuleEngine(homeKitManager: homeKitManager)
        super.init()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request HomeKit authorization
        homeKitManager.requestAuthorization { [weak self] success in
            if success {
                self?.homeKitManager.loadDevices()
                self?.homeKitManager.loadScenes()
            }
        }
        
        // Start HTTP server
        httpServer = HTTPServer(homeKitManager: homeKitManager, ruleEngine: ruleEngine)
        httpServer?.start()
        
        // Start app monitoring for context-aware scenes
        appMonitor.onAppChange = { [weak self] bundleId, appName in
            self?.ruleEngine.evaluateAppChange(bundleId: bundleId, appName: appName)
            
            // Update Homie's mood based on activity
            DispatchQueue.main.async {
                self?.homieState.currentMood = .excited
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self?.homieState.currentMood = .happy
                }
            }
        }
        appMonitor.start()
        
        // Security check
        performSecurityAudit()
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.performSecurityAudit()
        }
        
        NSLog("[Homie Mac] Started successfully")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        httpServer?.stop()
        appMonitor.stop()
    }
    
    private func performSecurityAudit() {
        SecurityAuditor.checkPortExposure(port: 8420) { [weak self] isExposed in
            DispatchQueue.main.async {
                self?.homieState.securityCompromised = isExposed
                if isExposed {
                    NSLog("[Homie] ⚠️ SECURITY WARNING: Port 8420 appears to be exposed!")
                }
            }
        }
    }
}

// MARK: - Security Auditor

struct SecurityAuditor {
    static func checkPortExposure(port: UInt16, completion: @escaping (Bool) -> Void) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-i", ":\(port)", "-P", "-n"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            let isExposed = output.contains("*:\(port)") || 
                           output.contains("0.0.0.0:\(port)")
            
            completion(isExposed)
        } catch {
            completion(false)
        }
    }
}
