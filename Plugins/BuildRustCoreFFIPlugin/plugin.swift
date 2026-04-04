import Foundation
import PackagePlugin

@main
struct BuildRustCoreFFIPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let script = context.package.directoryURL.appending(path: "scripts/build-rust-ffi.sh")

        return [
            .prebuildCommand(
                displayName: "Build Rust staticlib for VoiceSwitch FFI",
                executable: URL(fileURLWithPath: "/bin/sh"),
                arguments: [
                    script.path,
                    context.package.directoryURL.path,
                    context.pluginWorkDirectoryURL.path,
                ],
                outputFilesDirectory: context.pluginWorkDirectoryURL
            )
        ]
    }
}
