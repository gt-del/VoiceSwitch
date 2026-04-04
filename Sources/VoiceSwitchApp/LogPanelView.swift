import SwiftUI
import VoiceSwitchKit

struct LogPanelView: View {
    @Bindable var model: VoiceSwitchAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("日志与诊断")
                .font(.title2)

            Text("当前状态：\(model.currentEngineState.rawValue)")
            Text("最近事件：\(model.lastInputBehavior?.rawValue ?? "none")")
            Text("最近动作：\(model.lastEngineAction?.rawValue ?? "none")")
            Text("键盘监听：\(model.eventTapStatus.rawValue)")
            Text("辅助功能权限：\(model.permissionSnapshot.accessibility.rawValue)")
            Text("最近原始键盘事件：\(model.lastRawKeyboardEventSummary ?? "none")")

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

            if model.logEntries.isEmpty {
                ContentUnavailableView("暂无日志", systemImage: "text.append")
            } else {
                List(model.logEntries, id: \.self) { entry in
                    Text(entry)
                }
            }
        }
        .padding()
        .frame(minWidth: 640, minHeight: 360)
    }
}
