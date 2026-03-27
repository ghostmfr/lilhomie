// Tests/HomeKitManagerTests.swift
// XCTest suite for HomeKitManager's pure-Swift logic (device lookup, room filtering,
// device-state reads) using pre-populated mock data — no real HomeKit hardware needed.
//
// Note: createDevice(from:in:) and the HMHomeManagerDelegate methods require
// actual HMAccessory/HMHome objects that cannot be instantiated in a sandbox.
// Those integration paths are covered by api_test.sh and manual testing.
// This file tests the public interface of HomeKitManager that is hardware-free.

import XCTest
import Foundation

final class HomeKitManagerTests: XCTestCase {

    // MARK: - Helpers

    /// Return a MockHomeKitManager pre-loaded with a known device catalogue.
    private func makeMockManager(devices: [HomeDevice] = [], scenes: [HomeScene] = []) -> MockHomeKitManager {
        let m = MockHomeKitManager()
        m.devices = devices
        m.scenes = scenes
        return m
    }

    // MARK: - Device Lookup by ID

    func testGetDeviceByIdExactMatch() {
        let d = Fixtures.makeDevice(id: "uuid-abc", name: "Bedside Lamp")
        let m = makeMockManager(devices: [d])
        let found = m.getDevice(byId: "uuid-abc")
        XCTAssertEqual(found?.id, "uuid-abc")
        XCTAssertEqual(found?.name, "Bedside Lamp")
    }

    func testGetDeviceByIdMissing() {
        let m = makeMockManager(devices: [Fixtures.makeDevice(id: "known")])
        XCTAssertNil(m.getDevice(byId: "unknown"))
    }

    // MARK: - Device Lookup by Name

    func testGetDeviceByNameExactMatch() {
        let d = Fixtures.makeDevice(id: "n1", name: "Desk Fan")
        let m = makeMockManager(devices: [d])
        let found = m.getDevice(byName: "Desk Fan")
        XCTAssertEqual(found?.id, "n1")
    }

    func testGetDeviceByNameCaseInsensitive() {
        let d = Fixtures.makeDevice(id: "n2", name: "Kitchen Light")
        let m = makeMockManager(devices: [d])
        let found = m.getDevice(byName: "kitchen light")
        XCTAssertEqual(found?.id, "n2")
    }

    func testGetDeviceByNameContainsMatch() {
        let d = Fixtures.makeDevice(id: "n3", name: "Living Room Lamp")
        let m = makeMockManager(devices: [d])
        let found = m.getDevice(byName: "Lamp")
        XCTAssertEqual(found?.id, "n3")
    }

    func testGetDeviceByNameNotFound() {
        let m = makeMockManager(devices: [Fixtures.makeDevice(id: "n4", name: "Hallway Sconce")])
        XCTAssertNil(m.getDevice(byName: "Toaster"))
    }

    // MARK: - Room Filtering (via devices array)

    func testDevicesCanBeFilteredByRoom() {
        let devices: [HomeDevice] = [
            Fixtures.makeDevice(id: "r1", name: "A", roomName: "Office"),
            Fixtures.makeDevice(id: "r2", name: "B", roomName: "Office"),
            Fixtures.makeDevice(id: "r3", name: "C", roomName: "Bedroom")
        ]
        let m = makeMockManager(devices: devices)
        let officeDevices = m.devices.filter { $0.roomName == "Office" }
        XCTAssertEqual(officeDevices.count, 2)
    }

    func testDevicesWithNoRoomAreNil() {
        let d = Fixtures.makeDevice(id: "nr1", name: "Orphan", roomName: nil)
        let m = makeMockManager(devices: [d])
        XCTAssertNil(m.devices.first?.roomName)
    }

    func testDistinctRoomsSet() {
        let devices: [HomeDevice] = [
            Fixtures.makeDevice(id: "rr1", name: "X", roomName: "Kitchen"),
            Fixtures.makeDevice(id: "rr2", name: "Y", roomName: "Kitchen"),
            Fixtures.makeDevice(id: "rr3", name: "Z", roomName: "Patio")
        ]
        let m = makeMockManager(devices: devices)
        let rooms = Set(m.devices.compactMap { $0.roomName })
        XCTAssertEqual(rooms.count, 2)
        XCTAssertTrue(rooms.contains("Kitchen"))
        XCTAssertTrue(rooms.contains("Patio"))
    }

