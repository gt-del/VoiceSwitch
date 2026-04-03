import Foundation

public protocol EngineBridging: Sendable {
    func transition(from currentState: EngineState, event: InputBehavior) throws -> EngineTransitionResult
}

protocol RustCommandRunning: Sendable {
    func run(state: EngineState, event: InputBehavior) throws -> Data
}

public struct RustEngineBridge: EngineBridging, Sendable {
    private let commandRunner: any RustCommandRunning

    public init() {
        self.commandRunner = ProcessRustCommandRunner()
    }

    init(commandRunner: any RustCommandRunning) {
        self.commandRunner = commandRunner
    }

    public func transition(from currentState: EngineState, event: InputBehavior) throws -> EngineTransitionResult {
        let output = try commandRunner.run(state: currentState, event: event)

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

    func run(state: EngineState, event: InputBehavior) throws -> Data {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

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
    case processLaunchFailed(Error)
    case commandFailed(status: Int32, stderr: String)
    case invalidOutput(Error, String)
}
