import SwiftUI
import VoiceSwitchKit

struct LogPanelView: View {
    @Bindable var model: VoiceSwitchAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Logs")
                .font(.title2)

            Text("Current State: \(model.currentEngineState.rawValue)")
            Text("Last Event: \(model.lastInputBehavior?.rawValue ?? "none")")
            Text("Last Action: \(model.lastEngineAction?.rawValue ?? "none")")
            Text("Event Tap: \(model.eventTapStatus.rawValue)")
            Text("Accessibility: \(model.permissionSnapshot.accessibility.rawValue)")
            Text("Last Raw Keyboard Event: \(model.lastRawKeyboardEventSummary ?? "none")")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 8) {
                Button("Send Option Pressed") {
                    model.dispatchTestEvent(.optionPressed)
                }
                Button("Send Option Released") {
                    model.dispatchTestEvent(.optionReleased)
                }
                Button("Send Manual Switch") {
                    model.dispatchTestEvent(.manualSwitchDetected)
                }
                Button("Send Cooldown Expired") {
                    model.dispatchTestEvent(.cooldownExpired)
                }
            }

            if model.logEntries.isEmpty {
                ContentUnavailableView("No Logs Yet", systemImage: "text.append")
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
