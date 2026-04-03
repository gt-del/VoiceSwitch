import Foundation

public protocol CooldownScheduling: AnyObject {
    func schedule(deadline: Date, onFire: @escaping @Sendable () -> Void)
    func cancel()
}

public final class CooldownScheduler: CooldownScheduling {
    private var timer: Timer?

    public init() {}

    deinit {
        cancel()
    }

    public func schedule(deadline: Date, onFire: @escaping @Sendable () -> Void) {
        cancel()

        let interval = max(0, deadline.timeIntervalSinceNow)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            onFire()
        }
    }

    public func cancel() {
        timer?.invalidate()
        timer = nil
    }
}
