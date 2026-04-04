import SwiftUI
import VoiceSwitchKit

struct StatusMenuView: View {
    @Bindable var model: VoiceSwitchAppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("VoiceSwitch")
                .font(.headline)

            Text("Status: \(model.statusSummary)")

            if let issue = model.blockingIssue, model.isEnabled {
                Text(issue)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Divider()

            Button("Open VoiceSwitch") {
                openWindow(id: "main")
            }

            Button(model.isEnabled ? "Disable" : "Enable") {
                model.setEnabled(!model.isEnabled)
            }

            Button("Retry Monitoring") {
                model.retryKeyboardMonitoring()
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 260)
    }
}
