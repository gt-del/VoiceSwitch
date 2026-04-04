import Foundation
import PackagePlugin

@main
struct BuildRustCoreFFIPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let packageDirectory = context.package.directoryURL
        let script = packageDirectory.appending(path: "scripts/build-rust-ffi.sh")
        let outputDirectory = context.pluginWorkDirectoryURL
        let libraryOutput = outputDirectory.appending(path: "libvoiceswitch_core.a")
        let stampOutput = outputDirectory.appending(path: "rust-ffi.stamp")

        return [
            .buildCommand(
                displayName: "Build Rust staticlib for VoiceSwitch FFI",
                executable: URL(fileURLWithPath: "/bin/sh"),
                arguments: [
                    script.path,
                    packageDirectory.path,
                    outputDirectory.path,
                ],
                inputFiles: try trackedRustInputs(packageDirectory: packageDirectory, script: script),
                outputFiles: [
                    libraryOutput,
                    stampOutput,
                ]
            )
        ]
    }

    private func trackedRustInputs(packageDirectory: URL, script: URL) throws -> [URL] {
        let fileManager = FileManager.default
        let rustCoreDirectory = packageDirectory.appending(path: "RustCore")
        let rustSourceDirectory = rustCoreDirectory.appending(path: "src")
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey]

        var inputs = [
            script,
            rustCoreDirectory.appending(path: "Cargo.toml"),
            rustCoreDirectory.appending(path: "Cargo.lock"),
        ]

        if let enumerator = fileManager.enumerator(
            at: rustSourceDirectory,
            includingPropertiesForKeys: resourceKeys
        ) {
            for case let fileURL as URL in enumerator {
                let values = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                if values.isRegularFile == true {
                    inputs.append(fileURL)
                }
            }
        }

        return inputs.sorted { $0.path < $1.path }
    }
}
