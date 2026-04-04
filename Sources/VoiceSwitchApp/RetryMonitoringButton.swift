import SwiftUI
import VoiceSwitchKit

struct RetryMonitoringButton: View {
    @Bindable var model: VoiceSwitchAppModel

    var body: some View {
        if model.shouldHighlightRetryMonitoring {
            Button("重试监听") {
                model.retryKeyboardMonitoring()
            }
            .buttonStyle(.borderedProminent)
        } else {
            Button("重试监听") {
                model.retryKeyboardMonitoring()
            }
            .buttonStyle(.bordered)
        }
    }
}
