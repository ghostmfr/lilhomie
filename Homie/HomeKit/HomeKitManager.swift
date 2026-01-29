import Foundation
import HomeKit
import os.log

private let logger = Logger(subsystem: "com.homie.app", category: "HomeKit")

extension Notification.Name {
    static let devicesUpdated = Notification.Name("devicesUpdated")
    static let scenesUpdated = Notification.Name("scenesUpdated")
}

struct HomeDevice: Codable, Identifiable {
    let id: String
    let name: String
    let roomName: String?
    let type: DeviceType
    var isOn: Bool
    var brightness: Int?
    
    var stateEmoji: String {
        isOn ? "🟢" : "⚪️"
    }
    
    enum DeviceType: String, Codable {
        case light
        case outlet
        case switchDevice = "switch"
        case fan
        case thermostat
        case unknown
    }
}

struct HomeScene: Identifiable {
    let id: String
    let name: String
    let homeName: String
    let actionCount: Int
}

class HomeKitManager: NSObject, ObservableObject {
    let homeManager = HMHomeManager()
    @Published var devices: [HomeDevice] = []
    @Published var scenes: [HomeScene] = []
    
    private var accessoryCharacteristics: [String: HMCharacteristic] = [:]
    private var sceneObjects: [String: HMActionSet] = [:]
    
    override init() {
        super.init()
        homeManager.delegate = self
    }
    
