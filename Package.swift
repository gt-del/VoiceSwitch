// swift-tools-version: 6.2

import PackageDescription
import Foundation

let packageDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let rustFFILibraryDirectory = "\(packageDirectory)/.build/plugins/outputs/voiceswitch/VoiceSwitchFFI/destination/BuildRustCoreFFIPlugin"

let package = Package(
    name: "VoiceSwitch",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(name: "VoiceSwitchKit", targets: ["VoiceSwitchKit"]),
        .executable(name: "VoiceSwitchApp", targets: ["VoiceSwitchApp"]),
    ],
    targets: [
        .target(
            name: "VoiceSwitchFFI",
            publicHeadersPath: "include",
            linkerSettings: [
                .unsafeFlags([
                    "-L", rustFFILibraryDirectory,
                    "-lvoiceswitch_core",
                ]),
            ],
            plugins: ["BuildRustCoreFFIPlugin"]
        ),
        .target(
            name: "VoiceSwitchKit",
            dependencies: ["VoiceSwitchFFI"]
        ),
        .executableTarget(
            name: "VoiceSwitchApp",
            dependencies: ["VoiceSwitchKit"]
        ),
        .testTarget(
            name: "VoiceSwitchKitTests",
            dependencies: ["VoiceSwitchKit"]
        ),
        .plugin(
            name: "BuildRustCoreFFIPlugin",
            capability: .buildTool()
        ),
    ]
)
