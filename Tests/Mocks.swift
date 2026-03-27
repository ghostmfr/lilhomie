// Tests/Mocks.swift
// Shared mock objects and test helpers for lilhomie unit tests.
//
// All mocks implement HomeKitManagerProtocol so they can be injected into
// HTTPServer and RuleEngine without touching real HomeKit hardware.

import Foundation

// MARK: - MockHomeKitManager

/// A fully controllable mock of HomeKitManagerProtocol.
///
/// Lookup methods (getDevice/getScene by id/name) are intentionally **not**
/// reimplemented here — they are inherited from the default implementations in
/// HomeKitManagerProtocol, keeping this mock free of duplicated logic.
final class MockHomeKitManager: HomeKitManagerProtocol {

    // MARK: State

    var devices: [HomeDevice] = []
    var scenes: [HomeScene] = []
    var homeManagerHomesCount: Int = 0
    var homeManagerAuthStatus: Int = 0

    // MARK: Call recording

    var toggleCalls: [(device: HomeDevice, result: Bool)] = []
    var setStateCalls: [(device: HomeDevice, on: Bool, brightness: Int?, result: Bool)] = []
    var triggerSceneNameCalls: [(name: String, result: Bool)] = []
    var triggerSceneIdCalls: [(id: String, result: Bool)] = []

    // MARK: Return-value overrides

    var toggleResult: Bool = true
    var setStateResult: Bool = true
    var triggerSceneResult: Bool = true

    // MARK: Protocol — mutating operations
    //
    // Lookup operations (getDevice / getScene) are provided by the default
    // implementations on HomeKitManagerProtocol and are not repeated here.

    func toggleDevice(_ device: HomeDevice, completion: @escaping (Bool) -> Void) {
        // Flip the device's isOn state in the devices array
        if toggleResult, let idx = devices.firstIndex(where: { $0.id == device.id }) {
            devices[idx].isOn.toggle()
        }
        toggleCalls.append((device: device, result: toggleResult))
        completion(toggleResult)
    }

    func setDeviceState(_ device: HomeDevice, on: Bool, brightness: Int?, completion: @escaping (Bool) -> Void) {
        if setStateResult, let idx = devices.firstIndex(where: { $0.id == device.id }) {
            devices[idx].isOn = on
            if let b = brightness {
                devices[idx].brightness = b
            }
        }
        setStateCalls.append((device: device, on: on, brightness: brightness, result: setStateResult))
        completion(setStateResult)
    }

    func triggerScene(named name: String, completion: @escaping (Bool) -> Void) {
        triggerSceneNameCalls.append((name: name, result: triggerSceneResult))
        completion(triggerSceneResult)
    }

    func triggerScene(id: String, completion: @escaping (Bool) -> Void) {
        triggerSceneIdCalls.append((id: id, result: triggerSceneResult))
        completion(triggerSceneResult)
    }
}

// MARK: - FixedClock

/// A deterministic `Clock` implementation for use in tests.
/// Inject a specific `Date` to make time-range condition tests completely
/// predictable and immune to flakiness.
struct FixedClock: Clock {
    let fixedDate: Date

    /// Convenience initialiser: build a date from an hour and minute in the
    /// current calendar so tests read as "09:30 o'clock".
    init(hour: Int, minute: Int) {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        components.second = 0
        fixedDate = Calendar.current.date(from: components) ?? Date()
    }

    var now: Date { fixedDate }
}

// MARK: - Test Fixtures

enum Fixtures {
    static func makeDevice(
        id: String = UUID().uuidString,
        name: String = "Test Light",
        roomName: String? = "Living Room",
        type: HomeDevice.DeviceType = .light,
        isOn: Bool = false,
        brightness: Int? = nil
    ) -> HomeDevice {
        HomeDevice(id: id, name: name, roomName: roomName, type: type, isOn: isOn, brightness: brightness)
    }

    static func makeScene(
        id: String = UUID().uuidString,
        name: String = "Good Night",
        homeName: String = "My Home",
        actionCount: Int = 2
    ) -> HomeScene {
        HomeScene(id: id, name: name, homeName: homeName, actionCount: actionCount)
    }
}

// MARK: - HTTP Response Helpers

struct ParsedHTTPResponse {
    let statusCode: Int
    let headers: [String: String]
    let body: String
    var json: [String: Any]? {
        guard let data = body.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}

func parseHTTPResponse(_ raw: String) -> ParsedHTTPResponse {
    let parts = raw.components(separatedBy: "\r\n\r\n")
    let headerSection = parts.first ?? ""
    let body = parts.dropFirst().joined(separator: "\r\n\r\n").trimmingCharacters(in: .whitespacesAndNewlines)

    let headerLines = headerSection.components(separatedBy: "\r\n")
    let statusLine = headerLines.first ?? "HTTP/1.1 200 OK"
    let codeStr = statusLine.split(separator: " ").dropFirst().first ?? "200"
    let statusCode = Int(codeStr) ?? 0

    var headers: [String: String] = [:]
    for line in headerLines.dropFirst() {
        let pair = line.split(separator: ":", maxSplits: 1)
        if pair.count == 2 {
            headers[pair[0].trimmingCharacters(in: .whitespaces)] = pair[1].trimmingCharacters(in: .whitespaces)
        }
    }

    return ParsedHTTPResponse(statusCode: statusCode, headers: headers, body: body)
}
