// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "TypingPianoProbe",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "TypingPianoProbe", targets: ["PianoProbe"])],
    targets: [
        .target(name: "PianoCore"),
        .target(name: "PianoAudio"),
        .target(name: "PianoMac", dependencies: ["PianoCore", "PianoAudio"]),
        .executableTarget(name: "PianoProbe", dependencies: ["PianoMac", "PianoCore", "PianoAudio"]),
        .testTarget(name: "PianoCoreTests", dependencies: ["PianoCore"]),
        .testTarget(name: "PianoAudioTests", dependencies: ["PianoAudio"]),
        .testTarget(name: "PianoMacTests", dependencies: ["PianoMac", "PianoCore"])
    ],
    swiftLanguageModes: [.v5]
)
