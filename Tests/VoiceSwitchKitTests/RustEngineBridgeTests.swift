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
    func bridgeCanInvokeRustCli() throws {
        let bridge = RustEngineBridge()

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
