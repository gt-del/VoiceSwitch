import AppKit
import SwiftUI
import VoiceSwitchKit

struct SettingsView: View {
    @Bindable var model: VoiceSwitchAppModel

    var body: some View {
        Form {
            Section("状态") {
                Toggle("启用 VoiceSwitch", isOn: enabledBinding)
                Text("当前状态：\(model.statusSummary)")
                Text(statusMessage)
                    .foregroundStyle(model.canRun && model.isEnabled ? Color.secondary : Color.orange)
            }

            InputSourcesSection(model: model)

            BehaviorSection(model: model)

            PermissionsSection(model: model)

            Button("保存配置") {
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
        Section("输入法") {
            Picker("Primary IME", selection: primaryBinding) {
                Text("未设置").tag(String?.none)
                ForEach(model.availableInputSources) { source in
                    Text(source.displayName).tag(String?.some(source.id))
                }
            }

            Picker("Voice IME", selection: voiceBinding) {
                Text("未设置").tag(String?.none)
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
        Section("行为") {
            Stepper(value: $model.voiceActivationDelay, in: 0.0...0.3, step: 0.01) {
                Text("语音激活延迟：\(model.voiceActivationDelay, format: .number.precision(.fractionLength(2)))s")
            }

            Stepper(value: $model.releaseReturnDelay, in: 0.0...0.3, step: 0.01) {
                Text("松开返回延迟：\(model.releaseReturnDelay, format: .number.precision(.fractionLength(2)))s")
            }

            Stepper(value: $model.cooldownDuration, in: 0.5...30.0, step: 0.5) {
                Text("冷却时长：\(model.cooldownDuration, format: .number.precision(.fractionLength(1)))s")
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
        Section("权限与系统") {
            Text("辅助功能权限：\(model.permissionSnapshot.accessibility.rawValue)")
            Text("输入监听权限：\(model.permissionSnapshot.inputMonitoring.rawValue)")
            Text("键盘监听：\(model.eventTapStatus.rawValue)")

            if let errorMessage = model.keyboardMonitoringErrorMessage {
                Text(errorMessage)
                    .foregroundStyle(.orange)
            }

            Toggle("登录时启动", isOn: $model.launchAtLoginEnabled)

            if let errorMessage = model.launchAtLoginErrorMessage {
                Text(errorMessage)
                    .foregroundStyle(.orange)
            }

            Text("如果你是通过 `swift run` 启动，macOS 可能不会把它识别成标准 App Bundle。遇到权限问题时，优先使用 `.app` 形态启动。")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("重试监听") {
                    model.retryKeyboardMonitoring()
                }

                Button("打开系统设置") {
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
