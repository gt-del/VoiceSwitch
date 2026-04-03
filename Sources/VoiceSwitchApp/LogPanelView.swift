import SwiftUI
import VoiceSwitchKit

struct LogPanelView: View {
    let model: VoiceSwitchAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Logs")
                .font(.title2)

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
