import SwiftUI
import HomeKit
import ServiceManagement

@main
struct HomieApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate.homieState)
                .frame(width: 380, height: 600)
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
    @EnvironmentObject var homieState: HomieState
    
    // Olive/khaki background from the mockup
    private let backgroundColor = Color(red: 0.65, green: 0.6, blue: 0.45)
    private let cardColor = Color(red: 0.35, green: 0.33, blue: 0.3)
    
    private var baseURL: String {
        "http://127.0.0.1:\(homieState.port)"
    }
    
    @State private var showingSettings = false
    @State private var copiedURL = false
    
    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            
            if showingSettings {
                settingsFullView
            } else {
                mainView
            }
        }
    }
    
    // MARK: - Main View
    
    private var mainView: some View {
        VStack(spacing: 16) {
            // Settings gear
            HStack {
                Spacer()
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.black.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            // Mascot - full width
            HomieCharacter(size: 180)
                .frame(maxWidth: .infinity)
            
            // Wordmark - full width
            Image("Wordmark")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 32)
            
            // Tagline
            Text("runs so you don't have to")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.black.opacity(0.7))
            
            Spacer()
            
            // Status panel
            statusPanel
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 32)
    }
    
    // MARK: - Status Panel
    
    private var statusPanel: some View {
        VStack(spacing: 12) {
            // Status + toggle
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(homieState.serverRunning ? "\(homieState.requestCount) RUNS" : "STOPPED")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    // Tap to copy URL
                    Button(action: copyURL) {
                        HStack(spacing: 4) {
                            Text(baseURL)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                            
                            Image(systemName: copiedURL ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 9))
                        }
                        .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                // Power toggle button
                Button(action: { homieState.toggleServer() }) {
                    Image(systemName: homieState.serverRunning ? "power.circle.fill" : "power.circle")
                        .font(.system(size: 36))
                        .foregroundColor(homieState.serverRunning ? .green : .white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(cardColor)
        .cornerRadius(12)
    }
    
    private func copyURL() {
        #if targetEnvironment(macCatalyst)
        UIPasteboard.general.string = baseURL
        #endif
        copiedURL = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copiedURL = false
        }
    }
    
    // MARK: - Settings Full View
    
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @State private var selectedTab = 0
    
    private var settingsFullView: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Button(action: { showingSettings = false }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(selectedTab == 0 ? "Endpoints" : (selectedTab == 1 ? "CLI" : "Settings"))
                    .font(.headline)
                
                Spacer()
                
                // Invisible spacer for centering
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 14))
                }
                .opacity(0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // Tab picker
            Picker("", selection: $selectedTab) {
                Text("Endpoints").tag(0)
                Text("CLI").tag(1)
                Text("Settings").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            
            // Content
            if selectedTab == 0 {
                apiContent
            } else if selectedTab == 1 {
                cliContent
            } else {
                settingsContent
            }
            
            Spacer()
            
            // Version footer with ghost link
            HStack(spacing: 6) {
                Text("v1.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.5))
                
                Button(action: {
                    if let url = URL(string: "https://github.com/ghostmfr") {
                        #if targetEnvironment(macCatalyst)
                        UIApplication.shared.open(url)
                        #endif
                    }
                }) {
                    HStack(spacing: 4) {
                        Image("GhostIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                        Text("ghostmfr")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 24)
        }
        .background(Color(UIColor.systemBackground))
    }
    
    private var settingsContent: some View {
        VStack(spacing: 20) {
            // Launch at login
            Toggle("Start with computer", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .onChange(of: launchAtLogin) { newValue in
                    setLaunchAtLogin(newValue)
                }
            
            // Auto-start server
            Toggle("Start server automatically", isOn: $homieState.autoLaunchServer)
                .toggleStyle(.switch)
            
            // Hide from dock
            Toggle("Hide from Dock", isOn: $homieState.hideFromDock)
                .toggleStyle(.switch)
            
            Spacer()
            
            // Reset HomeKit Access button
            Button(action: openHomeKitSettings) {
                HStack {
                    Image(systemName: "house.circle")
                    Text("Reset HomeKit Access")
                }
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 8)
            
            // Quit button
            Button(action: quitApp) {
                HStack {
                    Image(systemName: "power")
                    Text("Quit lil homie")
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
    
    private var apiContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                // Base URL at top
                HStack {
                    Text("Base URL:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(baseURL)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                }
                .padding(.bottom, 8)
                
                endpointRow("GET", "/health", "Status check", nil)
                endpointRow("GET", "/devices", "List all devices", nil)
                endpointRow("GET", "/device/{name}", "Get device state", nil)
                endpointRow("GET", "/device/{name}/schema", "JSON schema", nil)
                endpointRow("POST", "/device/{name}/toggle", "Toggle on/off", nil)
                endpointRow("POST", "/device/{name}/on", "Turn on", nil)
                endpointRow("POST", "/device/{name}/off", "Turn off", nil)
                endpointRow("POST", "/device/{name}/set", "Set state", #"{"on": bool, "brightness": 0-100}"#)
                endpointRow("GET", "/rooms", "List all rooms", nil)
                endpointRow("GET", "/room/{name}", "Devices in room", nil)
                endpointRow("POST", "/room/{name}/on", "Turn room on", nil)
                endpointRow("POST", "/room/{name}/off", "Turn room off", nil)
                endpointRow("GET", "/room/{r}/device/{d}", "Device in room", nil)
                endpointRow("POST", "/room/{r}/device/{d}/on", "Device on", nil)
                endpointRow("POST", "/room/{r}/device/{d}/off", "Device off", nil)
                endpointRow("POST", "/room/{r}/device/{d}/toggle", "Toggle", nil)
                endpointRow("GET", "/scenes", "List scenes", nil)
                endpointRow("POST", "/scene/{name}/trigger", "Trigger scene", nil)
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var cliContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Control HomeKit from your terminal")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 12) {
                    cliExample("lilhomie list", "List all devices")
                    cliExample("lilhomie scenes", "List all scenes")
                    cliExample("lilhomie on \"Office Light\"", "Turn on a device")
                    cliExample("lilhomie off \"Office Light\"", "Turn off a device")
                    cliExample("lilhomie toggle \"Office Light\"", "Toggle a device")
                    cliExample("lilhomie set \"Office Light\" 50", "Set brightness")
                    cliExample("lilhomie scene \"Good Night\"", "Trigger a scene")
                }
                
                Divider().padding(.vertical, 8)
                
                Text("Install from GitHub")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                copyableCode("curl -sL https://github.com/ghostmfr/lil-homie/releases/latest/download/lilhomie -o /usr/local/bin/lilhomie && chmod +x /usr/local/bin/lilhomie")
            }
            .padding(.horizontal, 20)
        }
    }
    
    @State private var copiedText: String? = nil
    
    private func cliExample(_ cmd: String, _ desc: String) -> some View {
        Button(action: { copyText(cmd) }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(cmd)
                        .font(.system(size: 12, design: .monospaced))
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: copiedText == cmd ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
    
    private func copyableCode(_ code: String) -> some View {
        Button(action: { copyText(code) }) {
            HStack {
                Text(code)
                    .font(.system(size: 10, design: .monospaced))
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: copiedText == code ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
    
    private func copyText(_ text: String) {
        #if targetEnvironment(macCatalyst)
        UIPasteboard.general.string = text
        #endif
        copiedText = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if copiedText == text {
                copiedText = nil
            }
        }
    }
    
    private func endpointRow(_ method: String, _ path: String, _ desc: String, _ body: String?) -> some View {
        let curlCmd = method == "GET" 
            ? "curl \(baseURL)\(path)"
            : "curl -X POST \(baseURL)\(path)\(body != nil ? " -H 'Content-Type: application/json' -d '\(body!)'" : "")"
        
        return Button(action: { copyText(curlCmd) }) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(method)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(method == "GET" ? .blue : .orange)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(method == "GET" ? Color.blue.opacity(0.15) : Color.orange.opacity(0.15))
                        .cornerRadius(4)
                    
                    Text(path)
                        .font(.system(size: 11, design: .monospaced))
                    
                    Spacer()
                    
                    Image(systemName: copiedText == curlCmd ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                
                Text(desc)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                if let body = body {
                    Text(body)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
    
    private func quitApp() {
        // For Mac Catalyst, we need to use exit since NSApplication isn't directly available
        exit(0)
    }
    
    private func openHomeKitSettings() {
        #if targetEnvironment(macCatalyst)
        // Open Privacy & Security > HomeKit
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_HomeKit") {
            UIApplication.shared.open(url)
        }
        #endif
    }
    
    private func setLaunchAtLogin(_ enabled: Bool) {
        #if targetEnvironment(macCatalyst)
        if #available(macCatalyst 16.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
            }
        }
        #endif
    }
}
