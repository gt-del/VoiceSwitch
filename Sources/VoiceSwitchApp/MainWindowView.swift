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
            return "VoiceSwitch 当前已禁用，不会监听 Option 键，也不会自动切换输入法。"
        }
        if let blockingIssue = model.blockingIssue {
            return blockingIssue
        }
        return "当前配置可运行。关闭主窗口后应用仍会常驻，你可以从 Dock 或菜单栏重新打开。"
    }

    private var bannerColor: Color {
        if !model.isEnabled {
            return .secondary
        }
        if model.blockingIssue != nil {
            return .orange
        }
        return .green
    }

    private var bannerIconName: String {
        if !model.isEnabled {
            return "power"
        }
        if model.blockingIssue != nil {
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
                summaryCard(title: "监听状态", value: listenerSummary)
                summaryCard(title: "默认输入法", value: model.selectedPrimaryInputSourceName)
                summaryCard(title: "语音输入法", value: model.selectedVoiceInputSourceName)
            }

            detailPanel

            actionBar

            issuePanel
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

            Button("重试监听") {
                model.retryKeyboardMonitoring()
            }
            Button("打开设置") {
                openSettings()
            }
            Button("打开日志") {
                openLogs()
            }
        }
        .buttonStyle(.bordered)
    }

    private var listenerSummary: String {
        if !model.isEnabled {
            return "已停用"
        }
        return model.eventTapStatus == .running ? "运行中" : "未运行"
    }

    private var dashboardSummary: String {
        if !model.isEnabled {
            return "应用保持常驻，但自动切换暂停。重新启用后才会接管 Option 键。"
        }
        if let blockingIssue = model.blockingIssue {
            return "当前不可用：\(blockingIssue)"
        }
        return "默认保持 Primary IME，按住 Option 切到 Voice IME，松开后恢复。"
    }

    @ViewBuilder
    private var detailPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("运行概览")
                .font(.headline.weight(.semibold))

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                GridRow {
                    Text("辅助功能权限")
                        .foregroundStyle(.secondary)
                    Text("\(model.accessibilityStatusLabel) (AXIsProcessTrusted=\(model.accessibilityTrustedValueLabel))")
                }
                GridRow {
                    Text("输入监听权限")
                        .foregroundStyle(.secondary)
                    Text("\(model.inputMonitoringStatusLabel) (CGPreflightListenEventAccess=\(model.inputMonitoringTrustedValueLabel))")
                }
                GridRow {
                    Text("键盘监听")
                        .foregroundStyle(.secondary)
                    Text(model.keyboardListenerStatusLabel)
                }
                GridRow {
                    Text("当前输入法组合")
                        .foregroundStyle(.secondary)
                    Text(model.configurationSummary)
                }
                GridRow {
                    Text("最近动作")
                        .foregroundStyle(.secondary)
                    Text(model.lastActionSummary)
                }
                GridRow {
                    Text("最近原始事件")
                        .foregroundStyle(.secondary)
                    Text(model.lastRawKeyboardEventSummary ?? "none")
                }
                GridRow {
                    Text("当前运行路径")
                        .foregroundStyle(.secondary)
                    Text(model.runtimeExecutablePath)
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
                    Text(model.runtimeBundlePath)
                        .textSelection(.enabled)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(cardFill, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }

    @ViewBuilder
    private var issuePanel: some View {
        if let issue = model.blockingIssue {
            VStack(alignment: .leading, spacing: 6) {
                Label("当前阻塞问题", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                Text(issue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.orange.opacity(0.25))
            )
        } else if !model.configurationIssues.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Label("配置问题", systemImage: "slider.horizontal.3")
                    .font(.headline)
                ForEach(model.configurationIssues, id: \.self) { issue in
                    Text(issue)
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

    private func summaryCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 98, alignment: .topLeading)
        .padding(18)
        .background(cardFill, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }

    private var cardFill: Color {
        Color(nsColor: .controlBackgroundColor)
    }
}

private struct LogsSection: View {
    @Bindable var model: VoiceSwitchAppModel

    var body: some View {
        LogPanelView(model: model)
    }
}
