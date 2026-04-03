import SwiftUI
import VoiceSwitchKit

struct SettingsView: View {
    @Bindable var model: VoiceSwitchAppModel

    var body: some View {
        Form {
            if !model.configurationIssues.isEmpty {
                Section("Configuration Issues") {
                    ForEach(model.configurationIssues, id: \.self) { issue in
                        Text(issue)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Picker("Primary IME", selection: $model.selectedPrimaryInputSourceID) {
                Text("Not Set").tag(String?.none)
                ForEach(model.availableInputSources) { source in
                    Text(source.displayName).tag(String?.some(source.id))
                }
            }

            Picker("Voice IME", selection: $model.selectedVoiceInputSourceID) {
                Text("Not Set").tag(String?.none)
                ForEach(model.availableInputSources) { source in
                    Text(source.displayName).tag(String?.some(source.id))
                }
            }

            Section("Permissions") {
                Text("Accessibility: \(model.permissionSnapshot.accessibility.rawValue)")
                Text("Input Monitoring: \(model.permissionSnapshot.inputMonitoring.rawValue)")
            }

            Section("Startup") {
                Toggle("Launch at Login", isOn: $model.launchAtLoginEnabled)
            }

            Button("Save") {
                model.saveSelections()
            }
        }
        .padding()
        .frame(minWidth: 520, minHeight: 320)
        .task {
            try? model.load()
        }
    }
}
