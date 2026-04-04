import SwiftUI
import VoiceSwitchKit

struct StatusMenuView: View {
    @Bindable var model: VoiceSwitchAppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("VoiceSwitch")
                .font(.headline)

            Text("Primary: \(model.selectedPrimaryInputSourceID ?? "Not Set")")
            Text("Voice: \(model.selectedVoiceInputSourceID ?? "Not Set")")
            Text("Launch at Login: \(model.launchAtLoginEnabled ? "On" : "Off")")
            Text("Engine State: \(displayName(for: model.currentEngineState))")
            Text("Last Action: \(model.lastEngineAction?.rawValue ?? "none")")

            if let issue = model.configurationIssues.first {
                Text(issue)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Divider()

            Button("Open Settings") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.sendAction(#selector(AppDelegate.showSettingsWindow(_:)), to: nil, from: nil)
            }

            Button("Open Logs") {
                openWindow(id: "logs")
            }

            Divider()

            Text("Accessibility: \(model.permissionSnapshot.accessibility.rawValue)")
            Text("Input Monitoring: \(model.permissionSnapshot.inputMonitoring.rawValue)")
        }
        .padding(12)
        .frame(width: 280)
        .task {
            try? model.load()
        }
    }

    private func displayName(for state: EngineState) -> String {
        switch state {
        case .idlePrimary:
            return "Typing"
        case .voiceHeld:
            return "Voice Held"
        case .cooldown:
            return "Cooldown"
        }
    }
}
