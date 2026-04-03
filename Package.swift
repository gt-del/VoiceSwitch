// swift-tools-version: 6.2

import PackageDescription

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
            name: "VoiceSwitchKit"
        ),
        .executableTarget(
            name: "VoiceSwitchApp",
            dependencies: ["VoiceSwitchKit"]
        ),
        .testTarget(
            name: "VoiceSwitchKitTests",
            dependencies: ["VoiceSwitchKit"]
        ),
    ]
)
