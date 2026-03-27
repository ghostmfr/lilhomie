import UIKit
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    let homeKitManager = HomeKitManager()
    let appMonitor = AppMonitor()
    let ruleEngine: RuleEngine
    let homieState = HomieState()
    var httpServer: HTTPServer?
    
    override init() {
        self.ruleEngine = RuleEngine(homeKitManager: homeKitManager)
        super.init()
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Request HomeKit authorization
        homeKitManager.requestAuthorization { [weak self] success in
            if success {
                self?.homeKitManager.loadDevices()
                self?.homeKitManager.loadScenes()
            }
        }
        
        // Wire up server toggle
        homieState.onToggleServer = { [weak self] in
            self?.toggleServer()
        }
        
        // Start HTTP server (if auto-launch enabled)
        httpServer = HTTPServer(homeKitManager: homeKitManager, ruleEngine: ruleEngine, homieState: homieState)
        if homieState.autoLaunchServer {
            httpServer?.start()
            homieState.serverRunning = true
        } else {
            homieState.serverRunning = false
        }
        
        // Start app monitoring (limited in Catalyst)
        appMonitor.onAppChange = { [weak self] bundleId, appName in
            self?.ruleEngine.evaluateAppChange(bundleId: bundleId, appName: appName)
        }
        appMonitor.start()
        
        // Apply dock visibility preference
        homieState.applyDockVisibility()
        
        NSLog("[lil homie] Started successfully")
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        httpServer?.stop()
        appMonitor.stop()
    }
    
    func toggleServer() {
        if homieState.serverRunning {
            httpServer?.stop()
            homieState.serverRunning = false
        } else {
            httpServer?.start()
            homieState.serverRunning = true
        }
    }
}

// MARK: - Scene Delegate

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        
        #if targetEnvironment(macCatalyst)
        // Lock window size
        let fixedSize = CGSize(width: 380, height: 600)
        windowScene.sizeRestrictions?.minimumSize = fixedSize
        windowScene.sizeRestrictions?.maximumSize = fixedSize
        
        // Hide title bar for cleaner look
        if let titlebar = windowScene.titlebar {
            titlebar.titleVisibility = .hidden
            titlebar.toolbar = nil
        }
        #endif
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        // Don't quit - keep server running in background
    }
}

// Keep app running when all windows closed
extension AppDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: Any) -> Bool {
        return false
    }
}

// HomieState is defined in HomieState.swift
