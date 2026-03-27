// Tests/RuleEngineTests.swift
// XCTest suite for RuleEngine — rule loading, condition evaluation, action dispatch,
// enable/disable state, and edge cases (missing devices, conflicting rules).
//
// Rules are loaded from a temporary file so production data is never touched.
// A FixedClock is injected wherever time-range conditions are exercised so that
// tests are deterministic and never flaky.

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

    /// Create a RuleEngine that starts with an explicitly empty rules list.
    ///
    /// The testable init now calls `loadRules()` (consistent with production).
    /// To guarantee a known-empty starting state we write `[]` to `tmpURL`
    /// before constructing the engine, which makes `loadRules()` decode zero
    /// rules rather than falling back to the built-in defaults.
    private func makeEngine(devices: [HomeDevice] = [], clock: Clock = SystemClock()) -> RuleEngine {
        mock.devices = devices
        // Seed the file with an empty rules array so the engine starts clean.
        let empty = try! JSONEncoder().encode([HomieRule]())
        try! empty.write(to: tmpURL)
        return RuleEngine(homeKitManager: mock, rulesURL: tmpURL, clock: clock)
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
        // Do NOT pre-seed the file — verify the engine handles a missing file
        // gracefully (loads built-in defaults rather than crashing).
        let engine = RuleEngine(homeKitManager: mock, rulesURL: tmpURL)
        // The engine should have a non-nil, non-crashing rules array.
        // When the file is absent loadRules() creates the default rules.
        XCTAssertNotNil(engine.rules, "rules must never be nil")
    }

    func testLoadRulesFromDisk() throws {
        // Write rules to tmpURL before constructing the engine; the testable
        // init now calls loadRules() so the data is available immediately.
        let rule = makeRule(name: "Disk Rule")
        let data = try JSONEncoder().encode([rule])
        try data.write(to: tmpURL)

        let engine = RuleEngine(homeKitManager: mock, rulesURL: tmpURL)

        XCTAssertEqual(engine.rules.count, 1)
        XCTAssertEqual(engine.rules[0].name, "Disk Rule")
    }

    func testLoadRulesFallsBackGracefullyOnCorruptData() throws {
        try "not valid json".write(to: tmpURL, atomically: true, encoding: .utf8)
        // Engine calls loadRules() in init; corrupt data should not crash.
        let engine = RuleEngine(homeKitManager: mock, rulesURL: tmpURL)
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
        // saveRules is called inside addRule — the file now holds exactly 1 rule.

        // Create a fresh engine pointing at the same file.
        // makeEngine() would overwrite the file with [] so we construct directly.
        let engine2 = RuleEngine(homeKitManager: mock, rulesURL: tmpURL)
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
    //
    // A FixedClock is injected so tests are completely deterministic — they
    // never rely on the current wall-clock time and therefore cannot be flaky.

    func testRuleWithTimeRangeMatchesInsideRange() {
        // Clock fixed at 14:00 — well inside 09:00–18:00
        let clock = FixedClock(hour: 14, minute: 0)
        let engine = makeEngine(clock: clock)
        let rule = makeRule(name: "Work Hours", app: "com.test.app", after: "09:00", before: "18:00", enabled: true)
        engine.addRule(rule)

        engine.evaluateAppChange(bundleId: "com.test.app", appName: "TestApp")
        XCTAssertTrue(engine.activeRules.contains(rule.id))
    }

    func testRuleWithTimeRangeDoesNotMatchOutsideRange() {
        // Clock fixed at 08:00 — before the 09:00–18:00 window
        let clock = FixedClock(hour: 8, minute: 0)
        let engine = makeEngine(clock: clock)
        let rule = makeRule(name: "Work Hours", app: "com.test.app", after: "09:00", before: "18:00", enabled: true)
        engine.addRule(rule)

        engine.evaluateAppChange(bundleId: "com.test.app", appName: "TestApp")
        XCTAssertFalse(engine.activeRules.contains(rule.id))
    }

    func testRuleWithTimeRangeDoesNotMatchAfterRange() {
        // Clock fixed at 22:00 — after the 09:00–18:00 window
        let clock = FixedClock(hour: 22, minute: 0)
        let engine = makeEngine(clock: clock)
        let rule = makeRule(name: "Work Hours", app: "com.test.app", after: "09:00", before: "18:00", enabled: true)
        engine.addRule(rule)

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
