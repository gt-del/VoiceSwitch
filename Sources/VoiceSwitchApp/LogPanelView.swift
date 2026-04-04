import AppKit
import SwiftUI
import VoiceSwitchKit

struct LogPanelView: View {
    @Bindable var model: VoiceSwitchAppModel
    @State private var selectedFilter: AppLogFilter = .user
    @State private var exportStatusMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("日志")
                .font(.title2)

            Text("默认显示日常记录；需要排障时再切换诊断。")
                .foregroundStyle(.secondary)

            Picker("日志范围", selection: $selectedFilter) {
                Text("用户").tag(AppLogFilter.user)
                Text("诊断").tag(AppLogFilter.diagnostic)
                Text("全部").tag(AppLogFilter.all)
            }
            .pickerStyle(.segmented)

            HStack {
                Button("导出日志") {
                    exportLogs()
                }
                .buttonStyle(.bordered)

                if let exportStatusMessage {
                    Text(exportStatusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            if model.filteredLogEntries(selectedFilter).isEmpty {
                ContentUnavailableView("暂无日志", systemImage: "text.append")
            } else {
                List(model.filteredLogEntries(selectedFilter)) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(entry.timestamp.formatted(.dateTime.month().day().hour().minute().second()))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Text(logLevelText(entry.level))
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(levelBackgroundColor(entry.level), in: Capsule())
                        }
                        Text(entry.message)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
        .frame(minWidth: 640, minHeight: 360)
    }

    private func exportLogs() {
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = "VoiceSwitch-logs.txt"
        savePanel.allowedContentTypes = [.plainText]

        guard savePanel.runModal() == .OK, let url = savePanel.url else {
            return
        }

        do {
            try model.exportLogs(to: url)
            exportStatusMessage = "日志已导出到 \(url.lastPathComponent)。"
        } catch {
            exportStatusMessage = "日志导出失败：\(error.localizedDescription)"
        }
    }

    private func logLevelText(_ level: AppLogLevel) -> String {
        switch level {
        case .user:
            return "用户"
        case .diagnostic:
            return "诊断"
        }
    }

    private func levelBackgroundColor(_ level: AppLogLevel) -> Color {
        switch level {
        case .user:
            return Color.green.opacity(0.16)
        case .diagnostic:
            return Color.secondary.opacity(0.14)
        }
    }
}
