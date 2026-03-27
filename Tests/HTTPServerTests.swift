// Tests/HTTPServerTests.swift
// XCTest suite for HTTPServer route parsing, dispatch, and response shapes.
// Uses MockHomeKitManager so no real HomeKit hardware is needed.

import XCTest
import Foundation

final class HTTPServerTests: XCTestCase {

    // MARK: - Helpers

    private var mock: MockHomeKitManager!
    private var ruleEngine: RuleEngine!
    private var homieState: HomieState!
    private var server: HTTPServer!

    override func setUp() {
        super.setUp()
        mock = MockHomeKitManager()
        homieState = HomieState()
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("homie_tests_\(UUID().uuidString).json")
        ruleEngine = RuleEngine(homeKitManager: mock, rulesURL: tmpURL)
        server = HTTPServer(homeKitManager: mock, ruleEngine: ruleEngine, homieState: homieState)
    }

    override func tearDown() {
        mock = nil
        ruleEngine = nil
        homieState = nil
        server = nil
        super.tearDown()
    }

    /// Convenience: build a raw HTTP request string.
    private func request(_ method: String, _ path: String, body: [String: Any]? = nil) -> String {
        var raw = "\(method) \(path) HTTP/1.1\r\nHost: localhost\r\n"
        if let body = body, let data = try? JSONSerialization.data(withJSONObject: body),
           let bodyStr = String(data: data, encoding: .utf8) {
            raw += "Content-Type: application/json\r\nContent-Length: \(bodyStr.utf8.count)\r\n\r\n\(bodyStr)"
        } else {
            raw += "\r\n"
        }
        return raw
    }

    // MARK: - Health

    func testHealthEndpointReturns200() {
        let resp = parseHTTPResponse(server.handleRequest(request("GET", "/health")))
        XCTAssertEqual(resp.statusCode, 200)
        XCTAssertEqual(resp.json?["status"] as? String, "ok")
        XCTAssertEqual(resp.json?["app"] as? String, "Homie")
    }

    // MARK: - Debug

    func testDebugEndpointReturnsStructure() {
        mock.homeManagerHomesCount = 2
        mock.homeManagerAuthStatus = 3
        let resp = parseHTTPResponse(server.handleRequest(request("GET", "/debug")))
        XCTAssertEqual(resp.statusCode, 200)
        XCTAssertEqual(resp.json?["homesCount"] as? Int, 2)
        XCTAssertEqual(resp.json?["authStatus"] as? Int, 3)
        XCTAssertNotNil(resp.json?["devicesLoaded"])
    }

    // MARK: - GET /devices

    func testGetDevicesEmpty() {
        let resp = parseHTTPResponse(server.handleRequest(request("GET", "/devices")))
        XCTAssertEqual(resp.statusCode, 200)
        let devices = resp.json?["devices"] as? [[String: Any]]
        XCTAssertNotNil(devices)
        XCTAssertEqual(devices?.count, 0)
    }

    func testGetDevicesReturnsList() {
        mock.devices = [
            Fixtures.makeDevice(id: "id1", name: "Desk Lamp", isOn: true),
            Fixtures.makeDevice(id: "id2", name: "Floor Lamp", isOn: false)
        ]
        let resp = parseHTTPResponse(server.handleRequest(request("GET", "/devices")))
        XCTAssertEqual(resp.statusCode, 200)
        let devices = resp.json?["devices"] as? [[String: Any]]
        XCTAssertEqual(devices?.count, 2)
        let names = devices?.compactMap { $0["name"] as? String }
        XCTAssertTrue(names?.contains("Desk Lamp") == true)
        XCTAssertTrue(names?.contains("Floor Lamp") == true)
    }

    func testGetDevicesIncludesIsOnField() {
        mock.devices = [Fixtures.makeDevice(id: "id1", name: "Bulb", isOn: true)]
        let resp = parseHTTPResponse(server.handleRequest(request("GET", "/devices")))
        let devices = resp.json?["devices"] as? [[String: Any]]
        let device = devices?.first
        XCTAssertEqual(device?["isOn"] as? Bool, true)
    }

    // MARK: - GET /device/:id

