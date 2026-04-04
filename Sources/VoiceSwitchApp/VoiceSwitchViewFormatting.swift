import VoiceSwitchKit

extension VoiceSwitchAppModel {
    var inputSourceSummaryText: String {
        "默认：\(selectedPrimaryInputSourceName) | 语音：\(selectedVoiceInputSourceName)"
    }

    var permissionSummaryText: String {
        "辅助功能：\(accessibilityStatusLabel) | 输入监听：\(inputMonitoringStatusLabel) | 监听：\(keyboardListenerStatusLabel)"
    }

    var nextStepDisplayText: String {
        if !isEnabled {
            return "启用 VoiceSwitch 后才会接管 Option 键。"
        }
        return blockingReason?.nextStep ?? "当前配置可运行，可以直接按住 Option 切换语音输入法。"
    }

    var runtimeIdentityGuidanceText: String {
        switch runtimeIdentityStatus {
        case .matched:
            return "当前运行目标与已授权对象一致。"
        case .mismatched:
            return "系统里已勾选的对象可能不是当前这个进程，请改用固定 .app 产物并重新授权当前运行路径。"
        case .unknown:
            return "当前无法确认授权对象是否命中了这个运行目标。"
        }
    }

    var lastActionDisplayText: String {
        guard let lastEngineAction else {
            return "无"
        }

        switch lastEngineAction {
        case .switchToPrimary:
            return "切回默认输入法"
        case .switchToVoice:
            return "切到语音输入法"
        case .enterCooldown:
            return "进入冷却"
        case .noOp:
            return "无动作"
        }
    }

    var settingsAutosaveText: String {
        settingsSaveStatusMessage ?? "设置会自动保存并自动应用。"
    }
}
