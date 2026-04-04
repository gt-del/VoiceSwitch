import Foundation
import VoiceSwitchFFI

public protocol EngineBridging: Sendable {
    func transition(
        from currentState: EngineState,
        event: InputBehavior,
        configuration: EngineConfiguration
    ) throws -> EngineTransitionResult
}

protocol RustCommandRunning: Sendable {
    func run(state: EngineState, event: InputBehavior, configuration: EngineConfiguration) throws -> Data
}

enum RustEngineBridgeBackendKind: Sendable {
    case ffi
    case cli
}

public struct RustEngineBridge: EngineBridging, Sendable {
    private let bridge: any EngineBridging
    let backendKind: RustEngineBridgeBackendKind

    public init() {
        self.bridge = FFIRustEngineBridge()
        self.backendKind = .ffi
    }

    init(commandRunner: any RustCommandRunning) {
        self.bridge = CLIRustEngineBridge(commandRunner: commandRunner)
        self.backendKind = .cli
    }

    init(bridge: any EngineBridging, backendKind: RustEngineBridgeBackendKind) {
        self.bridge = bridge
        self.backendKind = backendKind
    }

    public func transition(
        from currentState: EngineState,
        event: InputBehavior,
        configuration: EngineConfiguration
    ) throws -> EngineTransitionResult {
        try bridge.transition(from: currentState, event: event, configuration: configuration)
    }
}

public struct FFIRustEngineBridge: EngineBridging, Sendable {
    public init() {}

    public func transition(
        from currentState: EngineState,
        event: InputBehavior,
        configuration: EngineConfiguration
    ) throws -> EngineTransitionResult {
        var rawResult = VSTransitionResult(
            state: VSStateIdlePrimary,
            action: VSActionNoOp,
            diagnostic: VSDiagnostic(
                trigger: nil,
                reason: nil,
                source_state: VSStateIdlePrimary,
                target_state: VSStateIdlePrimary
            ),
            timer: VSTimer(
                has_value: false,
                kind: VSTimerKindCooldown,
                delay_seconds: 0
            )
        )

        let errorCode = vs_engine_transition(
            ffiState(from: currentState),
            ffiEvent(from: event),
            ffiConfiguration(from: configuration),
            &rawResult
        )

        guard errorCode == VSErrorCodeOk else {
            throw RustEngineBridgeError.ffiError(
                code: Int32(errorCode.rawValue),
                message: ffiErrorMessage(for: errorCode)
            )
        }

        defer {
            vs_transition_result_free(&rawResult)
        }

        return try EngineTransitionResult(
            state: engineState(from: rawResult.state),
            action: engineAction(from: rawResult.action),
            diagnostic: DiagnosticEntry(
                trigger: try ffiString(rawResult.diagnostic.trigger, fieldName: "trigger"),
                reason: try ffiString(rawResult.diagnostic.reason, fieldName: "reason"),
                sourceState: try engineState(from: rawResult.diagnostic.source_state),
                targetState: try engineState(from: rawResult.diagnostic.target_state)
            ),
            timer: try engineTimer(from: rawResult.timer)
        )
    }

    private func ffiConfiguration(from configuration: EngineConfiguration) -> VSConfiguration {
        let whitelist = Set(configuration.typingKeyWhitelist)
        return VSConfiguration(
            voice_activation_delay: configuration.voiceActivationDelay,
            primary_return_delay: configuration.primaryReturnDelay,
            cooldown_duration: configuration.cooldownDuration,
            allow_letters: whitelist.contains(.letters),
            allow_numbers: whitelist.contains(.numbers),
            allow_space: whitelist.contains(.space),
            allow_delete: whitelist.contains(.delete),
            allow_return_key: whitelist.contains(.returnKey)
        )
    }

    private func ffiState(from state: EngineState) -> VSState {
        switch state {
        case .idlePrimary:
            return VSStateIdlePrimary
        case .voiceMode:
            return VSStateVoiceMode
        case .cooldown:
            return VSStateCooldown
        }
    }

    private func ffiEvent(from event: InputBehavior) -> VSEvent {
        switch event {
        case .controlPressed:
            return VSEventControlPressed
        case .controlReleased:
            return VSEventControlReleased
        case .typingDetected:
            return VSEventTypingDetected
        case .typingKeyLetters:
            return VSEventTypingKeyLetters
        case .typingKeyNumbers:
            return VSEventTypingKeyNumbers
        case .typingKeySpace:
            return VSEventTypingKeySpace
        case .typingKeyDelete:
            return VSEventTypingKeyDelete
        case .typingKeyReturnKey:
            return VSEventTypingKeyReturnKey
        case .manualSwitchDetected:
            return VSEventManualSwitchDetected
        case .cooldownExpired:
            return VSEventCooldownExpired
        }
    }

