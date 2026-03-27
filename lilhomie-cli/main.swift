#!/usr/bin/env swift

import Foundation

let baseURL = "http://127.0.0.1:8420"

// MARK: - Models

struct Device: Codable {
    let id: String
    let name: String
    let room: String?
    let type: String
    let isOn: Bool
    let brightness: Int?
}

struct Scene: Codable {
    let id: String
    let name: String
    let home: String
    let actions: Int
}

struct DevicesResponse: Codable {
    let devices: [Device]
}

struct ScenesResponse: Codable {
    let scenes: [Scene]
}

struct ActionResponse: Codable {
    let success: Bool?
    let device: Device?
    let error: String?
}

// MARK: - Argument Parsing

/// Strip `--json` / `-j` flags from args and return the cleaned args + flag state.
func parseGlobalFlags(_ rawArgs: [String]) -> (args: [String], jsonOutput: Bool) {
    var jsonOutput = false
    let filtered = rawArgs.filter { arg in
        if arg == "--json" || arg == "-j" {
            jsonOutput = true
            return false
        }
        return true
    }
    return (filtered, jsonOutput)
}

// MARK: - HTTP Client

func request(_ method: String, _ path: String, body: [String: Any]? = nil) -> Data? {
    guard let url = URL(string: baseURL + path) else { return nil }
    
    var req = URLRequest(url: url)
    req.httpMethod = method
    req.timeoutInterval = 10
    
    if let body = body {
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
    }
    
    let semaphore = DispatchSemaphore(value: 0)
    var result: Data?
    
    URLSession.shared.dataTask(with: req) { data, _, error in
        result = error == nil ? data : nil
        semaphore.signal()
    }.resume()
    
    _ = semaphore.wait(timeout: .now() + 15)
    return result
}

/// Pretty-print raw JSON data to stdout.
func printJSON(_ data: Data) {
    if let obj = try? JSONSerialization.jsonObject(with: data),
       let pretty = try? JSONSerialization.data(withJSONObject: obj, options: .prettyPrinted),
       let str = String(data: pretty, encoding: .utf8) {
        print(str)
    } else if let str = String(data: data, encoding: .utf8) {
        print(str)
    } else {
        print("{}")
    }
}

// MARK: - Shared Fetch Helper

/// Fetch data from the API and either emit raw JSON (when `jsonOutput` is true) or
/// decode the response to `T` and hand it to `display`.  Exits on network/decode failure.
func fetchAndDisplay<T: Decodable>(
    method: String,
    path: String,
    body: [String: Any]? = nil,
    jsonOutput: Bool,
    failMessage: String,
    as type: T.Type,
    display: (T) -> Void
) {
    guard let data = request(method, path, body: body) else {
        print(failMessage)
        exit(1)
    }
    if jsonOutput {
        printJSON(data)
        return
    }
    guard let decoded = try? JSONDecoder().decode(type, from: data) else {
        print(failMessage)
        exit(1)
    }
    display(decoded)
}

// MARK: - Commands

func listDevices(jsonOutput: Bool = false) {
    fetchAndDisplay(
        method: "GET", path: "/devices",
        jsonOutput: jsonOutput,
        failMessage: "❌ Failed to connect to Homie. Is the app running?",
        as: DevicesResponse.self
    ) { response in
        if response.devices.isEmpty {
            print("No devices found.")
            return
        }
        print("📱 HomeKit Devices:\n")
        let grouped = Dictionary(grouping: response.devices) { $0.room ?? "No Room" }
        for (room, devices) in grouped.sorted(by: { $0.key < $1.key }) {
            print("  \(room):")
            for device in devices.sorted(by: { $0.name < $1.name }) {
                let status = device.isOn ? "🟢" : "⚪️"
                let brightness = device.brightness.map { " (\($0)%)" } ?? ""
                print("    \(status) \(device.name)\(brightness)")
            }
            print("")
        }
        print("Total: \(response.devices.count) devices")
    }
}

func listScenes(jsonOutput: Bool = false) {
    fetchAndDisplay(
        method: "GET", path: "/scenes",
        jsonOutput: jsonOutput,
        failMessage: "❌ Failed to connect to Homie. Is the app running?",
        as: ScenesResponse.self
    ) { response in
        if response.scenes.isEmpty {
            print("No scenes found.")
            return
        }
        print("🎬 HomeKit Scenes:\n")
        for scene in response.scenes {
            print("  • \(scene.name) (\(scene.actions) actions)")
        }
        print("\nTotal: \(response.scenes.count) scenes")
    }
}

func getStatus(_ name: String, jsonOutput: Bool = false) {
    let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
    fetchAndDisplay(
        method: "GET", path: "/device/\(encoded)",
        jsonOutput: jsonOutput,
        failMessage: "❌ Device '\(name)' not found",
        as: Device.self
    ) { device in
        print("📱 \(device.name)")
        print("   Status: \(device.isOn ? "🟢 ON" : "⚪️ OFF")")
        if let brightness = device.brightness {
            print("   Brightness: \(brightness)%")
        }
        if let room = device.room {
            print("   Room: \(room)")
        }
    }
}

func toggleDevice(_ name: String, jsonOutput: Bool = false) {
    let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
    fetchAndDisplay(
        method: "POST", path: "/device/\(encoded)/toggle",
        jsonOutput: jsonOutput,
        failMessage: "❌ Failed to toggle '\(name)'",
        as: ActionResponse.self
    ) { response in
        if response.success == true {
            if let device = response.device {
                print("✅ \(device.name) → \(device.isOn ? "ON 🟢" : "OFF ⚪️")")
            } else {
                print("✅ Toggled '\(name)'")
            }
        } else {
            print("❌ \(response.error ?? "Unknown error")")
            exit(1)
        }
    }
}

