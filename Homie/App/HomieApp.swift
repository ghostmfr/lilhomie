import SwiftUI
import HomeKit

@main
struct HomieApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate.homeKitManager)
                .environmentObject(appDelegate.ruleEngine)
                .environmentObject(appDelegate.homieState)
        }
        
        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(appDelegate.homeKitManager)
                .environmentObject(appDelegate.ruleEngine)
        }
        #endif
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @EnvironmentObject var homeKitManager: HomeKitManager
    @EnvironmentObject var ruleEngine: RuleEngine
    @EnvironmentObject var homieState: HomieState
    
    @State private var selectedRoom: String? = nil
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with Homie character
                headerView
                
                Divider()
                
                // Security warning
                if homieState.securityCompromised {
                    securityWarning
                }
                
                // Active rules
                if !ruleEngine.activeRules.isEmpty {
                    activeRulesView
                }
                
                // Room filter
                roomFilterView
                
                // Device list
                List {
                    ForEach(filteredDevices) { device in
                        DeviceRowView(device: device, homeKitManager: homeKitManager)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Homie")
            #if targetEnvironment(macCatalyst)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { homeKitManager.loadDevices() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: 16) {
            HomieCharacter(mood: homieState.effectiveMood, size: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(statusText)
                    .font(.headline)
                
                Text("\(homeKitManager.devices.count) devices")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var statusText: String {
        let onCount = homeKitManager.devices.filter { $0.isOn }.count
        if onCount == 0 {
            return "All quiet"
        } else if onCount == 1 {
            return "1 light on"
        } else {
            return "\(onCount) lights on"
        }
    }
    
    // MARK: - Security Warning
    
    private var securityWarning: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text("Port exposed to internet!")
                .font(.caption)
                .fontWeight(.medium)
            Spacer()
        }
        .padding()
        .background(Color.red.opacity(0.1))
    }
    
    // MARK: - Active Rules
    
    private var activeRulesView: some View {
        HStack {
            Image(systemName: "bolt.fill")
                .foregroundColor(.yellow)
            
            let names = ruleEngine.rules
                .filter { ruleEngine.activeRules.contains($0.id) }
                .map { $0.name }
                .joined(separator: ", ")
            
            Text(names)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.yellow.opacity(0.1))
    }
    
    // MARK: - Room Filter
    
    private var roomFilterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                roomChip(nil, "All")
                ForEach(rooms, id: \.self) { room in
                    roomChip(room, room)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    private func roomChip(_ room: String?, _ label: String) -> some View {
        Button(action: { selectedRoom = room }) {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selectedRoom == room ? Color.accentColor : Color.secondary.opacity(0.2))
                .foregroundColor(selectedRoom == room ? .white : .primary)
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
    
    private var rooms: [String] {
        Set(homeKitManager.devices.compactMap { $0.roomName }).sorted()
    }
    
    private var filteredDevices: [HomeDevice] {
        if let room = selectedRoom {
            return homeKitManager.devices.filter { $0.roomName == room }
        }
        return homeKitManager.devices
    }
}

// MARK: - Device Row

struct DeviceRowView: View {
    let device: HomeDevice
    @ObservedObject var homeKitManager: HomeKitManager
    @State private var isToggling = false
    
    var body: some View {
        Button(action: toggleDevice) {
            HStack {
                Circle()
                    .fill(device.isOn ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 10, height: 10)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                    
                    if let room = device.roomName {
                        Text(room)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if let brightness = device.brightness, device.isOn {
                    Text("\(brightness)%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if isToggling {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: device.isOn ? "lightbulb.fill" : "lightbulb")
                        .foregroundColor(device.isOn ? .yellow : .secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isToggling)
    }
    
    private func toggleDevice() {
        isToggling = true
        homeKitManager.toggleDevice(device) { _ in
            DispatchQueue.main.async {
                isToggling = false
            }
        }
    }
}