    // MARK: - Authorization
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        NSLog("[HomeKit] Requesting authorization...")
        NSLog("[HomeKit] Authorization status: \(homeManager.authorizationStatus.rawValue)")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            let homes = self?.homeManager.homes ?? []
            NSLog("[HomeKit] Homes available: \(homes.count)")
            completion(!homes.isEmpty)
        }
    }
    
    // MARK: - Devices
    
    func loadDevices() {
        NSLog("[HomeKit] Loading devices...")
        var allDevices: [HomeDevice] = []
        accessoryCharacteristics.removeAll()
        
        for home in homeManager.homes {
            for accessory in home.accessories {
                guard let device = createDevice(from: accessory, in: home) else { continue }
                allDevices.append(device)
            }
        }
        
        NSLog("[HomeKit] Loaded \(allDevices.count) devices")
        DispatchQueue.main.async {
            self.devices = allDevices.sorted { $0.name < $1.name }
            NotificationCenter.default.post(name: .devicesUpdated, object: nil)
        }
    }
    
    private func createDevice(from accessory: HMAccessory, in home: HMHome) -> HomeDevice? {
        var powerCharacteristic: HMCharacteristic?
        var brightnessCharacteristic: HMCharacteristic?
        var deviceType: HomeDevice.DeviceType = .unknown
        
        for service in accessory.services {
            for characteristic in service.characteristics {
                if characteristic.characteristicType == HMCharacteristicTypePowerState {
                    powerCharacteristic = characteristic
                    deviceType = determineType(from: service)
                }
                if characteristic.characteristicType == HMCharacteristicTypeBrightness {
                    brightnessCharacteristic = characteristic
                }
            }
        }
        
        guard let power = powerCharacteristic else { return nil }
        
        let deviceId = accessory.uniqueIdentifier.uuidString
        accessoryCharacteristics[deviceId] = power
        
        if let brightness = brightnessCharacteristic {
            accessoryCharacteristics["\(deviceId)-brightness"] = brightness
        }
        
        let isOn = (power.value as? Bool) ?? false
        let brightness = brightnessCharacteristic?.value as? Int
        
        let room = home.rooms.first { room in
            room.accessories.contains { $0.uniqueIdentifier == accessory.uniqueIdentifier }
        }
        
        return HomeDevice(
            id: deviceId,
            name: accessory.name,
            roomName: room?.name,
            type: deviceType,
            isOn: isOn,
            brightness: brightness
        )
    }
    
    private func determineType(from service: HMService) -> HomeDevice.DeviceType {
        switch service.serviceType {
        case HMServiceTypeLightbulb: return .light
        case HMServiceTypeOutlet: return .outlet
        case HMServiceTypeSwitch: return .switchDevice
        case HMServiceTypeFan: return .fan
        case HMServiceTypeThermostat: return .thermostat
        default: return .unknown
        }
    }
    
    // MARK: - Scenes
    
    func loadScenes() {
        NSLog("[HomeKit] Loading scenes...")
        var allScenes: [HomeScene] = []
        sceneObjects.removeAll()
        
        for home in homeManager.homes {
            for actionSet in home.actionSets {
                let scene = HomeScene(
                    id: actionSet.uniqueIdentifier.uuidString,
                    name: actionSet.name,
                    homeName: home.name,
                    actionCount: actionSet.actions.count
                )
                allScenes.append(scene)
                sceneObjects[scene.id] = actionSet
                sceneObjects[actionSet.name.lowercased()] = actionSet  // Also index by name
            }
        }
        
        NSLog("[HomeKit] Loaded \(allScenes.count) scenes")
        DispatchQueue.main.async {
            self.scenes = allScenes.sorted { $0.name < $1.name }
            NotificationCenter.default.post(name: .scenesUpdated, object: nil)
        }
    }
    
    func triggerScene(named name: String, completion: @escaping (Bool) -> Void) {
        // Try exact match first
        if let actionSet = sceneObjects[name.lowercased()] {
            executeScene(actionSet, completion: completion)
            return
        }
        
        // Try fuzzy match
        let lowercaseName = name.lowercased()
        for (key, actionSet) in sceneObjects {
            if key.contains(lowercaseName) {
                executeScene(actionSet, completion: completion)
                return
            }
        }
        
        NSLog("[HomeKit] Scene not found: \(name)")
        completion(false)
    }
    
    func triggerScene(id: String, completion: @escaping (Bool) -> Void) {
        guard let actionSet = sceneObjects[id] else {
            completion(false)
            return
        }
        executeScene(actionSet, completion: completion)
    }
    
    private func executeScene(_ actionSet: HMActionSet, completion: @escaping (Bool) -> Void) {
        guard let home = homeManager.homes.first(where: { $0.actionSets.contains(actionSet) }) else {
            completion(false)
            return
        }
        
        NSLog("[HomeKit] Executing scene: \(actionSet.name)")
        home.executeActionSet(actionSet) { error in
            if let error = error {
                NSLog("[HomeKit] Scene execution failed: \(error)")
                completion(false)
            } else {
                NSLog("[HomeKit] Scene executed successfully")
                // Reload devices to reflect new state
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.loadDevices()
                }
                completion(true)
            }
        }
    }
    
    // MARK: - Device Control
    
    func toggleDevice(_ device: HomeDevice, completion: @escaping (Bool) -> Void) {
        setDeviceState(device, on: !device.isOn, completion: completion)
    }
    
    func setDeviceState(_ device: HomeDevice, on: Bool, brightness: Int? = nil, completion: @escaping (Bool) -> Void) {
        guard let characteristic = accessoryCharacteristics[device.id] else {
            completion(false)
            return
        }
        
        characteristic.writeValue(on) { [weak self] error in
            if let error = error {
                NSLog("[HomeKit] Error setting device state: \(error)")
                completion(false)
                return
            }
            
            if let brightness = brightness,
               let brightnessChar = self?.accessoryCharacteristics["\(device.id)-brightness"] {
                brightnessChar.writeValue(brightness) { error in
                    if let error = error {
                        NSLog("[HomeKit] Error setting brightness: \(error)")
                    }
                    self?.loadDevices()
                    completion(error == nil)
                }
            } else {
                self?.loadDevices()
                completion(true)
            }
        }
    }
    
    // MARK: - Lookups
    
    func getDevice(byId id: String) -> HomeDevice? {
        return devices.first { $0.id == id }
    }
    
    func getDevice(byName name: String) -> HomeDevice? {
        let lowercaseName = name.lowercased()
        
        // Exact match
        if let device = devices.first(where: { $0.name.lowercased() == lowercaseName }) {
            return device
        }
        
        // Contains match
        if let device = devices.first(where: { $0.name.lowercased().contains(lowercaseName) }) {
            return device
        }
        
        // Fuzzy match
        let searchWords = lowercaseName.split(separator: " ")
        for device in devices {
            let deviceWords = device.name.lowercased().split(separator: " ")
            if searchWords.allSatisfy({ searchWord in
                deviceWords.contains { $0.contains(searchWord) }
            }) {
                return device
            }
        }
        
        return nil
    }
    
    func getScene(byId id: String) -> HomeScene? {
        return scenes.first { $0.id == id }
    }
    
    func getScene(byName name: String) -> HomeScene? {
        let lowercaseName = name.lowercased()
        return scenes.first { $0.name.lowercased().contains(lowercaseName) }
    }
}

// MARK: - HMHomeManagerDelegate

extension HomeKitManager: HMHomeManagerDelegate {
    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        NSLog("[HomeKit] Homes updated: \(manager.homes.count)")
        loadDevices()
        loadScenes()
    }
    
    func homeManagerDidUpdatePrimaryHome(_ manager: HMHomeManager) {
        loadDevices()
        loadScenes()
    }
    
    func homeManager(_ manager: HMHomeManager, didUpdate status: HMHomeManagerAuthorizationStatus) {
        NSLog("[HomeKit] Authorization status: \(status.rawValue)")
    }
}