    // MARK: - isOn and Brightness State Reads

    func testIsOnReadCorrectly() {
        let on = Fixtures.makeDevice(id: "state1", name: "On Light", isOn: true)
        let off = Fixtures.makeDevice(id: "state2", name: "Off Light", isOn: false)
        let m = makeMockManager(devices: [on, off])
        XCTAssertTrue(m.getDevice(byId: "state1")!.isOn)
        XCTAssertFalse(m.getDevice(byId: "state2")!.isOn)
    }

    func testBrightnessReadCorrectly() {
        let bright = Fixtures.makeDevice(id: "b1", name: "Dimmer", type: .light, isOn: true, brightness: 42)
        let noBright = Fixtures.makeDevice(id: "b2", name: "Switch", type: .switchDevice, isOn: true)
        let m = makeMockManager(devices: [bright, noBright])
        XCTAssertEqual(m.getDevice(byId: "b1")!.brightness, 42)
        XCTAssertNil(m.getDevice(byId: "b2")!.brightness)
    }

    // MARK: - Toggle Dispatch

    func testToggleCallsCompletion() {
        let d = Fixtures.makeDevice(id: "t1", name: "Fan", isOn: false)
        let m = makeMockManager(devices: [d])
        var receivedResult: Bool? = nil
        m.toggleDevice(d) { result in receivedResult = result }
        XCTAssertEqual(receivedResult, true)
    }

    func testToggleFlipsIsOn() {
        let d = Fixtures.makeDevice(id: "t2", name: "Lamp", isOn: false)
        let m = makeMockManager(devices: [d])
        m.toggleDevice(d) { _ in }
        XCTAssertTrue(m.devices.first!.isOn) // now on
    }

    func testToggleFlipsIsOnWhenAlreadyOn() {
        let d = Fixtures.makeDevice(id: "t3", name: "Lamp", isOn: true)
        let m = makeMockManager(devices: [d])
        m.toggleDevice(d) { _ in }
        XCTAssertFalse(m.devices.first!.isOn) // now off
    }

    func testToggleFailureReturnsFailure() {
        let d = Fixtures.makeDevice(id: "t4", name: "Lamp", isOn: false)
        let m = makeMockManager(devices: [d])
        m.toggleResult = false
        var result: Bool = true
        m.toggleDevice(d) { r in result = r }
        XCTAssertFalse(result)
        XCTAssertFalse(m.devices.first!.isOn) // unchanged
    }

    // MARK: - SetDeviceState

    func testSetDeviceStateOn() {
        let d = Fixtures.makeDevice(id: "s1", name: "Bulb", isOn: false)
        let m = makeMockManager(devices: [d])
        var result = false
        m.setDeviceState(d, on: true, brightness: nil) { r in result = r }
        XCTAssertTrue(result)
        XCTAssertTrue(m.devices.first!.isOn)
    }

    func testSetDeviceStateOff() {
        let d = Fixtures.makeDevice(id: "s2", name: "Bulb", isOn: true)
        let m = makeMockManager(devices: [d])
        m.setDeviceState(d, on: false, brightness: nil) { _ in }
        XCTAssertFalse(m.devices.first!.isOn)
    }

    func testSetDeviceStateWithBrightness() {
        let d = Fixtures.makeDevice(id: "s3", name: "Dimmer", type: .light, isOn: false)
        let m = makeMockManager(devices: [d])
        m.setDeviceState(d, on: true, brightness: 65) { _ in }
        XCTAssertEqual(m.devices.first!.brightness, 65)
        XCTAssertTrue(m.devices.first!.isOn)
    }