    func testGetDeviceByIdFound() {
        let d = Fixtures.makeDevice(id: "abc-123", name: "Bulb", isOn: true)
        mock.devices = [d]
        let resp = parseHTTPResponse(server.handleRequest(request("GET", "/device/abc-123")))
        XCTAssertEqual(resp.statusCode, 200)
        XCTAssertEqual(resp.json?["id"] as? String, "abc-123")
        XCTAssertEqual(resp.json?["name"] as? String, "Bulb")
    }

    func testGetDeviceByNameFound() {
        mock.devices = [Fixtures.makeDevice(id: "abc-123", name: "Desk Lamp")]
        let resp = parseHTTPResponse(server.handleRequest(request("GET", "/device/Desk_Lamp")))
        XCTAssertEqual(resp.statusCode, 200)
        XCTAssertEqual(resp.json?["name"] as? String, "Desk Lamp")
    }

    func testGetDeviceNotFound() {
        let resp = parseHTTPResponse(server.handleRequest(request("GET", "/device/nonexistent")))
        XCTAssertEqual(resp.statusCode, 404)
        XCTAssertNotNil(resp.json?["error"])
    }

    func testGetDeviceBrightnessIncludedForLight() {
        mock.devices = [Fixtures.makeDevice(id: "l1", name: "Lamp", type: .light, isOn: true, brightness: 75)]
        let resp = parseHTTPResponse(server.handleRequest(request("GET", "/device/l1")))
        XCTAssertEqual(resp.statusCode, 200)
        XCTAssertEqual(resp.json?["brightness"] as? Int, 75)
    }

    // MARK: - POST /device/:id/toggle

    func testToggleDeviceSuccess() {
        let d = Fixtures.makeDevice(id: "dev1", name: "Light", isOn: false)
        mock.devices = [d]
        let resp = parseHTTPResponse(server.handleRequest(request("POST", "/device/dev1/toggle")))
        XCTAssertEqual(resp.statusCode, 200)
        XCTAssertEqual(resp.json?["success"] as? Bool, true)
        let device = resp.json?["device"] as? [String: Any]
        XCTAssertEqual(device?["isOn"] as? Bool, true) // was false, now toggled
    }

    func testToggleDeviceNotFound() {
        let resp = parseHTTPResponse(server.handleRequest(request("POST", "/device/missing/toggle")))
        XCTAssertEqual(resp.statusCode, 404)
    }

    func testToggleDeviceFailure() {
        let d = Fixtures.makeDevice(id: "dev1", name: "Light", isOn: false)
        mock.devices = [d]
        mock.toggleResult = false
        let resp = parseHTTPResponse(server.handleRequest(request("POST", "/device/dev1/toggle")))
        XCTAssertEqual(resp.statusCode, 500)
    }

    // MARK: - POST /device/:id/on

    func testTurnDeviceOnSuccess() {
        let d = Fixtures.makeDevice(id: "dev2", name: "Fan", type: .fan, isOn: false)
        mock.devices = [d]
        let resp = parseHTTPResponse(server.handleRequest(request("POST", "/device/dev2/on")))
        XCTAssertEqual(resp.statusCode, 200)
        XCTAssertEqual(resp.json?["success"] as? Bool, true)
        let updated = resp.json?["device"] as? [String: Any]
        XCTAssertEqual(updated?["isOn"] as? Bool, true)
    }

    func testTurnDeviceOnNotFound() {
        let resp = parseHTTPResponse(server.handleRequest(request("POST", "/device/ghost/on")))
        XCTAssertEqual(resp.statusCode, 404)
    }

    // MARK: - POST /device/:id/off

    func testTurnDeviceOffSuccess() {
        let d = Fixtures.makeDevice(id: "dev3", name: "Outlet", type: .outlet, isOn: true)
        mock.devices = [d]
        let resp = parseHTTPResponse(server.handleRequest(request("POST", "/device/dev3/off")))
        XCTAssertEqual(resp.statusCode, 200)
        let updated = resp.json?["device"] as? [String: Any]
        XCTAssertEqual(updated?["isOn"] as? Bool, false)
    }

    // MARK: - POST /device/:id/set

    func testSetDeviceStateWithBrightness() {
        let d = Fixtures.makeDevice(id: "dev4", name: "Lamp", type: .light, isOn: false)
        mock.devices = [d]
        let resp = parseHTTPResponse(server.handleRequest(
            request("POST", "/device/dev4/set", body: ["on": true, "brightness": 80])
        ))
        XCTAssertEqual(resp.statusCode, 200)
        let updated = resp.json?["device"] as? [String: Any]
        XCTAssertEqual(updated?["isOn"] as? Bool, true)
        XCTAssertEqual(updated?["brightness"] as? Int, 80)
    }

