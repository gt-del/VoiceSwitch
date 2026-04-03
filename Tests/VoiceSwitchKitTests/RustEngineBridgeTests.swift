import Foundation
import Testing
@testable import VoiceSwitchKit

struct RustEngineBridgeTests {
    @Test
    func bridgeDecodesTransitionResult() throws {
        let runner = StubRustCommandRunner(
            output: """
            {"state":"optionPending","action":"noOp","diagnostic":{"message":"Entered optionPending"}}
            """.data(using: .utf8)!
        )

        let bridge = RustEngineBridge(commandRunner: runner)
        let result = try bridge.transition(from: .idlePrimary, event: .optionPressed)

        #expect(result.state == .optionPending)
        #expect(result.action == .noOp)
        #expect(result.diagnostic.message == "Entered optionPending")
    }
}

private struct StubRustCommandRunner: RustCommandRunning {
    let output: Data

    func run(state: EngineState, event: InputBehavior) throws -> Data {
        output
    }
}
