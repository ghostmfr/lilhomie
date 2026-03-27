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
    var homeManagerAuthStatus: Int { get }
}

// MARK: - HomeKitManager conformance

extension HomeKitManager: HomeKitManagerProtocol {
    var homeManagerHomesCount: Int {
        homeManager.homes.count
    }

    var homeManagerAuthStatus: Int {
        homeManager.authorizationStatus.rawValue
    }
}
