import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var homeKitManager: HomeKitManager
    @EnvironmentObject var ruleEngine: RuleEngine
    
    var body: some View {
        NavigationStack {
            List {
                Section("Rules") {
                    ForEach(ruleEngine.rules) { rule in
                        RuleRowView(rule: rule, ruleEngine: ruleEngine)
                    }
                    
                    NavigationLink("Add Rule...") {
                        AddRuleView(ruleEngine: ruleEngine)
                    }
                }
                
                Section("Scenes") {
                    ForEach(homeKitManager.scenes) { scene in
                        HStack {
                            Text(scene.name)
                            Spacer()
                            Text("\(scene.actionCount) actions")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
                
                Section("API") {
                    HStack {
                        Text("Endpoint")
                        Spacer()
                        Text("http://localhost:8420")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Status")
                        Spacer()
                        Text("Running")
                            .foregroundColor(.green)
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Devices")
                        Spacer()
                        Text("\(homeKitManager.devices.count)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Rule Row

struct RuleRowView: View {
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
            .labelsHidden()
        }
    }
}

// MARK: - Add Rule

struct AddRuleView: View {
    @ObservedObject var ruleEngine: RuleEngine
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var appPattern = ""
    @State private var revert = true
    
    var body: some View {
        Form {
            Section("Rule") {
                TextField("Name", text: $name)
                TextField("App Bundle ID", text: $appPattern)
                    .autocapitalization(.none)
                Toggle("Revert on close", isOn: $revert)
            }
            
            Section {
                Text("Use wildcards like com.adobe.* to match multiple apps")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("New Rule")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveRule()
                    dismiss()
                }
                .disabled(name.isEmpty || appPattern.isEmpty)
            }
        }
    }
    
    private func saveRule() {
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