    func testSetDeviceStateFailure() {
        let d = Fixtures.makeDevice(id: "s4", name: "Bulb", isOn: false)
        let m = makeMockManager(devices: [d])
        m.setStateResult = false
        var result: Bool = true
        m.setDeviceState(d, on: true, brightness: nil) { r in result = r }
        XCTAssertFalse(result)
        XCTAssertFalse(m.devices.first!.isOn) // unchanged
    }

    func testSetDeviceStateCallRecorded() {
        let d = Fixtures.makeDevice(id: "s5", name: "Lamp")
        let m = makeMockManager(devices: [d])
        m.setDeviceState(d, on: true, brightness: 50) { _ in }
        XCTAssertEqual(m.setStateCalls.count, 1)
        XCTAssertEqual(m.setStateCalls[0].on, true)
        XCTAssertEqual(m.setStateCalls[0].brightness, 50)
    }

    // MARK: - Scene Lookup

    func testGetSceneByIdFound() {
        let s = Fixtures.makeScene(id: "sc1", name: "Movie Night")
        let m = makeMockManager(scenes: [s])
        let found = m.getScene(byId: "sc1")
        XCTAssertEqual(found?.name, "Movie Night")
    }

    func testGetSceneByIdNotFound() {
        let m = makeMockManager()
        XCTAssertNil(m.getScene(byId: "ghost"))
    }

    func testGetSceneByNameFound() {
        let s = Fixtures.makeScene(id: "sc2", name: "Good Night")
        let m = makeMockManager(scenes: [s])
        let found = m.getScene(byName: "night")
        XCTAssertEqual(found?.id, "sc2")
    }

    func testGetSceneByNameNotFound() {
        let m = makeMockManager()
        XCTAssertNil(m.getScene(byName: "anything"))
    }

    // MARK: - TriggerScene

    func testTriggerSceneByNameCallsCompletion() {
        let m = makeMockManager()
        var result: Bool = false
        m.triggerScene(named: "Good Night") { r in result = r }
        XCTAssertTrue(result)
        XCTAssertEqual(m.triggerSceneNameCalls.count, 1)
        XCTAssertEqual(m.triggerSceneNameCalls[0].name, "Good Night")
    }

    func testTriggerSceneByIdCallsCompletion() {
        let m = makeMockManager()
        var result: Bool = false
        m.triggerScene(id: "sc-id") { r in result = r }
        XCTAssertTrue(result)
        XCTAssertEqual(m.triggerSceneIdCalls.count, 1)
    }

    func testTriggerSceneFailure() {
        let m = makeMockManager()
        m.triggerSceneResult = false
        var result: Bool = true
        m.triggerScene(named: "Nonexistent") { r in result = r }
        XCTAssertFalse(result)
    }

    // MARK: - DeviceType

    func testDeviceTypeValues() {
        XCTAssertEqual(HomeDevice.DeviceType.light.rawValue, "light")
        XCTAssertEqual(HomeDevice.DeviceType.outlet.rawValue, "outlet")
        XCTAssertEqual(HomeDevice.DeviceType.switchDevice.rawValue, "switch")
        XCTAssertEqual(HomeDevice.DeviceType.fan.rawValue, "fan")
        XCTAssertEqual(HomeDevice.DeviceType.thermostat.rawValue, "thermostat")
        XCTAssertEqual(HomeDevice.DeviceType.unknown.rawValue, "unknown")
    }

    func testHomeDeviceStateEmoji() {
        let on = Fixtures.makeDevice(isOn: true)
        let off = Fixtures.makeDevice(isOn: false)
        XCTAssertEqual(on.stateEmoji, "🟢")
        XCTAssertEqual(off.stateEmoji, "⚪️")
    }

    // MARK: - HomeDevice Codable round-trip

    func testHomeDeviceCodableRoundTrip() throws {
        let original = Fixtures.makeDevice(id: "cod1", name: "Encoded Light", roomName: "Lab",
                                           type: .light, isOn: true, brightness: 33)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HomeDevice.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.roomName, original.roomName)
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.isOn, original.isOn)
        XCTAssertEqual(decoded.brightness, original.brightness)
    }
}
