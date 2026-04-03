import Carbon
import Foundation

public enum InputSourceObservation: Equatable, Sendable {
    case changed(inputSourceID: String?, rawDescription: String)
}

public protocol InputSourceObserving: AnyObject {
    func start(changeHandler: @escaping @Sendable (InputSourceObservation) -> Void)
    func stop()
}

public final class InputSourceObservationService: InputSourceObserving, @unchecked Sendable {
    private let inputSourceSwitchingService: InputSourceSwitching
    private let notificationCenter: DistributedNotificationCenter
    private var observer: NSObjectProtocol?
    private var changeHandler: (@Sendable (InputSourceObservation) -> Void)?

    public init(
        inputSourceSwitchingService: InputSourceSwitching,
        notificationCenter: DistributedNotificationCenter = .default()
    ) {
        self.inputSourceSwitchingService = inputSourceSwitchingService
        self.notificationCenter = notificationCenter
    }

    deinit {
        stop()
    }

    public func start(changeHandler: @escaping @Sendable (InputSourceObservation) -> Void) {
        self.changeHandler = changeHandler
        guard observer == nil else {
            return
        }

        observer = notificationCenter.addObserver(
            forName: NSNotification.Name(rawValue: kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.handleInputSourceChanged()
        }
    }

    public func stop() {
        if let observer {
            notificationCenter.removeObserver(observer)
        }
        observer = nil
        changeHandler = nil
    }

    private func handleInputSourceChanged() {
        let currentInputSourceID = try? inputSourceSwitchingService.currentSelectedInputSourceID()
        changeHandler?(.changed(
            inputSourceID: currentInputSourceID,
            rawDescription: "inputSourceChanged(id:\(currentInputSourceID ?? "none"))"
        ))
    }
}
