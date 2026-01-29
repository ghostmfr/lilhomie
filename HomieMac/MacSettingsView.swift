import SwiftUI
import ServiceManagement

struct MacSettingsView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gear") }
            
            RulesTab()
                .tabItem { Label("Rules", systemImage: "bolt") }
            
            APITab()
                .tabItem { Label("API", systemImage: "terminal") }
            
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - General Tab

struct GeneralTab: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    
    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch Homie at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        setLaunchAtLogin(newValue)
                    }
            }
            
            Section("Menu Bar") {
                Text("Homie lives in your menu bar. Click the house icon to access controls.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("[Settings] Launch at login error: \(error)")
        }
    }
}

// MARK: - Rules Tab

struct RulesTab: View {
    @EnvironmentObject var ruleEngine: RuleEngine
    @EnvironmentObject var appMonitor: MacAppMonitor
    @State private var showAddRule = false
    
    var body: some View {
        VStack {
            // Current app context
            if let app = appMonitor.currentApp {
                HStack {
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 20, height: 20)
                    }
                    VStack(alignment: .leading) {
                        Text("Current: \(app.name)")
                            .font(.caption)
                        Text(app.bundleIdentifier)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Add Rule for This App") {
                        // Pre-fill with current app
                        showAddRule = true
                    }
                    .font(.caption)
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                .padding()
            }
            
            // Rules list
            List {
                ForEach(ruleEngine.rules) { rule in
                    MacRuleRow(rule: rule, ruleEngine: ruleEngine)
                }
                .onDelete { indexSet in
                    indexSet.forEach { index in
                        ruleEngine.deleteRule(id: ruleEngine.rules[index].id)
                    }
                }
            }
            
            HStack {
                Button(action: { showAddRule = true }) {
                    Label("Add Rule", systemImage: "plus")
                }
                Spacer()
                Text("\(ruleEngine.rules.count) rules")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding()
        }
        .sheet(isPresented: $showAddRule) {
            MacAddRuleView(ruleEngine: ruleEngine, appMonitor: appMonitor, isPresented: $showAddRule)
        }
    }
}

struct MacRuleRow: View {
    let rule: HomieRule
    @ObservedObject var ruleEngine: RuleEngine
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    Text(rule.name)
                        .fontWeight(.medium)
                    if ruleEngine.activeRules.contains(rule.id) {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                }
                if let app = rule.conditions.app {
                    Text(app)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { rule.enabled },
                set: { newValue in
                    var updated = rule
                    updated.enabled = newValue
                    ruleEngine.updateRule(updated)
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
    }
}

struct MacAddRuleView: View {
    @ObservedObject var ruleEngine: RuleEngine
    @ObservedObject var appMonitor: MacAppMonitor
    @Binding var isPresented: Bool
    
    @State private var name = ""
    @State private var appPattern = ""
    @State private var selectedSceneId: String?
    @State private var revert = true
    
    var body: some View {
        VStack(spacing: 20) {
            Text("New App-Aware Rule")
                .font(.headline)
            
            Form {
                TextField("Rule Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                
                HStack {
                    TextField("App Bundle ID (e.g. com.adobe.*)", text: $appPattern)
                        .textFieldStyle(.roundedBorder)
                    
                    if let app = appMonitor.currentApp {
                        Button("Use Current") {
                            appPattern = app.bundleIdentifier
                            if name.isEmpty {
                                name = "\(app.name) Mode"
                            }
                        }
                        .font(.caption)
                    }
                }
                
                // TODO: Scene picker when we have scenes loaded
                
                Toggle("Revert when app closes", isOn: $revert)
            }
            
            Text("When the app matching this pattern becomes frontmost, the rule activates.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.escape)
                Spacer()
                Button("Create") {
                    createRule()
                    isPresented = false
                }
                .keyboardShortcut(.return)
                .disabled(name.isEmpty || appPattern.isEmpty)
            }
        }
        .padding()
        .frame(width: 450)
    }
    
    private func createRule() {
        let rule = HomieRule(
            name: name,
            conditions: HomieRule.Conditions(app: appPattern),
            actions: [],
            revert: revert,
            enabled: true
        )
        ruleEngine.addRule(rule)
    }
}

// MARK: - API Tab

struct APITab: View {
    @State private var cliInstalled = false
    
    var body: some View {
        Form {
            Section("HTTP API") {
                HStack {
                    Text("Endpoint")
                    Spacer()
                    Text("http://127.0.0.1:8420")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Status")
                    Spacer()
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Running")
                        .foregroundColor(.green)
                }
            }
            
            Section("CLI Tool") {
                HStack {
                    Text("hkctl")
                    Spacer()
                    Text(cliInstalled ? "Installed" : "Not installed")
                        .foregroundColor(cliInstalled ? .green : .secondary)
                }
                
                Button("Install CLI to /usr/local/bin") {
                    installCLI()
                }
            }
            
            Section("Examples") {
                VStack(alignment: .leading, spacing: 8) {
                    CodeLine("curl http://localhost:8420/devices")
                    CodeLine("curl -X POST http://localhost:8420/device/ID/toggle")
                    CodeLine("hkctl toggle \"Office Lamp\"")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { checkCLI() }
    }
    
    private func checkCLI() {
        cliInstalled = FileManager.default.fileExists(atPath: "/usr/local/bin/hkctl")
    }
    
    private func installCLI() {
        // Would need admin privileges - show instructions instead
        let alert = NSAlert()
        alert.messageText = "Install CLI"
        alert.informativeText = "Run this command in Terminal:\n\nsudo cp ~/.../hkctl /usr/local/bin/"
        alert.runModal()
    }
}

struct CodeLine: View {
    let text: String
    init(_ text: String) { self.text = text }
    
    var body: some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .padding(6)
            .background(Color.black.opacity(0.05))
            .cornerRadius(4)
    }
}

// MARK: - About Tab

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 20) {
            HomieCharacter(mood: .happy, size: 80)
            
            Text("Homie")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("The missing bridge between macOS and your home")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Version 1.0.0")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Link("GitHub", destination: URL(string: "https://github.com/ghostmfr/Homie")!)
                .font(.caption)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
