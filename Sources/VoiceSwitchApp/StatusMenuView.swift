import SwiftUI
import VoiceSwitchKit

struct StatusMenuView: View {
    @Bindable var model: VoiceSwitchAppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("VoiceSwitch")
                .font(.headline)

            Text("当前状态：\(model.statusSummary)")

            if let menuBlockingLabel = model.menuBlockingLabel {
                Text("问题：\(menuBlockingLabel)")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Divider()

            Button("打开 VoiceSwitch") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }

            Button(model.isEnabled ? "停用" : "启用") {
                model.setEnabled(!model.isEnabled)
            }

            Button("重试监听") {
                model.retryKeyboardMonitoring()
            }

            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 220)
    }
}
