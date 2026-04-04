import AppKit
import SwiftUI
import VoiceSwitchKit

struct SettingsView: View {
    @Bindable var model: VoiceSwitchAppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                settingsIntroCard

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
                }
                .formStyle(.grouped)

                Text(model.settingsAutosaveText)
                    .font(.callout)
                    .foregroundStyle(model.launchAtLoginErrorMessage == nil ? Color.secondary : Color.orange)
            }
            .padding(20)
        }
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
            return "VoiceSwitch 当前已停用。启用后才会接管 Option 键并自动切换输入法。"
        }
        return model.blockingReason?.message ?? "当前配置可运行。"
    }

    private var settingsIntroCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("设置")
                .font(.title2.weight(.semibold))
            Text("在这里配置默认输入法、语音输入法，以及按住 Option 时的切换行为。")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary.opacity(0.06))
        )
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
            if let issue = model.primaryInputSourceIssue {
                Text(issue)
                    .foregroundStyle(.orange)
            }

            Picker("Voice IME", selection: voiceBinding) {
                Text("未设置").tag(String?.none)
                ForEach(model.availableInputSources) { source in
                    Text(source.displayName).tag(String?.some(source.id))
                }
            }
            if let issue = model.voiceInputSourceIssue {
                Text(issue)
                    .foregroundStyle(.orange)
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
            Stepper(value: voiceActivationDelayBinding, in: 0.0...0.3, step: 0.01) {
                Text("语音激活延迟：\(model.voiceActivationDelay, format: .number.precision(.fractionLength(2)))s")
            }

            Stepper(value: releaseReturnDelayBinding, in: 0.0...0.3, step: 0.01) {
                Text("松开返回延迟：\(model.releaseReturnDelay, format: .number.precision(.fractionLength(2)))s")
            }

            Stepper(value: cooldownDurationBinding, in: 0.5...30.0, step: 0.5) {
                Text("冷却时长：\(model.cooldownDuration, format: .number.precision(.fractionLength(1)))s")
            }

            Text("按住 Option 切到 Voice IME，松开 Option 切回 Primary IME。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var voiceActivationDelayBinding: Binding<TimeInterval> {
        Binding(
            get: { model.voiceActivationDelay },
            set: { model.updateVoiceActivationDelay($0) }
        )
    }

    private var releaseReturnDelayBinding: Binding<TimeInterval> {
        Binding(
            get: { model.releaseReturnDelay },
            set: { model.updateReleaseReturnDelay($0) }
        )
    }

    private var cooldownDurationBinding: Binding<TimeInterval> {
        Binding(
            get: { model.cooldownDuration },
            set: { model.updateCooldownDuration($0) }
        )
    }
}

private struct PermissionsSection: View {
    @Bindable var model: VoiceSwitchAppModel

    var body: some View {
        Section("权限与系统") {
            Text("辅助功能权限：\(model.accessibilityStatusLabel)")
            Text("输入监听权限：\(model.inputMonitoringStatusLabel)")
            Text("键盘监听：\(model.keyboardListenerStatusLabel)")
            Text("运行对象匹配：\(model.runtimeIdentityStatusLabel)")
            Text(model.runtimeIdentityGuidanceText)
                .foregroundStyle(.secondary)

            if let errorMessage = model.keyboardMonitoringErrorMessage {
                Text(errorMessage)
                    .foregroundStyle(.orange)
            }

            Toggle("登录时启动", isOn: launchAtLoginBinding)

            if let errorMessage = model.launchAtLoginErrorMessage {
                Text(errorMessage)
                    .foregroundStyle(.orange)
            }

            Text("遇到权限问题时，优先使用固定 `.app` 形态启动，并确认系统设置里勾选的是当前运行目标。")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                RetryMonitoringButton(model: model)

                Button("打开系统设置") {
                    openAccessibilitySettings()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { model.launchAtLoginEnabled },
            set: { model.updateLaunchAtLoginEnabled($0) }
        )
    }
}
