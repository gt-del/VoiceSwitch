import SwiftUI
import VoiceSwitchKit

struct LogPanelView: View {
    @Bindable var model: VoiceSwitchAppModel
    @State private var selectedFilter: AppLogFilter = .user

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("日志与诊断")
                .font(.title2)

            Text("当前状态：\(model.statusSummary)")
            Text("最近事件：\(model.lastInputBehaviorSummary)")
            Text("最近动作：\(model.lastActionSummary)")
            Text("键盘监听：\(model.keyboardListenerStatusLabel)")
            Text("辅助功能权限：\(model.accessibilityStatusLabel)")
            Text("最近原始键盘事件：\(model.lastRawKeyboardEventSummary ?? "无")")

            Picker("日志范围", selection: $selectedFilter) {
                Text("全部").tag(AppLogFilter.all)
                Text("用户日志").tag(AppLogFilter.user)
                Text("诊断日志").tag(AppLogFilter.diagnostic)
            }
            .pickerStyle(.segmented)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 8) {
                Button("发送 Option 按下") {
                    model.dispatchTestEvent(.optionPressed)
                }
                Button("发送 Option 松开") {
                    model.dispatchTestEvent(.optionReleased)
                }
                Button("发送手动切换") {
                    model.dispatchTestEvent(.manualSwitchDetected)
                }
                Button("发送冷却到期") {
                    model.dispatchTestEvent(.cooldownExpired)
                }
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
}