    func testSetDeviceStateNotFound() {
        let resp = parseHTTPResponse(server.handleRequest(
            request("POST", "/device/nobody/set", body: ["on": true])
        ))
        XCTAssertEqual(resp.statusCode, 404)
    }

    // MARK: - GET /rooms

    func testGetRoomsReturnsSortedRooms() {
        mock.devices = [
            Fixtures.makeDevice(id: "a", name: "A", roomName: "Kitchen", isOn: true),
            Fixtures.makeDevice(id: "b", name: "B", roomName: "Kitchen", isOn: false),
            Fixtures.makeDevice(id: "c", name: "C", roomName: "Bedroom", isOn: true)
        ]
        let resp = parseHTTPResponse(server.handleRequest(request("GET", "/rooms")))
        XCTAssertEqual(resp.statusCode, 200)
        let rooms = resp.json?["rooms"] as? [[String: Any]]
        XCTAssertNotNil(rooms)
        let names = rooms?.compactMap { $0["name"] as? String }
        XCTAssertEqual(names, ["Bedroom", "Kitchen"]) // sorted
        let kitchen = rooms?.first { $0["name"] as? String == "Kitchen" }
        XCTAssertEqual(kitchen?["deviceCount"] as? Int, 2)
        XCTAssertEqual(kitchen?["onCount"] as? Int, 1)
    }

    func testGetRoomsEmpty() {
        let resp = parseHTTPResponse(server.handleRequest(request("GET", "/rooms")))
        XCTAssertEqual(resp.statusCode, 200)
        let rooms = resp.json?["rooms"] as? [[String: Any]]
        XCTAssertEqual(rooms?.count, 0)
    }

    // MARK: - POST /room/:id/on

    func testTurnRoomOnSuccess() {
        mock.devices = [
            Fixtures.makeDevice(id: "r1", name: "Light A", roomName: "Office", isOn: false),
            Fixtures.makeDevice(id: "r2", name: "Light B", roomName: "Office", isOn: false)
        ]
        let resp = parseHTTPResponse(server.handleRequest(request("POST", "/room/Office/on")))
        XCTAssertEqual(resp.statusCode, 200)
        XCTAssertEqual(resp.json?["success"] as? Bool, true)
    }

    func testTurnRoomOnNotFound() {
        let resp = parseHTTPResponse(server.handleRequest(request("POST", "/room/Narnia/on")))
        XCTAssertEqual(resp.statusCode, 404)
    }

    func testTurnRoomOffSuccess() {
        mock.devices = [
            Fixtures.makeDevice(id: "r3", name: "Light C", roomName: "Garage", isOn: true)
        ]
        let resp = parseHTTPResponse(server.handleRequest(request("POST", "/room/Garage/off")))
        XCTAssertEqual(resp.statusCode, 200)
        XCTAssertEqual(resp.json?["success"] as? Bool, true)
    }

    // MARK: - GET /scenes

    func testGetScenesReturnsList() {
        mock.scenes = [
            Fixtures.makeScene(id: "s1", name: "Good Night"),
            Fixtures.makeScene(id: "s2", name: "Morning")
        ]
        let resp = parseHTTPResponse(server.handleRequest(request("GET", "/scenes")))
        XCTAssertEqual(resp.statusCode, 200)
        let scenes = resp.json?["scenes"] as? [[String: Any]]
        XCTAssertEqual(scenes?.count, 2)
        let names = scenes?.compactMap { $0["name"] as? String }
        XCTAssertTrue(names?.contains("Good Night") == true)
    }

    // MARK: - POST /scene/:id/trigger

    func testTriggerSceneByIdSuccess() {
        mock.scenes = [Fixtures.makeScene(id: "scene-1", name: "Movie Night")]
        let resp = parseHTTPResponse(server.handleRequest(request("POST", "/scene/scene-1/trigger")))
        XCTAssertEqual(resp.statusCode, 200)
        XCTAssertEqual(resp.json?["success"] as? Bool, true)
    }

