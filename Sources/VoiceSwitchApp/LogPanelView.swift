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

            Text("用户日志用于日常查看；诊断日志用于排障。")
                .foregroundStyle(.secondary)

            Text("当前状态：\(model.statusSummary)")
                .font(.callout)
                .foregroundStyle(.secondary)

            Picker("日志范围", selection: $selectedFilter) {
                Text("全部").tag(AppLogFilter.all)
                Text("用户日志").tag(AppLogFilter.user)
                Text("诊断日志").tag(AppLogFilter.diagnostic)
            }
            .pickerStyle(.segmented)

            HStack {
                Button("导出日志") {
                    exportLogs()
                }
                .buttonStyle(.bordered)

                if let exportStatusMessage {
                    Text(exportStatusMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            if model.filteredLogEntries(selectedFilter).isEmpty {
                ContentUnavailableView("暂无日志", systemImage: "text.append")
            } else {
                List(model.filteredLogEntries(selectedFilter)) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.level == .user ? "用户日志" : "诊断日志")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(entry.message)
                            .textSelection(.enabled)
                    }
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
}
