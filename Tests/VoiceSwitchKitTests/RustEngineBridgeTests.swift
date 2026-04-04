import Foundation
import Testing
@testable import VoiceSwitchKit

struct RustEngineBridgeTests {
    @Test
    func bridgeDecodesTransitionResult() throws {
        let runner = StubRustCommandRunner(
            output: """
            {"state":"voiceMode","action":"switchToVoice","diagnostic":{"trigger":"controlPressed","reason":"pressed_control_switch_to_voice","sourceState":"idlePrimary","targetState":"voiceMode"},"timer":{"kind":"voiceActivationDelay","delaySeconds":0.05}}
            """.data(using: .utf8)!
        )

        let bridge = RustEngineBridge(commandRunner: runner)
        let result = try bridge.transition(
            from: .idlePrimary,
            event: .controlPressed,
            configuration: EngineConfiguration()
        )

        #expect(result.state == .voiceMode)
        #expect(result.action == .switchToVoice)
        #expect(result.diagnostic.trigger == "controlPressed")
        #expect(result.diagnostic.reason == "pressed_control_switch_to_voice")
        #expect(result.diagnostic.sourceState == .idlePrimary)
        #expect(result.diagnostic.targetState == .voiceMode)
        #expect(result.timer?.kind == .voiceActivationDelay)
        #expect(result.timer?.delaySeconds == 0.05)
    }

    @Test
    func bridgePassesConfigurationToRunner() throws {
        let runner = RecordingRustCommandRunner(
            output: """
            {"state":"voiceMode","action":"switchToVoice","diagnostic":{"trigger":"controlPressed","reason":"pressed_control_switch_to_voice","sourceState":"idlePrimary","targetState":"voiceMode"}}
            """.data(using: .utf8)!
        )

        let bridge = RustEngineBridge(commandRunner: runner)
        _ = try bridge.transition(
            from: .idlePrimary,
            event: .controlPressed,
            configuration: EngineConfiguration(
                voiceActivationDelay: 0.25,
                primaryReturnDelay: 0.1,
                cooldownDuration: 7,
                typingKeyWhitelist: [.letters, .space]
            )
        )

        #expect(runner.lastConfiguration?.voiceActivationDelay == 0.25)
        #expect(runner.lastConfiguration?.primaryReturnDelay == 0.1)
        #expect(runner.lastConfiguration?.cooldownDuration == 7)
        #expect(runner.lastConfiguration?.typingKeyWhitelist == [.letters, .space])
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
            voiceActivationDelay: 0.05,
            primaryReturnDelay: 0.03,
            cooldownDuration: 6,
            typingKeyWhitelist: [.letters, .space]
        )

        let ffiResult = try ffiBridge.transition(
            from: .idlePrimary,
            event: .controlPressed,
            configuration: configuration
        )
        let cliResult = try cliBridge.transition(
            from: .idlePrimary,
            event: .controlPressed,
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
                event: .controlPressed,
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
                event: .controlPressed,
                configuration: EngineConfiguration()
            )

            #expect(result.state == .voiceMode)
            #expect(result.action == .switchToVoice)
            #expect(result.diagnostic.reason == "pressed_control_switch_to_voice")
        }
    }

    @Test
    func ffiBridgeMaintainsCoreTransitionSequence() throws {
        let bridge = FFIRustEngineBridge()
        let configuration = EngineConfiguration()

        let controlPressed = try bridge.transition(
            from: .idlePrimary,
            event: .controlPressed,
            configuration: configuration
        )
        #expect(controlPressed.state == .voiceMode)
        #expect(controlPressed.action == .switchToVoice)
        #expect(controlPressed.diagnostic.reason == "pressed_control_switch_to_voice")

        let secondControlPressed = try bridge.transition(
            from: controlPressed.state,
            event: .controlPressed,
            configuration: configuration
        )
        #expect(secondControlPressed.state == .idlePrimary)
        #expect(secondControlPressed.action == .switchToPrimary)
        #expect(secondControlPressed.diagnostic.reason == "pressed_control_switch_to_primary")

        let manualSwitch = try bridge.transition(
            from: secondControlPressed.state,
            event: .manualSwitchDetected,
            configuration: configuration
        )
        #expect(manualSwitch.state == .cooldown)
        #expect(manualSwitch.action == .enterCooldown)
        #expect(manualSwitch.diagnostic.reason == "entered_cooldown_after_manual_switch")

        let cooldownExpired = try bridge.transition(
            from: manualSwitch.state,
            event: .cooldownExpired,
            configuration: configuration
        )
        #expect(cooldownExpired.state == .idlePrimary)
        #expect(cooldownExpired.action == .noOp)
        #expect(cooldownExpired.diagnostic.reason == "cooldown_expired")
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
