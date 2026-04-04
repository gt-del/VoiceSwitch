import AppKit
import SwiftUI
import VoiceSwitchKit

struct SettingsView: View {
    @Bindable var model: VoiceSwitchAppModel

    var body: some View {
        Form {
            Section("Status") {
                Toggle("Enable VoiceSwitch", isOn: enabledBinding)
                Text("Runtime Status: \(model.statusSummary)")
                Text(statusMessage)
                    .foregroundStyle(model.canRun && model.isEnabled ? Color.secondary : Color.orange)
            }

            InputSourcesSection(model: model)

            BehaviorSection(model: model)

            PermissionsSection(model: model)

            Button("Save") {
                model.saveSelections()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { model.isEnabled },
            set: { model.setEnabled($0) }
        )
    }

    private var statusMessage: String {
        if !model.isEnabled {
            return "VoiceSwitch 当前已禁用。启用后才会接管 Option 键并自动切换输入法。"
        }
        return model.blockingIssue ?? "当前配置可运行。"
    }
}

private struct InputSourcesSection: View {
    @Bindable var model: VoiceSwitchAppModel

    var body: some View {
        Section("Input Sources") {
            Picker("Primary IME", selection: primaryBinding) {
                Text("Not Set").tag(String?.none)
                ForEach(model.availableInputSources) { source in
                    Text(source.displayName).tag(String?.some(source.id))
                }
            }

            Picker("Voice IME", selection: voiceBinding) {
                Text("Not Set").tag(String?.none)
                ForEach(model.availableInputSources) { source in
                    Text(source.displayName).tag(String?.some(source.id))
                }
            }

            if !model.configurationIssues.isEmpty {
                ForEach(model.configurationIssues, id: \.self) { issue in
                    Text(issue)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var primaryBinding: Binding<String?> {
        Binding(
            get: { model.selectedPrimaryInputSourceID },
            set: { model.updatePrimaryInputSourceID($0) }
        )
    }

    private var voiceBinding: Binding<String?> {
        Binding(
            get: { model.selectedVoiceInputSourceID },
            set: { model.updateVoiceInputSourceID($0) }
        )
    }
}

private struct BehaviorSection: View {
    @Bindable var model: VoiceSwitchAppModel

    var body: some View {
        Section("Behavior") {
            Stepper(value: $model.voiceActivationDelay, in: 0.0...0.3, step: 0.01) {
                Text("Voice Activation Delay: \(model.voiceActivationDelay, format: .number.precision(.fractionLength(2)))s")
            }

            Stepper(value: $model.releaseReturnDelay, in: 0.0...0.3, step: 0.01) {
                Text("Release Return Delay: \(model.releaseReturnDelay, format: .number.precision(.fractionLength(2)))s")
            }

            Stepper(value: $model.cooldownDuration, in: 0.5...30.0, step: 0.5) {
                Text("Cooldown Duration: \(model.cooldownDuration, format: .number.precision(.fractionLength(1)))s")
            }

            Text("按住 Option 切到 Voice IME，松开 Option 切回 Primary IME。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct PermissionsSection: View {
    @Bindable var model: VoiceSwitchAppModel

    var body: some View {
        Section("Permissions & System") {
            Text("Accessibility: \(model.permissionSnapshot.accessibility.rawValue)")
            Text("Input Monitoring: \(model.permissionSnapshot.inputMonitoring.rawValue)")
            Text("Event Tap: \(model.eventTapStatus.rawValue)")

            if let errorMessage = model.keyboardMonitoringErrorMessage {
                Text(errorMessage)
                    .foregroundStyle(.orange)
            }

            Toggle("Launch at Login", isOn: $model.launchAtLoginEnabled)

            if let errorMessage = model.launchAtLoginErrorMessage {
                Text(errorMessage)
                    .foregroundStyle(.orange)
            }

            Text("If you are running from `swift run`, macOS may not register this executable like a normal app bundle. Open Accessibility settings and add the built VoiceSwitch binary manually if needed.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Retry Monitoring") {
                    model.retryKeyboardMonitoring()
                }

                Button("Open System Settings") {
                    openAccessibilitySettings()
                }
            }
        }
    }

    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}
