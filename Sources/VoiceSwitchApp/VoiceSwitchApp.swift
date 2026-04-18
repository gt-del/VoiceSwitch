import SwiftUI
import VoiceSwitchKit
import AppKit

enum VoiceSwitchWindowID {
    static let main = "main"
    static let title = "VoiceSwitch"
}

enum MainWindowLaunchPolicy: Equatable {
    case presentedOnLaunch
}

enum MainWindowSceneKind: Equatable {
    case appDelegateManagedWindow
}

func mainWindowLaunchPolicy() -> MainWindowLaunchPolicy {
    .presentedOnLaunch
}

func mainWindowSceneKind() -> MainWindowSceneKind {
    .appDelegateManagedWindow
}

@main
struct VoiceSwitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model: VoiceSwitchAppModel

    init() {
        let model = makeVoiceSwitchAppModel()
        MainWindowBootstrapStore.model = model
        _model = State(initialValue: model)
    }

    var body: some Scene {
        let _ = appDelegate.refreshManagedMainWindowContentIfNeeded()

        MenuBarExtra("VoiceSwitch", systemImage: "waveform.and.mic") {
            StatusMenuView(model: model)
        }
    }
}
