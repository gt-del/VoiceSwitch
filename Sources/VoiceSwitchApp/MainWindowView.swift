import SwiftUI
import VoiceSwitchKit

private enum MainWindowTab: Hashable {
    case dashboard
    case settings
    case logs
}

struct MainWindowView: View {
    @Bindable var model: VoiceSwitchAppModel
    @State private var selectedTab: MainWindowTab = .dashboard

    var body: some View {
        VStack(spacing: 0) {
            statusBanner

            TabView(selection: $selectedTab) {
                ScrollView {
                    DashboardSection(
                        model: model,
                        openSettings: { selectedTab = .settings },
                        openLogs: { selectedTab = .logs }
                    )
                    .padding(20)
                }
                .tabItem { Label("概览", systemImage: "gauge.with.dots.needle.50percent") }
                .tag(MainWindowTab.dashboard)

                SettingsView(model: model)
                    .tabItem { Label("设置", systemImage: "slider.horizontal.3") }
                    .tag(MainWindowTab.settings)

                ScrollView {
                    LogsSection(model: model)
                        .padding(20)
                }
                .tabItem { Label("日志", systemImage: "list.bullet.rectangle") }
                .tag(MainWindowTab.logs)
            }
        }
        .frame(minWidth: 860, minHeight: 620)
        .task {
            try? model.load()
        }
    }

    private var statusBanner: some View {
        HStack(spacing: 12) {
            Label(model.statusSummary, systemImage: bannerIconName)
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(bannerColor.opacity(0.18), in: Capsule())

            Text(bannerMessage)
                .foregroundStyle(bannerColor)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(bannerColor.opacity(0.12))
    }

    private var bannerMessage: String {
        if !model.isEnabled {
            return "VoiceSwitch 当前已停用，不会监听左 Control，也不会自动切换输入法。"
        }
        if model.blockingReason != nil {
            return "当前不可用，请按页面中的建议处理后再试。"
        }
        return "当前配置可运行。关闭主窗口后应用仍会常驻，你可以从 Dock 或菜单栏重新打开。"
    }

    private var bannerColor: Color {
        if !model.isEnabled {
            return .secondary
        }
        if model.blockingReason != nil {
            return .orange
        }
        return .green
    }

    private var bannerIconName: String {
        if !model.isEnabled {
            return "power"
        }
        if model.blockingReason != nil {
            return "exclamationmark.triangle.fill"
        }
        return "checkmark.circle.fill"
    }
}

private struct DashboardSection: View {
    @Bindable var model: VoiceSwitchAppModel
    let openSettings: () -> Void
    let openLogs: () -> Void
    private let summaryColumns = [
        GridItem(.flexible(minimum: 150), spacing: 16),
        GridItem(.flexible(minimum: 150), spacing: 16),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("VoiceSwitch")
                .font(.largeTitle.weight(.semibold))

            Text(dashboardSummary)
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: 720, alignment: .leading)

            LazyVGrid(columns: summaryColumns, alignment: .leading, spacing: 16) {
                summaryCard(title: "当前状态", value: model.statusSummary)
                summaryCard(title: "当前输入法组合", value: inputSourceSummary)
                summaryCard(title: "权限与监听摘要", value: permissionAndListenerSummary)
                summaryCard(title: "最近一次动作", value: lastActionSummary)
            }

            issuePanel

            if let nextStepText {
                guidancePanel(nextStepText)
            }

            actionBar

            diagnosticPanel
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var actionBar: some View {
        HStack(spacing: 12) {
            Button(model.isEnabled ? "停用" : "启用") {
                model.setEnabled(!model.isEnabled)
            }
            .buttonStyle(.borderedProminent)

            RetryMonitoringButton(model: model)
            Button("打开设置") {
                openSettings()
            }
            .buttonStyle(.bordered)
            Button("打开日志") {
                openLogs()
            }
            .buttonStyle(.bordered)
        }
    }

    private var permissionAndListenerSummary: String {
        if !model.isEnabled {
            return "已停用"
        }
        return "辅助功能 \(model.accessibilityStatusLabel) · 输入监听 \(model.inputMonitoringStatusLabel) · 监听 \(model.keyboardListenerStatusLabel)"
    }

    private var inputSourceSummary: String {
        "普通：\(model.selectedPrimaryInputSourceName)\n语音：\(model.selectedVoiceInputSourceName)"
    }

    private var lastActionSummary: String {
        guard let lastEngineAction = model.lastEngineAction else {
            return "无"
        }

        switch lastEngineAction {
        case .switchToPrimary:
            return "切回普通输入法"
        case .switchToVoice:
            return "切到语音输入法"
        case .enterCooldown:
            return "进入冷却"
        case .noOp:
            return "无动作"
        }
    }

    private var dashboardSummary: String {
        if !model.isEnabled {
            return "应用保持常驻，但自动切换暂停。重新启用后才会接管左 Control。"
        }
        if model.blockingReason != nil {
            return "当前不可用。请先处理权限、配置或监听问题，再继续使用自动切换。"
        }
        return "默认保持普通输入法，第一次按左 Control 切到语音输入法，第二次按左 Control 切回普通输入法。"
    }

    private var nextStepText: String? {
        if !model.isEnabled {
            return "启用 VoiceSwitch 后才会接管左 Control。"
        }
        return model.blockingReason?.nextStep
    }

    private func guidancePanel(_ text: String) -> some View {
        AppCard {
            Text("下一步建议")
                .font(.headline.weight(.semibold))
            Text(text)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var diagnosticPanel: some View {
        AppCard {
            DisclosureGroup("诊断信息") {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                    GridRow {
                        Text("AXIsProcessTrusted")
                            .foregroundStyle(.secondary)
                        Text(model.accessibilityTrustedValueLabel)
                    }
                    GridRow {
                        Text("CGPreflightListenEventAccess")
                            .foregroundStyle(.secondary)
                        Text(model.inputMonitoringTrustedValueLabel)
                    }
                    GridRow {
                        Text("最近原始事件")
                            .foregroundStyle(.secondary)
                        Text(model.lastRawKeyboardEventSummary ?? "无")
                    }
                    GridRow {
                        Text("当前运行路径")
                            .foregroundStyle(.secondary)
                        Text(model.maskedRuntimeExecutablePath)
                            .textSelection(.enabled)
                    }
                    GridRow {
                        Text("当前 Bundle ID")
                            .foregroundStyle(.secondary)
                        Text(model.runtimeBundleIdentifier)
                            .textSelection(.enabled)
                    }
                    GridRow {
                        Text("当前 Bundle 路径")
                            .foregroundStyle(.secondary)
                        Text(model.maskedRuntimeBundlePath)
                            .textSelection(.enabled)
                    }
                }
                .padding(.top, 10)
            }
            .font(.callout)
        }
    }

    @ViewBuilder
    private var issuePanel: some View {
        if let blockingReason = model.blockingReason {
            BlockingReasonCard(reason: blockingReason)
        }
    }

    private func summaryCard(title: String, value: String) -> some View {
        AppCard {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: 98, alignment: .topLeading)
    }
}

struct AppCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
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

struct BlockingReasonCard: View {
    let reason: AppBlockingReason

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("阻塞原因")
                .font(.headline.weight(.semibold))
            VStack(alignment: .leading, spacing: 8) {
                Label(reason.title, systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                Text(reason.message)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.orange.opacity(0.25))
        )
    }
}

private struct LogsSection: View {
    @Bindable var model: VoiceSwitchAppModel

    var body: some View {
        LogPanelView(model: model)
    }
}
