// Tests/RuleEngineTests.swift
// XCTest suite for RuleEngine — rule loading, condition evaluation, action dispatch,
// enable/disable state, and edge cases (missing devices, conflicting rules).
//
// Rules are loaded from a temporary file so production data is never touched.

import XCTest
import Foundation

final class RuleEngineTests: XCTestCase {

    // MARK: - Helpers

    private var mock: MockHomeKitManager!
    private var tmpURL: URL!

    override func setUp() {
        super.setUp()
        mock = MockHomeKitManager()
        tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rules_test_\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmpURL)
        mock = nil
        super.tearDown()
    }

    /// Create a RuleEngine that starts with no persisted rules.
    private func makeEngine(devices: [HomeDevice] = []) -> RuleEngine {
        mock.devices = devices
        return RuleEngine(homeKitManager: mock, rulesURL: tmpURL)
    }

    private func makeRule(
        name: String = "Test Rule",
        app: String? = "com.test.app",
        after: String? = nil,
        before: String? = nil,
        actions: [HomieRule.Action] = [],
        revert: Bool = false,
        enabled: Bool = true
    ) -> HomieRule {
        let conditions = HomieRule.Conditions(
            app: app,
            timeRange: (after != nil || before != nil) ?
                HomieRule.TimeRange(after: after, before: before) : nil
        )
        return HomieRule(name: name, conditions: conditions, actions: actions, revert: revert, enabled: enabled)
    }

    // MARK: - Rule Loading

    func testEngineStartsWithNoRulesWhenFileAbsent() {
        let engine = makeEngine()
        XCTAssertTrue(engine.rules.isEmpty, "Expected empty rules when no file exists at tmpURL")
    }

    func testLoadRulesFromDisk() throws {
        // Write rules to tmpURL, then load
        let rule = makeRule(name: "Disk Rule")
        let data = try JSONEncoder().encode([rule])
        try data.write(to: tmpURL)

        let engine = makeEngine()
        engine.loadRules()

        XCTAssertEqual(engine.rules.count, 1)
        XCTAssertEqual(engine.rules[0].name, "Disk Rule")
    }

    func testLoadRulesFallsBackGracefullyOnCorruptData() throws {
        try "not valid json".write(to: tmpURL, atomically: true, encoding: .utf8)
        let engine = makeEngine()
        engine.loadRules()
        // Should not crash; rules may be empty or set to defaults depending on implementation
        // Just verify it doesn't throw
        XCTAssertNotNil(engine.rules)
    }

    // MARK: - Rule Management

    func testAddRule() {
        let engine = makeEngine()
        let rule = makeRule(name: "New Rule")
        engine.addRule(rule)
        XCTAssertEqual(engine.rules.count, 1)
        XCTAssertEqual(engine.rules[0].name, "New Rule")
    }

    func testUpdateRule() {
        let engine = makeEngine()
        var rule = makeRule(name: "Original")
        engine.addRule(rule)

        rule.name = "Updated"
        engine.updateRule(rule)

        XCTAssertEqual(engine.rules[0].name, "Updated")
    }

    func testDeleteRule() {
        let engine = makeEngine()
        let rule = makeRule(name: "Deletable")
        engine.addRule(rule)
        XCTAssertEqual(engine.rules.count, 1)

        engine.deleteRule(id: rule.id)
        XCTAssertTrue(engine.rules.isEmpty)
    }

    func testDeleteRuleAlsoRemovesFromActiveRules() {
        let engine = makeEngine()
        let rule = makeRule(name: "Active Rule")
        engine.addRule(rule)
        engine.activeRules.insert(rule.id)

        engine.deleteRule(id: rule.id)
        XCTAssertFalse(engine.activeRules.contains(rule.id))
    }

    // MARK: - Rule Persistence

    func testSaveAndReloadRules() throws {
        let engine = makeEngine()
        engine.addRule(makeRule(name: "Persisted"))
        // saveRules is called inside addRule

        // Create a fresh engine from the same file
        let engine2 = makeEngine()
        engine2.loadRules()
        XCTAssertEqual(engine2.rules.count, 1)
        XCTAssertEqual(engine2.rules[0].name, "Persisted")
    }

    // MARK: - Condition Evaluation (via evaluateAppChange)

    func testEnabledRuleActivatesOnAppMatch() {
        let engine = makeEngine()
        let rule = makeRule(name: "Zoom Rule", app: "us.zoom.xos", enabled: true)
        engine.addRule(rule)

        engine.evaluateAppChange(bundleId: "us.zoom.xos", appName: "Zoom")
        XCTAssertTrue(engine.activeRules.contains(rule.id))
    }

    func testDisabledRuleDoesNotActivate() {
        let engine = makeEngine()
        let rule = makeRule(name: "Disabled", app: "com.test.app", enabled: false)
        engine.addRule(rule)

        engine.evaluateAppChange(bundleId: "com.test.app", appName: "TestApp")
        XCTAssertFalse(engine.activeRules.contains(rule.id))
    }

    func testRuleWithWildcardBundleIdMatches() {
        let engine = makeEngine()
        let rule = makeRule(name: "Adobe Rule", app: "com.adobe.*", enabled: true)
        engine.addRule(rule)

        engine.evaluateAppChange(bundleId: "com.adobe.LightroomClassicCC7", appName: "Lightroom")
        XCTAssertTrue(engine.activeRules.contains(rule.id))
    }

    func testRuleDoesNotActivateOnMismatchedApp() {
        let engine = makeEngine()
        let rule = makeRule(name: "Zoom Only", app: "us.zoom.xos", enabled: true)
        engine.addRule(rule)

        engine.evaluateAppChange(bundleId: "com.slack.SlackMacGap", appName: "Slack")
        XCTAssertFalse(engine.activeRules.contains(rule.id))
    }

    func testActiveRuleDeactivatesWhenConditionNoLongerMatches() {
        let engine = makeEngine()
        let rule = makeRule(name: "Zoom Rule", app: "us.zoom.xos", enabled: true)
        engine.addRule(rule)

        // Activate
        engine.evaluateAppChange(bundleId: "us.zoom.xos", appName: "Zoom")
        XCTAssertTrue(engine.activeRules.contains(rule.id))

        // Switch to Slack — rule should deactivate
        engine.evaluateAppChange(bundleId: "com.tinyspeck.slackmacgap", appName: "Slack")
        XCTAssertFalse(engine.activeRules.contains(rule.id))
    }

    // MARK: - Time Range Conditions

    func testRuleWithTimeRangeMatchesInsideRange() {
        // Use a time range guaranteed to encompass "now" — 00:00 to 23:59
        let engine = makeEngine()
        let rule = makeRule(name: "All Day", app: "com.test.app", after: "00:00", before: "23:59", enabled: true)
        engine.addRule(rule)

        engine.evaluateAppChange(bundleId: "com.test.app", appName: "TestApp")
        XCTAssertTrue(engine.activeRules.contains(rule.id))
    }

    func testRuleWithTimeRangeDoesNotMatchOutsideRange() {
        // Use a time range in the past: e.g. 00:01-00:02 (almost certainly not now)
        let engine = makeEngine()
        let rule = makeRule(name: "Tiny Window", app: "com.test.app", after: "00:01", before: "00:02", enabled: true)
        engine.addRule(rule)

        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let currentMinutes = hour * 60 + minute

        guard currentMinutes < 1 || currentMinutes > 2 else {
            // Test is running inside the tiny window — skip to avoid false failure
            return
        }

        engine.evaluateAppChange(bundleId: "com.test.app", appName: "TestApp")
        XCTAssertFalse(engine.activeRules.contains(rule.id))
    }

    // MARK: - Action Dispatch: Device

    func testActivatingRuleDispatchesDeviceAction() {
        let device = Fixtures.makeDevice(id: "d-action", name: "Study Light", isOn: false)
        let engine = makeEngine(devices: [device])

        let settings = HomieRule.Action.DeviceSettings(on: true, brightness: 80)
        let action = HomieRule.Action.device("d-action", settings)
        let rule = makeRule(name: "Light On", app: "us.zoom.xos", actions: [action], enabled: true)
        engine.addRule(rule)

        engine.evaluateAppChange(bundleId: "us.zoom.xos", appName: "Zoom")

        XCTAssertEqual(mock.setStateCalls.count, 1)
        XCTAssertEqual(mock.setStateCalls[0].on, true)
        XCTAssertEqual(mock.setStateCalls[0].brightness, 80)
    }

    func testActivatingRuleDispatchesSceneAction() {
        let engine = makeEngine()
        let action = HomieRule.Action.scene("Movie Night")
        let rule = makeRule(name: "Cinema", app: "com.infuse.app", actions: [action], enabled: true)
        engine.addRule(rule)

        engine.evaluateAppChange(bundleId: "com.infuse.app", appName: "Infuse")

        XCTAssertEqual(mock.triggerSceneNameCalls.count, 1)
        XCTAssertEqual(mock.triggerSceneNameCalls[0].name, "Movie Night")
    }

    // MARK: - Missing Device Reference

    func testActionWithMissingDeviceDoesNotCrash() {
        let engine = makeEngine(devices: [])  // no devices
        let action = HomieRule.Action.device("nonexistent-id", HomieRule.Action.DeviceSettings(on: true, brightness: nil))
        let rule = makeRule(name: "Ghost Action", app: "com.test.app", actions: [action], enabled: true)
        engine.addRule(rule)

        // Should not crash — device not found is silently ignored
        engine.evaluateAppChange(bundleId: "com.test.app", appName: "TestApp")
        XCTAssertTrue(mock.setStateCalls.isEmpty)
    }

    // MARK: - Conflicting Rules

    func testTwoConflictingRulesBothActivateIfBothMatch() {
        let d1 = Fixtures.makeDevice(id: "conflict-d1", name: "Lamp1", isOn: false)
        let d2 = Fixtures.makeDevice(id: "conflict-d2", name: "Lamp2", isOn: false)
        let engine = makeEngine(devices: [d1, d2])

        let rule1 = makeRule(name: "Rule A", app: "com.test.app",
            actions: [.device("conflict-d1", .init(on: true, brightness: nil))], enabled: true)
        let rule2 = makeRule(name: "Rule B", app: "com.test.app",
            actions: [.device("conflict-d2", .init(on: true, brightness: nil))], enabled: true)

        engine.addRule(rule1)
        engine.addRule(rule2)
        engine.evaluateAppChange(bundleId: "com.test.app", appName: "TestApp")

        XCTAssertTrue(engine.activeRules.contains(rule1.id))
        XCTAssertTrue(engine.activeRules.contains(rule2.id))
        XCTAssertEqual(mock.setStateCalls.count, 2)
    }

    // MARK: - Enable / Disable

    func testEnableRule() {
        let engine = makeEngine()
        var rule = makeRule(name: "Disabled", enabled: false)
        engine.addRule(rule)

        rule.enabled = true
        engine.updateRule(rule)

        XCTAssertTrue(engine.rules.first!.enabled)
    }

    func testDisableRule() {
        let engine = makeEngine()
        var rule = makeRule(name: "Enabled", enabled: true)
        engine.addRule(rule)

        rule.enabled = false
        engine.updateRule(rule)

        XCTAssertFalse(engine.rules.first!.enabled)
    }

    // MARK: - Revert Behaviour

    func testRevertRuleRestoresPreviousDeviceState() {
        let device = Fixtures.makeDevice(id: "rev-d1", name: "Mood Light", isOn: false, brightness: 20)
        let engine = makeEngine(devices: [device])

        let action = HomieRule.Action.device("rev-d1", HomieRule.Action.DeviceSettings(on: true, brightness: 100))
        let rule = makeRule(name: "Revertable", app: "us.zoom.xos", actions: [action], revert: true, enabled: true)
        engine.addRule(rule)

        // Activate rule (saves previous state)
        engine.evaluateAppChange(bundleId: "us.zoom.xos", appName: "Zoom")

        let setCallsAfterActivation = mock.setStateCalls.count
        XCTAssertTrue(setCallsAfterActivation >= 1)

        // Deactivate rule (should restore)
        engine.evaluateAppChange(bundleId: "com.other.app", appName: "Other")
        XCTAssertFalse(engine.activeRules.contains(rule.id))

        // An additional setDeviceState call should have been made to restore
        XCTAssertTrue(mock.setStateCalls.count > setCallsAfterActivation)
    }

    // MARK: - AppMonitor Pattern Matching (static utility)

    func testAppMonitorMatchesExactBundleId() {
        XCTAssertTrue(AppMonitor.matches(bundleId: "us.zoom.xos", pattern: "us.zoom.xos"))
    }

    func testAppMonitorMatchesWildcardPrefix() {
        XCTAssertTrue(AppMonitor.matches(bundleId: "com.adobe.LightroomClassic", pattern: "com.adobe.*"))
    }

    func testAppMonitorMatchesWildcardSuffix() {
        XCTAssertTrue(AppMonitor.matches(bundleId: "app.zoom.us", pattern: "*.zoom.us"))
    }

    func testAppMonitorDoesNotMatchDifferentBundle() {
        XCTAssertFalse(AppMonitor.matches(bundleId: "com.slack.SlackMacGap", pattern: "us.zoom.xos"))
    }

    // MARK: - HomieRule Codable

    func testHomieRuleCodableRoundTrip() throws {
        let original = makeRule(name: "Codec Rule", app: "com.test.app", after: "09:00", before: "17:00",
                                actions: [.scene("Work Mode")], revert: true, enabled: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HomieRule.self, from: data)
        XCTAssertEqual(decoded.name, "Codec Rule")
        XCTAssertEqual(decoded.conditions.app, "com.test.app")
        XCTAssertEqual(decoded.conditions.timeRange?.after, "09:00")
        XCTAssertEqual(decoded.conditions.timeRange?.before, "17:00")
        XCTAssertTrue(decoded.revert)
        XCTAssertTrue(decoded.enabled)
    }
}
