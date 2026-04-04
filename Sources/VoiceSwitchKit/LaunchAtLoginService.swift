import Foundation
import ServiceManagement

public enum LaunchAtLoginError: LocalizedError {
    case requiresApproval
    case operationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .requiresApproval:
            return "Launch at Login requires user approval in Login Items."
        case let .operationFailed(message):
            return message
        }
    }
}

public struct NoopLaunchAtLoginController: LaunchAtLoginControlling {
    public init() {}

    public func isEnabled() -> Bool {
        false
    }

    public func setEnabled(_ enabled: Bool) throws {}
}

public final class LaunchAtLoginService: LaunchAtLoginControlling, @unchecked Sendable {
    private let appService: SMAppService

    public init(appService: SMAppService = .mainApp) {
        self.appService = appService
    }

    public func isEnabled() -> Bool {
        appService.status == .enabled
    }

    public func setEnabled(_ enabled: Bool) throws {
        do {
            if enabled {
                try appService.register()
            } else {
                try appService.unregister()
            }
        } catch {
            throw LaunchAtLoginError.operationFailed(error.localizedDescription)
        }

        if enabled, appService.status == .requiresApproval {
            throw LaunchAtLoginError.requiresApproval
        }
    }
}
