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
            Text("第一次按左 Control 切到语音输入法，第二次按左 Control 切回普通输入法。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let menuBlockingLabel = model.menuBlockingLabel {
                Text("问题：\(menuBlockingLabel)")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Divider()

            Button("Open VoiceSwitch") {
                openMainWindow()
            }

            Button(model.isEnabled ? "停用" : "启用") {
                model.setEnabled(!model.isEnabled)
            }

            Button("重试监听") {
                model.retryKeyboardMonitoring()
            }

            Button("Quit VoiceSwitch") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 260)
    }

    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: VoiceSwitchWindowID.main)

        DispatchQueue.main.async {
            if let mainWindow = NSApp.windows.first(where: { $0.title == "VoiceSwitch" }) {
                mainWindow.makeKeyAndOrderFront(nil)
            }
        }
    }
}
