import AppKit
import Combine

/// Full-featured app monitor for native macOS
/// Uses NSWorkspace to track frontmost application
class MacAppMonitor: ObservableObject {
    @Published var currentApp: RunningApp?
    @Published var isUserActive: Bool = true
    
    var onAppChange: ((String, String) -> Void)?
    var onUserActivity: ((Bool) -> Void)?
    
    private var appObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?
    private var lastBundleId: String?
    private var idleTimer: Timer?
    private let idleThreshold: TimeInterval = 300 // 5 minutes
    
    struct RunningApp: Equatable {
        let bundleIdentifier: String
        let name: String
        let icon: NSImage?
    }
    
    func start() {
        // Get initial state
        updateCurrentApp()
        
        // Monitor app switches
        appObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppActivation(notification)
        }
        
        // Monitor screen lock/unlock for presence
        let dnc = DistributedNotificationCenter.default()
        screenObserver = dnc.addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenLock()
        }
        
        dnc.addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenUnlock()
        }
        
        // Start idle timer
        startIdleMonitoring()
        
        NSLog("[MacAppMonitor] Started - tracking frontmost app and user presence")
    }
    
    func stop() {
        if let appObserver = appObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(appObserver)
        }
        if let screenObserver = screenObserver {
            DistributedNotificationCenter.default().removeObserver(screenObserver)
        }
        idleTimer?.invalidate()
        
        NSLog("[MacAppMonitor] Stopped")
    }
    
    // MARK: - App Monitoring
    
    private func updateCurrentApp() {
        guard let frontmost = NSWorkspace.shared.frontmostApplication else { return }
        
        let bundleId = frontmost.bundleIdentifier ?? "unknown"
        let appName = frontmost.localizedName ?? "Unknown"
        
        currentApp = RunningApp(
            bundleIdentifier: bundleId,
            name: appName,
            icon: frontmost.icon
        )
    }
    
    private func handleAppActivation(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        let bundleId = app.bundleIdentifier ?? "unknown"
        let appName = app.localizedName ?? "Unknown"
        
        // Only fire if app actually changed
        if bundleId != lastBundleId {
            lastBundleId = bundleId
            
            currentApp = RunningApp(
                bundleIdentifier: bundleId,
                name: appName,
                icon: app.icon
            )
            
            NSLog("[MacAppMonitor] App changed: \(appName) (\(bundleId))")
            onAppChange?(bundleId, appName)
        }
        
        // Reset idle on any app activity
        resetIdleTimer()
    }
    
    // MARK: - Presence Detection
    
    private func handleScreenLock() {
        NSLog("[MacAppMonitor] Screen locked - user away")
        isUserActive = false
        onUserActivity?(false)
    }
    
    private func handleScreenUnlock() {
        NSLog("[MacAppMonitor] Screen unlocked - user returned")
        isUserActive = true
        onUserActivity?(true)
        resetIdleTimer()
    }
    
    private func startIdleMonitoring() {
        idleTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkIdleState()
        }
    }
    
    private func resetIdleTimer() {
        if !isUserActive {
            isUserActive = true
            onUserActivity?(true)
        }
    }
    
    private func checkIdleState() {
        let idleTime = CGEventSource.secondsSinceLastEventType(
            .hidSystemState,
            eventType: .mouseMoved
        )
        
        let keyboardIdle = CGEventSource.secondsSinceLastEventType(
            .hidSystemState,
            eventType: .keyDown
        )
        
        let actualIdle = min(idleTime, keyboardIdle)
        
        if actualIdle > idleThreshold && isUserActive {
            NSLog("[MacAppMonitor] User idle for \(Int(actualIdle))s - marking as away")
            isUserActive = false
            onUserActivity?(false)
        }
    }
    
    // MARK: - Utilities
    
    /// Get list of running apps
    func getRunningApps() -> [RunningApp] {
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app in
                guard let bundleId = app.bundleIdentifier,
                      let name = app.localizedName else { return nil }
                return RunningApp(bundleIdentifier: bundleId, name: name, icon: app.icon)
            }
    }
    
    /// Check if a specific app is running
    func isAppRunning(bundleId: String) -> Bool {
        return NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == bundleId
        }
    }
    
    /// Check if app bundle ID matches a pattern (supports wildcards)
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
