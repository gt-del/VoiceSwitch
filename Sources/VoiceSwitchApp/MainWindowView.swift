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
                .tabItem { Label("Dashboard", systemImage: "gauge.with.dots.needle.50percent") }
                .tag(MainWindowTab.dashboard)

                SettingsView(model: model)
                    .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
                    .tag(MainWindowTab.settings)

                ScrollView {
                    LogsSection(model: model)
                        .padding(20)
                }
                .tabItem { Label("Logs", systemImage: "list.bullet.rectangle") }
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
            return "VoiceSwitch 已禁用，不会监听 Option 键，也不会自动切换输入法。"
        }
        if let blockingIssue = model.blockingIssue {
            return blockingIssue
        }
        return "当前配置可运行。最小化窗口后仍可通过菜单栏快速查看状态和重新打开。"
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

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("VoiceSwitch")
                .font(.largeTitle.weight(.semibold))

            HStack(spacing: 16) {
                summaryCard(title: "Status", value: model.statusSummary)
                summaryCard(title: "Listener", value: listenerSummary)
                summaryCard(title: "Primary IME", value: model.selectedPrimaryInputSourceName)
                summaryCard(title: "Voice IME", value: model.selectedVoiceInputSourceName)
            }

            detailPanel

            HStack(spacing: 12) {
                Button(model.isEnabled ? "Disable" : "Enable") {
                    model.setEnabled(!model.isEnabled)
                }
                Button("Retry Monitoring") {
                    model.retryKeyboardMonitoring()
                }
                Button("Open Settings") {
                    openSettings()
                }
                Button("Open Logs") {
                    openLogs()
                }
            }

            issuePanel
        }
    }

    private var listenerSummary: String {
        if !model.isEnabled {
            return "Disabled"
        }
        return model.eventTapStatus == .running ? "Running" : "Stopped"
    }

    @ViewBuilder
    private var detailPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Overview")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                GridRow {
                    Text("Accessibility")
                        .foregroundStyle(.secondary)
                    Text(model.permissionSnapshot.accessibility.rawValue)
                }
                GridRow {
                    Text("Input Monitoring")
                        .foregroundStyle(.secondary)
                    Text(model.permissionSnapshot.inputMonitoring.rawValue)
                }
                GridRow {
                    Text("Event Tap")
                        .foregroundStyle(.secondary)
                    Text(model.eventTapStatus.rawValue)
                }
                GridRow {
                    Text("Current Pair")
                        .foregroundStyle(.secondary)
                    Text(model.configurationSummary)
                }
                GridRow {
                    Text("Last Action")
                        .foregroundStyle(.secondary)
                    Text(model.lastEngineAction?.rawValue ?? "none")
                }
                GridRow {
                    Text("Last Raw Event")
                        .foregroundStyle(.secondary)
                    Text(model.lastRawKeyboardEventSummary ?? "none")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var issuePanel: some View {
        if let issue = model.blockingIssue {
            VStack(alignment: .leading, spacing: 6) {
                Text("Blocking Issue")
                    .font(.headline)
                Text(issue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        } else if !model.configurationIssues.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Configuration Issues")
                    .font(.headline)
                ForEach(model.configurationIssues, id: \.self) { issue in
                    Text(issue)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func summaryCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct LogsSection: View {
    @Bindable var model: VoiceSwitchAppModel

    var body: some View {
        LogPanelView(model: model)
    }
}
