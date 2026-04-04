import SwiftUI
import VoiceSwitchKit

struct RetryMonitoringButton: View {
    @Bindable var model: VoiceSwitchAppModel

    var body: some View {
        if model.shouldHighlightRetryMonitoring {
            retryButton
                .buttonStyle(.borderedProminent)
        } else {
            retryButton
                .buttonStyle(.bordered)
        }
    }

    private var retryButton: some View {
        Button("重试监听") {
            model.retryKeyboardMonitoring()
        }
    }
}
