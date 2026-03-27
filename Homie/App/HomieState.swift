import Foundation
import Combine
import SwiftUI

class HomieState: ObservableObject {
    @Published var securityCompromised: Bool = false
    @Published var currentMood: HomieCharacter.Mood = .happy
    @Published var isProcessing: Bool = false
    @Published var requestCount: Int = 0
    @Published var port: UInt16 = 8420
    @Published var serverRunning: Bool = true
    
    // Callback to toggle server (set by AppDelegate)
    var onToggleServer: (() -> Void)?
    
    // Auto-launch preference
    @AppStorage("autoLaunchServer") var autoLaunchServer: Bool = true
    
    // Hide from dock preference
    @AppStorage("hideFromDock") var hideFromDock: Bool = false {
        didSet {
            applyDockVisibility()
        }
    }
    
    func applyDockVisibility() {
        #if targetEnvironment(macCatalyst)
        guard let nsAppClass = NSClassFromString("NSApplication") as? NSObject.Type,
              let sharedApp = nsAppClass.value(forKey: "sharedApplication") as? NSObject else {
            return
        }
        let policy = hideFromDock ? 1 : 0
        sharedApp.perform(Selector(("setActivationPolicy:")), with: policy)
        #endif
    }
    
    var effectiveMood: HomieCharacter.Mood {
        if securityCompromised { return .angry }
        if isProcessing { return .thinking }
        return currentMood
    }
    
    func incrementRequestCount() {
        DispatchQueue.main.async {
            self.requestCount += 1
        }
    }
    
    func toggleServer() {
        onToggleServer?()
    }
}
