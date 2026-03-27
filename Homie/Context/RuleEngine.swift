import Foundation
import Combine

/// Evaluates app-aware rules and triggers HomeKit actions
class RuleEngine: ObservableObject {
    @Published var rules: [HomieRule] = []
    @Published var activeRules: Set<String> = []  // Rule IDs currently active
    
    private let homeKitManager: HomeKitManagerProtocol
    private var previousStates: [String: [String: Any]] = [:]  // For reverting
    
    private let rulesURL: URL

    private static func defaultRulesURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let homieDir = appSupport.appendingPathComponent("Homie")
        try? FileManager.default.createDirectory(at: homieDir, withIntermediateDirectories: true)
        return homieDir.appendingPathComponent("rules.json")
    }

    /// Production init — loads rules from the standard Application Support path.
    init(homeKitManager: HomeKitManagerProtocol) {
        self.homeKitManager = homeKitManager
        self.rulesURL = RuleEngine.defaultRulesURL()
        loadRules()
    }

    /// Testable init — uses a custom rulesURL so tests don't touch the real file system.
    init(homeKitManager: HomeKitManagerProtocol, rulesURL: URL) {
        self.homeKitManager = homeKitManager
        self.rulesURL = rulesURL
    }
    
    // MARK: - Rule Evaluation
    
    func evaluateAppChange(bundleId: String, appName: String) {
        NSLog("[RuleEngine] Evaluating rules for app: \(appName) (\(bundleId))")
        
        for rule in rules where rule.enabled {
            let matches = evaluateConditions(rule: rule, bundleId: bundleId, appName: appName)
            let wasActive = activeRules.contains(rule.id)
            
            if matches && !wasActive {
                // Rule just became active
                activateRule(rule)
            } else if !matches && wasActive {
                // Rule just became inactive
                deactivateRule(rule)
            }
        }
    }
    
    private func evaluateConditions(rule: HomieRule, bundleId: String, appName: String) -> Bool {
        // Check app pattern
        if let appPattern = rule.conditions.app {
            if !AppMonitor.matches(bundleId: bundleId, pattern: appPattern) {
                return false
            }
        }
        
        // Check time range (if specified)
        if let timeRange = rule.conditions.timeRange {
            let now = Date()
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: now)
            let minute = calendar.component(.minute, from: now)
            let currentMinutes = hour * 60 + minute
            
            if let after = parseTime(timeRange.after) {
                if currentMinutes < after { return false }
            }
            if let before = parseTime(timeRange.before) {
                if currentMinutes > before { return false }
            }
        }
        
        // TODO: Check focus mode
        // TODO: Check other conditions
        
        return true
    }
    
    private func parseTime(_ timeString: String?) -> Int? {
        guard let timeString = timeString else { return nil }
        let parts = timeString.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return nil }
        return hour * 60 + minute
    }
    
    // MARK: - Rule Activation
    
    private func activateRule(_ rule: HomieRule) {
        NSLog("[RuleEngine] Activating rule: \(rule.name)")
        activeRules.insert(rule.id)
        
        // Save current state if we need to revert later
        if rule.revert {
            savePreviousState(for: rule)
        }
        
        // Execute actions
        for action in rule.actions {
            executeAction(action)
        }
    }
    
    private func deactivateRule(_ rule: HomieRule) {
        NSLog("[RuleEngine] Deactivating rule: \(rule.name)")
        activeRules.remove(rule.id)
        
        // Revert to previous state if configured
        if rule.revert {
            restorePreviousState(for: rule)
        }
    }
    
    private func savePreviousState(for rule: HomieRule) {
        var states: [String: Any] = [:]
        
        for action in rule.actions {
            if case .device(let deviceId, _) = action {
                if let device = homeKitManager.getDevice(byId: deviceId) {
                    states[deviceId] = [
                        "isOn": device.isOn,
                        "brightness": device.brightness as Any
                    ]
                }
            }
        }
        
        previousStates[rule.id] = states
    }
    
    private func restorePreviousState(for rule: HomieRule) {
        guard let states = previousStates[rule.id] else { return }
        
        for (deviceId, state) in states {
            guard let stateDict = state as? [String: Any] else { continue }
            
            let isOn = stateDict["isOn"] as? Bool ?? false
            let brightness = stateDict["brightness"] as? Int
            
            if let device = homeKitManager.getDevice(byId: deviceId) {
                homeKitManager.setDeviceState(device, on: isOn, brightness: brightness) { _ in }
            }
        }
        
        previousStates.removeValue(forKey: rule.id)
    }
    
    private func executeAction(_ action: HomieRule.Action) {
        switch action {
        case .scene(let sceneName):
            homeKitManager.triggerScene(named: sceneName) { success in
                NSLog("[RuleEngine] Scene '\(sceneName)' trigger: \(success ? "success" : "failed")")
            }
            
        case .device(let deviceId, let settings):
            guard let device = homeKitManager.getDevice(byId: deviceId) else {
                NSLog("[RuleEngine] Device not found: \(deviceId)")
                return
            }
            
            let on = settings.on ?? device.isOn
            let brightness = settings.brightness
            
            homeKitManager.setDeviceState(device, on: on, brightness: brightness) { success in
                NSLog("[RuleEngine] Device '\(device.name)' set: \(success ? "success" : "failed")")
            }
        }
    }
    
    // MARK: - Rule Management
    
    func addRule(_ rule: HomieRule) {
        rules.append(rule)
        saveRules()
    }
    
    func updateRule(_ rule: HomieRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
            saveRules()
        }
    }
    
    func deleteRule(id: String) {
        rules.removeAll { $0.id == id }
        activeRules.remove(id)
        saveRules()
    }
    
    // MARK: - Persistence
    
    func loadRules() {
        guard FileManager.default.fileExists(atPath: rulesURL.path) else {
            // Create default rules
            rules = defaultRules()
            saveRules()
            return
        }
        
        do {
            let data = try Data(contentsOf: rulesURL)
            rules = try JSONDecoder().decode([HomieRule].self, from: data)
            NSLog("[RuleEngine] Loaded \(rules.count) rules")
        } catch {
            NSLog("[RuleEngine] Failed to load rules: \(error)")
            rules = defaultRules()
        }
    }
    
    func saveRules() {
        do {
            let data = try JSONEncoder().encode(rules)
            try data.write(to: rulesURL)
            NSLog("[RuleEngine] Saved \(rules.count) rules")
        } catch {
            NSLog("[RuleEngine] Failed to save rules: \(error)")
        }
    }
    
    private func defaultRules() -> [HomieRule] {
        return [
            HomieRule(
                name: "Video Call Mode",
                conditions: HomieRule.Conditions(
                    app: "us.zoom.xos",  // Zoom
                    timeRange: nil
                ),
                actions: [
                    // This would trigger a scene - user can customize
                ],
                revert: true,
                enabled: false  // Disabled by default until configured
            ),
            HomieRule(
                name: "Photo Editing",
                conditions: HomieRule.Conditions(
                    app: "com.adobe.Lightroom*",
                    timeRange: HomieRule.TimeRange(after: "18:00", before: "23:59")
                ),
                actions: [],
                revert: true,
                enabled: false
            )
        ]
    }
}

// MARK: - Rule Model

struct HomieRule: Codable, Identifiable {
    var id: String = UUID().uuidString
    var name: String
    var conditions: Conditions
    var actions: [Action]
    var revert: Bool = true  // Revert when conditions no longer match
    var enabled: Bool = true
    
    struct Conditions: Codable {
        var app: String?  // Bundle ID pattern (supports * wildcard)
        var timeRange: TimeRange?
        var focus: String?  // macOS Focus mode name
    }
    
    struct TimeRange: Codable {
        var after: String?   // "HH:mm"
        var before: String?  // "HH:mm"
    }
    
    enum Action: Codable {
        case scene(String)  // Scene name
        case device(String, DeviceSettings)  // Device ID + settings
        
        struct DeviceSettings: Codable {
            var on: Bool?
            var brightness: Int?
        }
    }
}
