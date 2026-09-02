import Foundation

/// Protocol abstracting HomeKitManager for testability.
/// Mirrors the public interface of HomeKitManager so HTTPServer and
/// RuleEngine can be tested with mock implementations.
protocol HomeKitManagerProtocol: AnyObject {
    var devices: [HomeDevice] { get }
    var scenes: [HomeScene] { get }

    func getDevice(byId id: String) -> HomeDevice?
    func getDevice(byName name: String) -> HomeDevice?
    func getScene(byId id: String) -> HomeScene?
    func getScene(byName name: String) -> HomeScene?

    func toggleDevice(_ device: HomeDevice, completion: @escaping (Bool) -> Void)
    func setDeviceState(_ device: HomeDevice, on: Bool, brightness: Int?, completion: @escaping (Bool) -> Void)
    func triggerScene(named name: String, completion: @escaping (Bool) -> Void)
    func triggerScene(id: String, completion: @escaping (Bool) -> Void)

    // For /debug endpoint
    var homeManagerHomesCount: Int { get }
    var homeManagerAuthStatus: UInt { get }
}

// MARK: - Default lookup implementations
//
// These default implementations live here so that every conformer (including
// mocks) gets correct, non-duplicated lookup behaviour for free.
// Concrete types such as HomeKitManager can override with richer strategies
// (e.g. fuzzy word matching) without losing the shared baseline.

extension HomeKitManagerProtocol {
    func getDevice(byId id: String) -> HomeDevice? {
        devices.first { $0.id == id }
    }

    func getDevice(byName name: String) -> HomeDevice? {
        let normalizedQuery = normalizeDeviceName(name)
        return devices.first { normalizeDeviceName($0.name) == normalizedQuery }
            ?? devices.first { deviceNameMatches(query: name, candidate: $0.name) }
    }

    func getScene(byId id: String) -> HomeScene? {
        scenes.first { $0.id == id }
    }

    func getScene(byName name: String) -> HomeScene? {
        scenes.first { $0.name.lowercased().contains(name.lowercased()) }
    }
}

// MARK: - HomeKitManager conformance

extension HomeKitManager: HomeKitManagerProtocol {
    var homeManagerHomesCount: Int {
        homeManager.homes.count
    }

    var homeManagerAuthStatus: UInt {
        homeManager.authorizationStatus.rawValue
    }
}
