import Foundation
import Testing
@testable import VoiceSwitchKit

struct RustEngineBridgeTests {
    @Test
    func bridgeDecodesTransitionResult() throws {
        let runner = StubRustCommandRunner(
            output: """
            {"state":"optionPending","action":"noOp","diagnostic":{"trigger":"optionPressed","reason":"entered_option_pending","sourceState":"idlePrimary","targetState":"optionPending"},"timer":{"kind":"optionPendingWindow","delaySeconds":0.25}}
            """.data(using: .utf8)!
        )

        let bridge = RustEngineBridge(commandRunner: runner)
        let result = try bridge.transition(
            from: .idlePrimary,
            event: .optionPressed,
            configuration: EngineConfiguration()
        )

        #expect(result.state == .optionPending)
        #expect(result.action == .noOp)
        #expect(result.diagnostic.trigger == "optionPressed")
        #expect(result.diagnostic.reason == "entered_option_pending")
        #expect(result.diagnostic.sourceState == .idlePrimary)
        #expect(result.diagnostic.targetState == .optionPending)
        #expect(result.timer?.kind == .optionPendingWindow)
        #expect(result.timer?.delaySeconds == 0.25)
    }

    @Test
    func bridgePassesConfigurationToRunner() throws {
        let runner = RecordingRustCommandRunner(
            output: """
            {"state":"optionPending","action":"noOp","diagnostic":{"trigger":"optionPressed","reason":"entered_option_pending","sourceState":"idlePrimary","targetState":"optionPending"}}
            """.data(using: .utf8)!
        )

        let bridge = RustEngineBridge(commandRunner: runner)
        _ = try bridge.transition(
            from: .idlePrimary,
            event: .optionPressed,
            configuration: EngineConfiguration(
                optionPendingWindow: 0.25,
                cooldownDuration: 7,
                voiceExitDelay: 1.2
            )
        )

        #expect(runner.lastConfiguration?.optionPendingWindow == 0.25)
        #expect(runner.lastConfiguration?.cooldownDuration == 7)
        #expect(runner.lastConfiguration?.voiceExitDelay == 1.2)
    }

    @Test
    func defaultBridgeUsesFFIBackend() {
        let bridge = RustEngineBridge()

        #expect(bridge.backendKind == .ffi)
    }

    @Test
    func ffiBridgeMatchesCliBridge() throws {
        let ffiBridge = FFIRustEngineBridge()
        let cliBridge = CLIRustEngineBridge()
        let configuration = EngineConfiguration(
            optionPendingWindow: 0.32,
            cooldownDuration: 6,
            voiceExitDelay: 1.1,
            typingKeyWhitelist: [.letters, .space]
        )

        let ffiResult = try ffiBridge.transition(
            from: .voiceActive,
            event: .typingKeyLetters,
            configuration: configuration
        )
        let cliResult = try cliBridge.transition(
            from: .voiceActive,
            event: .typingKeyLetters,
            configuration: configuration
        )

        #expect(ffiResult == cliResult)
    }

    @Test
    func ffiBridgeReturnsInvalidConfigurationError() throws {
        let bridge = FFIRustEngineBridge()

        #expect(throws: RustEngineBridgeError.self) {
            _ = try bridge.transition(
                from: .idlePrimary,
                event: .optionPressed,
                configuration: EngineConfiguration(typingKeyWhitelist: [])
            )
        }
    }

    @Test
    func ffiBridgeSupportsRepeatedCallsWithoutCliRunner() throws {
        let bridge = FFIRustEngineBridge()

        for _ in 0..<100 {
            let result = try bridge.transition(
                from: .idlePrimary,
                event: .optionPressed,
                configuration: EngineConfiguration()
            )

            #expect(result.state == .optionPending)
            #expect(result.action == .noOp)
            #expect(result.diagnostic.reason == "entered_option_pending")
        }
    }
}

private struct StubRustCommandRunner: RustCommandRunning {
    let output: Data

    func run(state: EngineState, event: InputBehavior, configuration: EngineConfiguration) throws -> Data {
        output
    }
}

private final class RecordingRustCommandRunner: RustCommandRunning, @unchecked Sendable {
    let output: Data
    private(set) var lastConfiguration: EngineConfiguration?

    init(output: Data) {
        self.output = output
    }

    func run(state: EngineState, event: InputBehavior, configuration: EngineConfiguration) throws -> Data {
        lastConfiguration = configuration
        return output
    }
}