    func testTriggerSceneByNameSuccess() {
        mock.scenes = [Fixtures.makeScene(id: "scene-2", name: "Party")]
        let resp = parseHTTPResponse(server.handleRequest(request("POST", "/scene/Party/trigger")))
        XCTAssertEqual(resp.statusCode, 200)
        XCTAssertEqual(resp.json?["success"] as? Bool, true)
    }

    func testTriggerSceneFailure() {
        mock.triggerSceneResult = false
        let resp = parseHTTPResponse(server.handleRequest(request("POST", "/scene/ghost-scene/trigger")))
        XCTAssertEqual(resp.statusCode, 500)
    }

    // MARK: - 404 Unknown Path

    func testUnknownPathReturns404() {
        let resp = parseHTTPResponse(server.handleRequest(request("GET", "/nonexistent")))
        XCTAssertEqual(resp.statusCode, 404)
        XCTAssertNotNil(resp.json?["error"])
    }

    func testUnknownMethodReturns404() {
        let resp = parseHTTPResponse(server.handleRequest(request("DELETE", "/devices")))
        XCTAssertEqual(resp.statusCode, 404)
    }

    // MARK: - Route method (direct)

    func testRouteHealthDirect() {
        let raw = server.route(method: "GET", path: "/health")
        let resp = parseHTTPResponse(raw)
        XCTAssertEqual(resp.statusCode, 200)
    }

    func testRouteUnderscoreToSpaceNormalization() {
        mock.devices = [Fixtures.makeDevice(id: "n1", name: "Desk Lamp")]
        let raw = server.route(method: "GET", path: "/device/Desk_Lamp")
        let resp = parseHTTPResponse(raw)
        XCTAssertEqual(resp.statusCode, 200)
        XCTAssertEqual(resp.json?["name"] as? String, "Desk Lamp")
    }

    // MARK: - GET /rules

    func testGetRulesEndpoint() {
        let resp = parseHTTPResponse(server.handleRequest(request("GET", "/rules")))
        XCTAssertEqual(resp.statusCode, 200)
        XCTAssertNotNil(resp.json?["rules"])
        XCTAssertNotNil(resp.json?["active"])
    }

    // MARK: - Bad Request

    func testMalformedRequestLineReturns400() {
        let raw = "GARBAGE\r\n\r\n"
        let resp = parseHTTPResponse(server.handleRequest(raw))
        XCTAssertEqual(resp.statusCode, 400)
    }

    func testEmptyRequestReturns400() {
        let resp = parseHTTPResponse(server.handleRequest(""))
        XCTAssertEqual(resp.statusCode, 400)
    }

    // MARK: - Schema endpoint

    func testGetDeviceSchemaForLight() {
        mock.devices = [Fixtures.makeDevice(id: "s1", name: "Bulb", type: .light)]
        let resp = parseHTTPResponse(server.handleRequest(request("GET", "/device/s1/schema")))
        XCTAssertEqual(resp.statusCode, 200)
        let props = resp.json?["properties"] as? [String: Any]
        XCTAssertNotNil(props?["brightness"])
    }

    func testGetDeviceSchemaNotFound() {
        let resp = parseHTTPResponse(server.handleRequest(request("GET", "/device/ghost/schema")))
        XCTAssertEqual(resp.statusCode, 404)
    }

    // MARK: - Room-scoped device control

    func testGetRoomDeviceStatus() {
        mock.devices = [Fixtures.makeDevice(id: "rd1", name: "Sconce", roomName: "Hallway", isOn: true)]
        let resp = parseHTTPResponse(server.handleRequest(request("GET", "/room/Hallway/device/Sconce")))
        XCTAssertEqual(resp.statusCode, 200)
        XCTAssertEqual(resp.json?["name"] as? String, "Sconce")
    }

    func testToggleRoomDevice() {
        mock.devices = [Fixtures.makeDevice(id: "rd2", name: "Lamp", roomName: "Den", isOn: false)]
        let resp = parseHTTPResponse(server.handleRequest(request("POST", "/room/Den/device/Lamp/toggle")))
        XCTAssertEqual(resp.statusCode, 200)
        XCTAssertEqual(resp.json?["success"] as? Bool, true)
    }

    func testRoomDeviceNotFound() {
        let resp = parseHTTPResponse(server.handleRequest(request("GET", "/room/Narnia/device/Torch")))
        XCTAssertEqual(resp.statusCode, 404)
    }
}
