import Foundation
import Network

class HTTPServer {
    private var listener: NWListener?
    private let homeKitManager: HomeKitManager
    private let ruleEngine: RuleEngine
    private let homieState: HomieState
    private let port: UInt16 = 8420
    
    init(homeKitManager: HomeKitManager, ruleEngine: RuleEngine, homieState: HomieState) {
        self.homeKitManager = homeKitManager
        self.ruleEngine = ruleEngine
        self.homieState = homieState
    }
    
    func start() {
        do {
            let params = NWParameters.tcp
            params.requiredLocalEndpoint = NWEndpoint.hostPort(
                host: NWEndpoint.Host("127.0.0.1"),
                port: NWEndpoint.Port(rawValue: port)!
            )
            
            listener = try NWListener(using: params)
            
            listener?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    NSLog("[HTTP] Server listening on http://127.0.0.1:\(self.port)")
                case .failed(let error):
                    NSLog("[HTTP] Server failed: \(error)")
                default:
                    break
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener?.start(queue: .global())
        } catch {
            NSLog("[HTTP] Failed to start: \(error)")
        }
    }
    
    func stop() {
        listener?.cancel()
        listener = nil
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global())
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, _ in
            if let data = data, let request = String(data: data, encoding: .utf8) {
                let response = self?.handleRequest(request) ?? self?.errorResponse(500, "Internal error")
                
                if let responseData = response?.data(using: .utf8) {
                    connection.send(content: responseData, completion: .contentProcessed { _ in
                        connection.cancel()
                    })
                }
            } else {
                connection.cancel()
            }
        }
    }
    
    private func handleRequest(_ request: String) -> String {
        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            return errorResponse(400, "Bad request")
        }
        
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else {
            return errorResponse(400, "Bad request")
        }
        
        let method = String(parts[0])
        // URL decode only - underscore replacement happens when extracting names
        let path = String(parts[1]).removingPercentEncoding ?? String(parts[1])
        
        var body: [String: Any]? = nil
        if method == "POST", let bodyStart = request.range(of: "\r\n\r\n") {
            let bodyString = String(request[bodyStart.upperBound...])
            if let data = bodyString.data(using: .utf8) {
                body = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            }
        }
        
        return route(method: method, path: path, body: body)
    }
    
    private func route(method: String, path: String, body: [String: Any]?) -> String {
        NSLog("[HTTP] \(method) \(path)")
        homieState.incrementRequestCount()
        
        // MARK: - Health & Debug
        
        if path == "/health" {
            return jsonResponse(["status": "ok", "port": port, "app": "Homie"])
        }
        
        // Echo endpoint for debugging
        if path.hasPrefix("/echo/") {
            let value = String(path.dropFirst("/echo/".count))
            return jsonResponse(["received": value, "length": value.count, "bytes": Array(value.utf8)])
        }
        
        if path == "/debug" {
            let homes = homeKitManager.homeManager.homes
            let authStatus = homeKitManager.homeManager.authorizationStatus.rawValue
            return jsonResponse([
                "authStatus": authStatus,
                "homesCount": homes.count,
                "devicesLoaded": homeKitManager.devices.count,
                "scenesLoaded": homeKitManager.scenes.count,
                "activeRules": Array(ruleEngine.activeRules)
            ])
        }
        
        // MARK: - Devices
        
        if method == "GET" && path == "/devices" {
            let devices = homeKitManager.devices.map { deviceToDict($0) }
            return jsonResponse(["devices": devices])
        }
        
        // Device schema
        if method == "GET" && path.hasSuffix("/schema") {
            let pathWithoutSchema = String(path.dropLast("/schema".count))
            let id = normalizeName(String(pathWithoutSchema.dropFirst("/device/".count)))
            
            guard let device = homeKitManager.getDevice(byId: id) ?? homeKitManager.getDevice(byName: id) else {
                return errorResponse(404, "Device not found")
            }
            
            var schema: [String: Any] = [
                "device": device.name,
                "type": device.type.rawValue,
                "properties": [String: Any]()
            ]
            
            var properties: [String: Any] = [
                "on": ["type": "boolean", "description": "Turn device on or off"]
            ]
            
            // Add brightness for lights
            if device.type == .light {
                properties["brightness"] = [
                    "type": "integer",
                    "minimum": 0,
                    "maximum": 100,
                    "description": "Brightness percentage"
                ]
            }
            
            schema["properties"] = properties
            schema["example"] = exampleBody(for: device)
            
            return jsonResponse(schema)
        }
        
        if method == "GET" && path.hasPrefix("/device/") && !path.contains("/toggle") && !path.contains("/set") && !path.contains("/schema") {
            let id = normalizeName(String(path.dropFirst("/device/".count)))
            NSLog("[HTTP] Looking up device: '\(id)'")
            if let device = homeKitManager.getDevice(byId: id) ?? homeKitManager.getDevice(byName: id) {
                return jsonResponse(deviceToDict(device))
            }
            // Better error message with suggestions
            let suggestions = homeKitManager.devices
                .filter { $0.name.lowercased().contains(id.lowercased().prefix(3)) }
                .prefix(3)
                .map { $0.name }
            if suggestions.isEmpty {
                return errorResponse(404, "Device '\(id)' not found. Use /devices to list all.")
            } else {
                return errorResponse(404, "Device '\(id)' not found. Did you mean: \(suggestions.joined(separator: ", "))?")
            }
        }
        
        if method == "POST" && path.hasSuffix("/toggle") && !path.contains("/room/") {
            let pathWithoutToggle = String(path.dropLast("/toggle".count))
            let id = normalizeName(String(pathWithoutToggle.dropFirst("/device/".count)))
            NSLog("[HTTP] Toggle device: '\(id)'")
            
            guard let device = homeKitManager.getDevice(byId: id) ?? homeKitManager.getDevice(byName: id) else {
                let suggestions = homeKitManager.devices
                    .filter { $0.name.lowercased().contains(id.lowercased().prefix(3)) }
                    .prefix(3)
                    .map { $0.name }
                if suggestions.isEmpty {
                    return errorResponse(404, "Device '\(id)' not found. Use /devices to list all.")
                } else {
                    return errorResponse(404, "Device '\(id)' not found. Did you mean: \(suggestions.joined(separator: ", "))?")
                }
            }
            
            let semaphore = DispatchSemaphore(value: 0)
            var success = false
            
            homeKitManager.toggleDevice(device) { result in
                success = result
                semaphore.signal()
            }
            
            _ = semaphore.wait(timeout: .now() + 10)
            
            if success {
                if let updated = homeKitManager.getDevice(byId: device.id) {
                    return jsonResponse(["success": true, "device": deviceToDict(updated)])
                }
                return jsonResponse(["success": true])
            }
            return errorResponse(500, "Failed to toggle device")
        }

        if method == "POST" && path.hasSuffix("/on") && !path.contains("/room/") {
            let pathWithoutOn = String(path.dropLast("/on".count))
            let id = normalizeName(String(pathWithoutOn.dropFirst("/device/".count)))
            NSLog("[HTTP] Turn device on: '\(id)'")

            guard let device = homeKitManager.getDevice(byId: id) ?? homeKitManager.getDevice(byName: id) else {
                let suggestions = homeKitManager.devices
                    .filter { $0.name.lowercased().contains(id.lowercased().prefix(3)) }
                    .prefix(3)
                    .map { $0.name }
                if suggestions.isEmpty {
                    return errorResponse(404, "Device '\(id)' not found. Use /devices to list all.")
                } else {
                    return errorResponse(404, "Device '\(id)' not found. Did you mean: \(suggestions.joined(separator: ", "))?")
                }
            }

            let semaphore = DispatchSemaphore(value: 0)
            var success = false

            homeKitManager.setDeviceState(device, on: true, brightness: nil) { result in
                success = result
                semaphore.signal()
            }

            _ = semaphore.wait(timeout: .now() + 10)

            if success {
                if let updated = homeKitManager.getDevice(byId: device.id) {
                    return jsonResponse(["success": true, "device": deviceToDict(updated)])
                }
                return jsonResponse(["success": true])
            }
            return errorResponse(500, "Failed to turn device on")
        }

        if method == "POST" && path.hasSuffix("/off") && !path.contains("/room/") {
            let pathWithoutOff = String(path.dropLast("/off".count))
            let id = normalizeName(String(pathWithoutOff.dropFirst("/device/".count)))
            NSLog("[HTTP] Turn device off: '\(id)'")

            guard let device = homeKitManager.getDevice(byId: id) ?? homeKitManager.getDevice(byName: id) else {
                let suggestions = homeKitManager.devices
                    .filter { $0.name.lowercased().contains(id.lowercased().prefix(3)) }
                    .prefix(3)
                    .map { $0.name }
                if suggestions.isEmpty {
                    return errorResponse(404, "Device '\(id)' not found. Use /devices to list all.")
                } else {
                    return errorResponse(404, "Device '\(id)' not found. Did you mean: \(suggestions.joined(separator: ", "))?")
                }
            }

            let semaphore = DispatchSemaphore(value: 0)
            var success = false

            homeKitManager.setDeviceState(device, on: false, brightness: nil) { result in
                success = result
                semaphore.signal()
            }

            _ = semaphore.wait(timeout: .now() + 10)

            if success {
                if let updated = homeKitManager.getDevice(byId: device.id) {
                    return jsonResponse(["success": true, "device": deviceToDict(updated)])
                }
                return jsonResponse(["success": true])
            }
            return errorResponse(500, "Failed to turn device off")
        }
        
        if method == "POST" && path.hasSuffix("/set") && !path.contains("/room/") {
            let pathWithoutSet = String(path.dropLast("/set".count))
            let id = normalizeName(String(pathWithoutSet.dropFirst("/device/".count)))
            
            guard let device = homeKitManager.getDevice(byId: id) ?? homeKitManager.getDevice(byName: id) else {
                return errorResponse(404, "Device not found")
            }
            
            let on = body?["on"] as? Bool ?? device.isOn
            let brightness = body?["brightness"] as? Int
            
            let semaphore = DispatchSemaphore(value: 0)
            var success = false
            
            homeKitManager.setDeviceState(device, on: on, brightness: brightness) { result in
                success = result
                semaphore.signal()
            }
            
            _ = semaphore.wait(timeout: .now() + 10)
            
            if success {
                if let updated = homeKitManager.getDevice(byId: device.id) {
                    return jsonResponse(["success": true, "device": deviceToDict(updated)])
                }
                return jsonResponse(["success": true])
            }
            return errorResponse(500, "Failed to set device state")
        }
        
        // MARK: - Rooms
        
        if method == "GET" && path == "/rooms" {
            let rooms = Set(homeKitManager.devices.compactMap { $0.roomName }).sorted()
            let roomData = rooms.map { room -> [String: Any] in
                let devicesInRoom = homeKitManager.devices.filter { $0.roomName == room }
                let onCount = devicesInRoom.filter { $0.isOn }.count
                return [
                    "name": room,
                    "deviceCount": devicesInRoom.count,
                    "onCount": onCount
                ]
            }
            return jsonResponse(["rooms": roomData])
        }
        
        if method == "GET" && path.hasPrefix("/room/") && !path.contains("/on") && !path.contains("/off") && !path.contains("/device/") {
            let roomName = normalizeName(String(path.dropFirst("/room/".count)))
            let devicesInRoom = homeKitManager.devices.filter { 
                $0.roomName?.lowercased() == roomName.lowercased() 
            }
            if devicesInRoom.isEmpty {
                return errorResponse(404, "Room '\(roomName)' not found")
            }
            return jsonResponse([
                "room": roomName,
                "devices": devicesInRoom.map { deviceToDict($0) }
            ])
        }
        
        if method == "POST" && path.hasPrefix("/room/") && path.hasSuffix("/on") && !path.contains("/device/") {
            let roomName = normalizeName(String(path.dropFirst("/room/".count).dropLast("/on".count)))
            let devicesInRoom = homeKitManager.devices.filter { 
                $0.roomName?.lowercased() == roomName.lowercased() 
            }
            if devicesInRoom.isEmpty {
                return errorResponse(404, "Room '\(roomName)' not found")
            }
            
            var successCount = 0
            let group = DispatchGroup()
            
            for device in devicesInRoom where !device.isOn {
                group.enter()
                homeKitManager.setDeviceState(device, on: true, brightness: nil) { success in
                    if success { successCount += 1 }
                    group.leave()
                }
            }
            
            _ = group.wait(timeout: .now() + 10)
            return jsonResponse(["success": true, "room": roomName, "devicesChanged": successCount])
        }
        
        if method == "POST" && path.hasPrefix("/room/") && path.hasSuffix("/off") && !path.contains("/device/") {
            let roomName = normalizeName(String(path.dropFirst("/room/".count).dropLast("/off".count)))
            let devicesInRoom = homeKitManager.devices.filter { 
                $0.roomName?.lowercased() == roomName.lowercased() 
            }
            if devicesInRoom.isEmpty {
                return errorResponse(404, "Room '\(roomName)' not found")
            }
            
            var successCount = 0
            let group = DispatchGroup()
            
            for device in devicesInRoom where device.isOn {
                group.enter()
                homeKitManager.setDeviceState(device, on: false, brightness: nil) { success in
                    if success { successCount += 1 }
                    group.leave()
                }
            }
            
            _ = group.wait(timeout: .now() + 10)
            return jsonResponse(["success": true, "room": roomName, "devicesChanged": successCount])
        }
        
        // Room-scoped device control: /room/{room}/device/{device}/...
        if path.hasPrefix("/room/") && path.contains("/device/") {
            // Parse: /room/{room}/device/{device}/{action}
            let withoutPrefix = String(path.dropFirst("/room/".count))
            guard let deviceIndex = withoutPrefix.range(of: "/device/") else {
                return errorResponse(400, "Invalid path")
            }
            
            let roomName = normalizeName(String(withoutPrefix[..<deviceIndex.lowerBound]))
            let afterDevice = String(withoutPrefix[deviceIndex.upperBound...])
            
            // Find device and action
            var deviceName: String
            var action: String? = nil
            
            if let actionIndex = afterDevice.lastIndex(of: "/") {
                deviceName = normalizeName(String(afterDevice[..<actionIndex]))
                action = String(afterDevice[afterDevice.index(after: actionIndex)...])
            } else {
                deviceName = normalizeName(afterDevice)
            }
            
            // Find device in specific room
            guard let device = homeKitManager.devices.first(where: { 
                $0.name.lowercased() == deviceName.lowercased() && 
                $0.roomName?.lowercased() == roomName.lowercased()
            }) else {
                return errorResponse(404, "Device '\(deviceName)' not found in room '\(roomName)'")
            }
            
            // GET /room/{room}/device/{device} - status
            if method == "GET" && action == nil {
                return jsonResponse(deviceToDict(device))
            }
            
            // POST /room/{room}/device/{device}/toggle
            if method == "POST" && action == "toggle" {
                let semaphore = DispatchSemaphore(value: 0)
                var success = false
                homeKitManager.toggleDevice(device) { result in
                    success = result
                    semaphore.signal()
                }
                _ = semaphore.wait(timeout: .now() + 10)
                if success {
                    if let updated = homeKitManager.getDevice(byId: device.id) {
                        return jsonResponse(["success": true, "device": deviceToDict(updated)])
                    }
                    return jsonResponse(["success": true])
                }
                return errorResponse(500, "Failed to toggle device")
            }
            
            // POST /room/{room}/device/{device}/on
            if method == "POST" && action == "on" {
                let semaphore = DispatchSemaphore(value: 0)
                var success = false
                homeKitManager.setDeviceState(device, on: true, brightness: nil) { result in
                    success = result
                    semaphore.signal()
                }
                _ = semaphore.wait(timeout: .now() + 10)
                if success {
                    if let updated = homeKitManager.getDevice(byId: device.id) {
                        return jsonResponse(["success": true, "device": deviceToDict(updated)])
                    }
                    return jsonResponse(["success": true])
                }
                return errorResponse(500, "Failed to turn device on")
            }
            
            // POST /room/{room}/device/{device}/off
            if method == "POST" && action == "off" {
                let semaphore = DispatchSemaphore(value: 0)
                var success = false
                homeKitManager.setDeviceState(device, on: false, brightness: nil) { result in
                    success = result
                    semaphore.signal()
                }
                _ = semaphore.wait(timeout: .now() + 10)
                if success {
                    if let updated = homeKitManager.getDevice(byId: device.id) {
                        return jsonResponse(["success": true, "device": deviceToDict(updated)])
                    }
                    return jsonResponse(["success": true])
                }
                return errorResponse(500, "Failed to turn device off")
            }
            
            // POST /room/{room}/device/{device}/set
            if method == "POST" && action == "set" {
                let on = body?["on"] as? Bool ?? device.isOn
                let brightness = body?["brightness"] as? Int
                let semaphore = DispatchSemaphore(value: 0)
                var success = false
                homeKitManager.setDeviceState(device, on: on, brightness: brightness) { result in
                    success = result
                    semaphore.signal()
                }
                _ = semaphore.wait(timeout: .now() + 10)
                return success ? jsonResponse(["success": true]) : errorResponse(500, "Failed")
            }
            
            return errorResponse(400, "Unknown action '\(action ?? "")'")
        }
        
        // MARK: - Scenes
        
        if method == "GET" && path == "/scenes" {
            let scenes = homeKitManager.scenes.map { sceneToDict($0) }
            return jsonResponse(["scenes": scenes])
        }
        
        if method == "POST" && path.hasPrefix("/scene/") && path.hasSuffix("/trigger") {
            let pathWithoutTrigger = String(path.dropLast("/trigger".count))
            let id = normalizeName(String(pathWithoutTrigger.dropFirst("/scene/".count)))
            
            let semaphore = DispatchSemaphore(value: 0)
            var success = false
            
            // Try by ID first, then by name
            if let scene = homeKitManager.getScene(byId: id) {
                homeKitManager.triggerScene(id: scene.id) { result in
                    success = result
                    semaphore.signal()
                }
            } else {
                homeKitManager.triggerScene(named: id) { result in
                    success = result
                    semaphore.signal()
                }
            }
            
            _ = semaphore.wait(timeout: .now() + 10)
            
            if success {
                return jsonResponse(["success": true])
            }
            return errorResponse(500, "Failed to trigger scene")
        }
        
        // MARK: - Rules
        
        if method == "GET" && path == "/rules" {
            let rules = ruleEngine.rules.map { ruleToDict($0) }
            return jsonResponse([
                "rules": rules,
                "active": Array(ruleEngine.activeRules)
            ])
        }
        
        if method == "POST" && path == "/rules" {
            guard let name = body?["name"] as? String,
                  let app = body?["app"] as? String else {
                return errorResponse(400, "Missing required fields: name, app")
            }
            
            let rule = HomieRule(
                name: name,
                conditions: HomieRule.Conditions(app: app),
                actions: [],
                revert: body?["revert"] as? Bool ?? true,
                enabled: body?["enabled"] as? Bool ?? true
            )
            
            ruleEngine.addRule(rule)
            return jsonResponse(["success": true, "rule": ruleToDict(rule)])
        }
        
        return errorResponse(404, "Not found")
    }
    
    // MARK: - Helpers
    
    // Convert underscores to spaces in names
    private func normalizeName(_ name: String) -> String {
        return name.replacingOccurrences(of: "_", with: " ")
    }
    
    private func exampleBody(for device: HomeDevice) -> [String: Any] {
        var example: [String: Any] = ["on": true]
        if device.type == .light {
            example["brightness"] = 80
        }
        return example
    }
    
    private func deviceToDict(_ device: HomeDevice) -> [String: Any] {
        var dict: [String: Any] = [
            "id": device.id,
            "name": device.name,
            "type": device.type.rawValue,
            "isOn": device.isOn
        ]
        if let room = device.roomName { dict["room"] = room }
        if let brightness = device.brightness { dict["brightness"] = brightness }
        return dict
    }
    
    private func sceneToDict(_ scene: HomeScene) -> [String: Any] {
        return [
            "id": scene.id,
            "name": scene.name,
            "home": scene.homeName,
            "actions": scene.actionCount
        ]
    }
    
    private func ruleToDict(_ rule: HomieRule) -> [String: Any] {
        return [
            "id": rule.id,
            "name": rule.name,
            "app": rule.conditions.app ?? "",
            "enabled": rule.enabled,
            "revert": rule.revert
        ]
    }
    
    private func jsonResponse(_ data: Any) -> String {
        let json = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
        let body = json.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        
        return """
        HTTP/1.1 200 OK\r
        Content-Type: application/json\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """
    }
    
    private func errorResponse(_ code: Int, _ message: String) -> String {
        let body = "{\"error\": \"\(message)\"}"
        let status = code == 404 ? "Not Found" : (code == 400 ? "Bad Request" : "Internal Server Error")
        
        return """
        HTTP/1.1 \(code) \(status)\r
        Content-Type: application/json\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """
    }
}
