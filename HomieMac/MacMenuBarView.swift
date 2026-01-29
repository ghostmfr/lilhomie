import SwiftUI

struct MacMenuBarView: View {
    @EnvironmentObject var homeKitManager: HomeKitManager
    @EnvironmentObject var ruleEngine: RuleEngine
    @EnvironmentObject var homieState: HomieState
    @EnvironmentObject var appMonitor: MacAppMonitor
    
    @State private var selectedRoom: String? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Context info
            if let app = appMonitor.currentApp {
                contextView(app: app)
                Divider()
            }
            
            // Security warning
            if homieState.securityCompromised {
                securityWarning
                Divider()
            }
            
            // Active rules
            if !ruleEngine.activeRules.isEmpty {
                activeRulesView
                Divider()
            }
            
            // Room filter
            roomFilterView
            
            Divider()
            
            // Devices
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filteredDevices) { device in
                        MacDeviceRow(device: device, homeKitManager: homeKitManager)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 300)
            
            Divider()
            
            // Scenes
            if !homeKitManager.scenes.isEmpty {
                scenesView
                Divider()
            }
            
            // Footer
            footerView
        }
        .frame(width: 300)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: 12) {
            HomieCharacter(mood: homieState.effectiveMood, size: 36)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Homie")
                    .font(.headline)
                
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Presence indicator
            Circle()
                .fill(appMonitor.isUserActive ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
                .help(appMonitor.isUserActive ? "User active" : "User away")
            
            Button(action: { homeKitManager.loadDevices() }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
        }
        .padding(12)
    }
    
    private var statusText: String {
        let onCount = homeKitManager.devices.filter { $0.isOn }.count
        if onCount == 0 { return "All quiet" }
        return "\(onCount) light\(onCount == 1 ? "" : "s") on"
    }
    
    // MARK: - Context
    
    private func contextView(app: MacAppMonitor.RunningApp) -> some View {
        HStack(spacing: 8) {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 16, height: 16)
            }
            
            Text(app.name)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if ruleEngine.rules.contains(where: { 
                $0.enabled && MacAppMonitor.matches(bundleId: app.bundleIdentifier, pattern: $0.conditions.app ?? "")
            }) {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.yellow)
                    .font(.caption)
                    .help("Rule active for this app")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.1))
    }
    
    // MARK: - Security
    
    private var securityWarning: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text("Port exposed!")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.red)
            Spacer()
        }
        .padding(8)
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
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
    
    // MARK: - Room Filter
    
    private var roomFilterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                roomChip(nil, "All")
                ForEach(rooms, id: \.self) { room in
                    roomChip(room, room)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }
    
    private func roomChip(_ room: String?, _ label: String) -> some View {
        Button(action: { selectedRoom = room }) {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(selectedRoom == room ? Color.accentColor : Color.secondary.opacity(0.2))
                .foregroundColor(selectedRoom == room ? .white : .primary)
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
    
    private var rooms: [String] {
        Set(homeKitManager.devices.compactMap { $0.roomName }).sorted()
    }
    
    private var filteredDevices: [HomeDevice] {
        let devices = selectedRoom != nil 
            ? homeKitManager.devices.filter { $0.roomName == selectedRoom }
            : homeKitManager.devices
        return devices.sorted { $0.name < $1.name }
    }
    
    // MARK: - Scenes
    
    private var scenesView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Scenes")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
            
            ForEach(homeKitManager.scenes.prefix(5)) { scene in
                Button(action: { triggerScene(scene) }) {
                    HStack {
                        Text(scene.name)
                            .font(.system(size: 12))
                        Spacer()
                        Text("\(scene.actionCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
    }
    
    private func triggerScene(_ scene: HomeScene) {
        homeKitManager.triggerScene(id: scene.id) { _ in }
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
        HStack {
            Button("Settings...") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
            
            Spacer()
            
            Button("Quit") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
        }
        .padding(12)
    }
}

// MARK: - Device Row

struct MacDeviceRow: View {
    let device: HomeDevice
    @ObservedObject var homeKitManager: HomeKitManager
    @State private var isToggling = false
    @State private var isHovering = false
    
    var body: some View {
        Button(action: toggleDevice) {
            HStack(spacing: 8) {
                Circle()
                    .fill(device.isOn ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(device.name)
                        .font(.system(size: 12))
                    
                    if let room = device.roomName {
                        Text(room)
                            .font(.caption2)
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
                        .scaleEffect(0.5)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: device.isOn ? "lightbulb.fill" : "lightbulb")
                        .font(.caption)
                        .foregroundColor(device.isOn ? .yellow : .secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(isHovering ? Color.secondary.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
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
