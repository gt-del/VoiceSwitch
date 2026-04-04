import AppKit
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
                Text("Event Tap: \(model.eventTapStatus.rawValue)")

                if let errorMessage = model.keyboardMonitoringErrorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.orange)
                }

                Text("If you are running from `swift run`, macOS may not register this executable like a normal app bundle. Open Accessibility settings and add the built VoiceSwitch binary manually if needed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Open Accessibility Settings") {
                    openAccessibilitySettings()
                }

                Button("Retry Keyboard Monitoring") {
                    model.retryKeyboardMonitoring()
                }
            }

            Section("Startup") {
                Toggle("Launch at Login", isOn: $model.launchAtLoginEnabled)

                if let errorMessage = model.launchAtLoginErrorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.orange)
                }
            }

            Section("Engine Parameters") {
                Stepper(value: $model.optionPendingWindow, in: 0.05...1.0, step: 0.05) {
                    Text("Option Pending Window: \(model.optionPendingWindow, format: .number.precision(.fractionLength(2)))s")
                }

                Stepper(value: $model.cooldownDuration, in: 0.5...30.0, step: 0.5) {
                    Text("Cooldown Duration: \(model.cooldownDuration, format: .number.precision(.fractionLength(1)))s")
                }

                Stepper(value: $model.voiceExitDelay, in: 0.0...30.0, step: 0.5) {
                    Text("Voice Exit Delay: \(model.voiceExitDelay, format: .number.precision(.fractionLength(1)))s")
                }

                Text("Changes affect new events immediately. Save persists them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}