func setDevice(_ name: String, on: Bool, jsonOutput: Bool = false) {
    let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
    fetchAndDisplay(
        method: "POST", path: "/device/\(encoded)/set",
        body: ["on": on],
        jsonOutput: jsonOutput,
        failMessage: "❌ Failed to set '\(name)'",
        as: ActionResponse.self
    ) { response in
        if response.success == true {
            print("✅ \(name) → \(on ? "ON 🟢" : "OFF ⚪️")")
        } else {
            print("❌ \(response.error ?? "Unknown error")")
            exit(1)
        }
    }
}

func setBrightness(_ name: String, _ level: Int, jsonOutput: Bool = false) {
    let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
    fetchAndDisplay(
        method: "POST", path: "/device/\(encoded)/set",
        body: ["on": true, "brightness": level],
        jsonOutput: jsonOutput,
        failMessage: "❌ Failed to set brightness for '\(name)'",
        as: ActionResponse.self
    ) { response in
        if response.success == true {
            print("✅ \(name) → \(level)%")
        } else {
            print("❌ \(response.error ?? "Unknown error")")
            exit(1)
        }
    }
}

func triggerScene(_ name: String, jsonOutput: Bool = false) {
    let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
    fetchAndDisplay(
        method: "POST", path: "/scene/\(encoded)/trigger",
        jsonOutput: jsonOutput,
        failMessage: "❌ Failed to trigger scene '\(name)'",
        as: ActionResponse.self
    ) { response in
        if response.success == true {
            print("✅ Scene '\(name)' triggered")
        } else {
            print("❌ \(response.error ?? "Scene not found")")
            exit(1)
        }
    }
}

func showStatus(jsonOutput: Bool = false) {
    guard let data = request("GET", "/debug") else {
        print("❌ Failed to connect to Homie. Is the app running?")
        exit(1)
    }
    if jsonOutput {
        printJSON(data)
        return
    }
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        print("❌ Failed to connect to Homie. Is the app running?")
        exit(1)
    }
    
    let devices = json["devicesLoaded"] as? Int ?? 0
    let scenes = json["scenesLoaded"] as? Int ?? 0
    let activeRules = json["activeRules"] as? [String] ?? []
    
    print("🏠 Homie Status")
    print("   Devices: \(devices)")
    print("   Scenes: \(scenes)")
    print("   Active Rules: \(activeRules.isEmpty ? "None" : activeRules.joined(separator: ", "))")
    print("   API: http://127.0.0.1:8420")
}

func printUsage() {
    print("""
    lilhomie - Homie CLI

    Usage:
      lilhomie list                    List all devices (grouped by room)
      lilhomie scenes                  List all scenes
      lilhomie status <name>           Get device status
      lilhomie toggle <name>           Toggle device on/off
      lilhomie on <name>               Turn device on
      lilhomie off <name>              Turn device off
      lilhomie set <name> <0-100>      Set brightness level
      lilhomie scene <name>            Trigger a scene
      lilhomie info                    Show Homie status

    Global flags:
      --json, -j                       Output raw JSON (great for piping into jq)

    Examples:
      lilhomie toggle "Office Lamp"
      lilhomie on office
      lilhomie set kitchen 50
      lilhomie scene "Good Night"
      lilhomie list --json | jq '.devices[] | select(.isOn) | .name'
      lilhomie status "Desk Lamp" -j
    """)
}

// MARK: - Main

let (args, jsonOutput) = parseGlobalFlags(Array(CommandLine.arguments.dropFirst()))

guard !args.isEmpty else {
    printUsage()
    exit(0)
}

switch args[0].lowercased() {
case "list", "ls", "devices":
    listDevices(jsonOutput: jsonOutput)
    
case "scenes":
    listScenes(jsonOutput: jsonOutput)
    
case "status", "get":
    guard args.count > 1 else {
        print("Usage: lilhomie status <device-name>")
        exit(1)
    }
    getStatus(args[1...].joined(separator: " "), jsonOutput: jsonOutput)
    
case "toggle":
    guard args.count > 1 else {
        print("Usage: lilhomie toggle <device-name>")
        exit(1)
    }
    toggleDevice(args[1...].joined(separator: " "), jsonOutput: jsonOutput)
    
case "on":
    guard args.count > 1 else {
        print("Usage: lilhomie on <device-name>")
        exit(1)
    }
    setDevice(args[1...].joined(separator: " "), on: true, jsonOutput: jsonOutput)
    
case "off":
    guard args.count > 1 else {
        print("Usage: lilhomie off <device-name>")
        exit(1)
    }
    setDevice(args[1...].joined(separator: " "), on: false, jsonOutput: jsonOutput)
    
case "set":
    guard args.count > 2, let level = Int(args.last!) else {
        print("Usage: lilhomie set <device-name> <0-100>")
        exit(1)
    }
    let name = args[1..<(args.count-1)].joined(separator: " ")
    setBrightness(name, max(0, min(100, level)), jsonOutput: jsonOutput)
    
case "scene":
    guard args.count > 1 else {
        print("Usage: lilhomie scene <scene-name>")
        exit(1)
    }
    triggerScene(args[1...].joined(separator: " "), jsonOutput: jsonOutput)
    
case "info", "status-all":
    showStatus(jsonOutput: jsonOutput)
    
case "help", "-h", "--help":
    printUsage()
    
default:
    print("Unknown command: \(args[0])")
    printUsage()
    exit(1)
}
