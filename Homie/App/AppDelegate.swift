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
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
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
        
        // Start app monitoring (limited in Catalyst)
        appMonitor.onAppChange = { [weak self] bundleId, appName in
            self?.ruleEngine.evaluateAppChange(bundleId: bundleId, appName: appName)
        }
        appMonitor.start()
        
        NSLog("[Homie] Started successfully")
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        httpServer?.stop()
        appMonitor.stop()
    }
}

// MARK: - Homie State

class HomieState: ObservableObject {
    @Published var securityCompromised: Bool = false
    @Published var currentMood: HomieCharacter.Mood = .happy
    @Published var isProcessing: Bool = false
    
    var effectiveMood: HomieCharacter.Mood {
        if securityCompromised { return .angry }
        if isProcessing { return .thinking }
        return currentMood
    }
}