    private func engineState(from state: VSState) throws -> EngineState {
        switch state {
        case VSStateIdlePrimary:
            return .idlePrimary
        case VSStateVoiceMode:
            return .voiceMode
        case VSStateCooldown:
            return .cooldown
        default:
            throw RustEngineBridgeError.invalidFFIState("unknown state rawValue=\(state.rawValue)")
        }
    }

    private func engineAction(from action: VSAction) throws -> EngineAction {
        switch action {
        case VSActionSwitchToPrimary:
            return .switchToPrimary
        case VSActionSwitchToVoice:
            return .switchToVoice
        case VSActionEnterCooldown:
            return .enterCooldown
        case VSActionNoOp:
            return .noOp
        default:
            throw RustEngineBridgeError.invalidFFIState("unknown action rawValue=\(action.rawValue)")
        }
    }

    private func engineTimer(from timer: VSTimer) throws -> EngineTimer? {
        guard timer.has_value else {
            return nil
        }

        let kind: EngineTimerKind
        switch timer.kind {
        case VSTimerKindVoiceActivationDelay:
            kind = .voiceActivationDelay
        case VSTimerKindPrimaryReturnDelay:
            kind = .primaryReturnDelay
        case VSTimerKindCooldown:
            kind = .cooldown
        default:
            throw RustEngineBridgeError.invalidFFIState("unknown timer rawValue=\(timer.kind.rawValue)")
        }

        return EngineTimer(kind: kind, delaySeconds: timer.delay_seconds)
    }

    private func ffiString(_ pointer: UnsafeMutablePointer<CChar>?, fieldName: String) throws -> String {
        guard let pointer else {
            throw RustEngineBridgeError.invalidFFIState("missing diagnostic field \(fieldName)")
        }
        return String(cString: pointer)
    }

    private func ffiErrorMessage(for code: VSErrorCode) -> String {
        guard let pointer = vs_error_message(code) else {
            return "unknown ffi error"
        }
        return String(cString: pointer)
    }
}

struct CLIRustEngineBridge: EngineBridging, Sendable {
    private let commandRunner: any RustCommandRunning

    init(commandRunner: any RustCommandRunning = ProcessRustCommandRunner()) {
        self.commandRunner = commandRunner
    }

    func transition(
        from currentState: EngineState,
        event: InputBehavior,
        configuration: EngineConfiguration
    ) throws -> EngineTransitionResult {
        let output = try commandRunner.run(state: currentState, event: event, configuration: configuration)

        do {
            return try JSONDecoder().decode(EngineTransitionResult.self, from: output)
        } catch {
            throw RustEngineBridgeError.invalidOutput(error, String(decoding: output, as: UTF8.self))
        }
    }
}

struct ProcessRustCommandRunner: RustCommandRunning {
    private let cargoManifestPath: String

    init(cargoManifestPath: String = Self.defaultManifestPath) {
        self.cargoManifestPath = cargoManifestPath
    }

    func run(state: EngineState, event: InputBehavior, configuration: EngineConfiguration) throws -> Data {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let configurationPayload: Data

        do {
            configurationPayload = try JSONEncoder().encode(configuration)
        } catch {
            throw RustEngineBridgeError.configurationEncodeFailed(error)
        }

        let configurationArgument = String(decoding: configurationPayload, as: UTF8.self)

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "cargo",
            "run",
            "--quiet",
            "--manifest-path",
            cargoManifestPath,
            "--bin",
            "voiceswitch-core-cli",
            "--",
            state.rawValue,
            event.rawValue,
            configurationArgument,
        ]
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw RustEngineBridgeError.processLaunchFailed(error)
        }

        process.waitUntilExit()

        let output = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            throw RustEngineBridgeError.commandFailed(
                status: process.terminationStatus,
                stderr: String(decoding: stderr, as: UTF8.self)
            )
        }

        return output
    }

    private static var defaultManifestPath: String {
        repositoryRootURL()
            .appendingPathComponent("RustCore")
            .appendingPathComponent("Cargo.toml")
            .path
    }

    private static func repositoryRootURL(filePath: String = #filePath) -> URL {
        URL(fileURLWithPath: filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

enum RustEngineBridgeError: Error {
    case configurationEncodeFailed(Error)
    case processLaunchFailed(Error)
    case commandFailed(status: Int32, stderr: String)
    case invalidOutput(Error, String)
    case ffiError(code: Int32, message: String)
    case invalidFFIState(String)
}
