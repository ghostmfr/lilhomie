import Foundation
import Combine

/// Monitors the frontmost application and notifies when it changes
/// Note: Full functionality requires native macOS (not Catalyst)
class AppMonitor: ObservableObject {
    @Published var currentApp: RunningApp?
    
    var onAppChange: ((String, String) -> Void)?
    
    struct RunningApp {
        let bundleIdentifier: String
        let name: String
    }
    
    func start() {
        // App monitoring requires native macOS APIs (NSWorkspace)
        // which are not available in Mac Catalyst.
        // For full app-aware features, a native macOS build is needed.
        NSLog("[AppMonitor] App monitoring not available in Catalyst build")
    }
    
    func stop() {
        // No-op in Catalyst
    }
}

// MARK: - App Matching Helpers

extension AppMonitor {
    /// Check if a bundle ID matches a pattern (supports wildcards)
    static func matches(bundleId: String, pattern: String) -> Bool {
        if pattern.hasSuffix("*") {
            let prefix = String(pattern.dropLast())
            return bundleId.hasPrefix(prefix)
        } else if pattern.hasPrefix("*") {
            let suffix = String(pattern.dropFirst())
            return bundleId.hasSuffix(suffix)
        } else {
            return bundleId == pattern
        }
    }
}
