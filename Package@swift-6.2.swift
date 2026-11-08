// swift-tools-version: 6.2
import PackageDescription
import Foundation

// The preview build validates AppKit and core behavior on older toolchains.
// Production always includes the real, pinned speech engine.
let preview = ProcessInfo.processInfo.environment["VOICEBAR_PREVIEW"] == "1"
var dependencies: [Package.Dependency] = []
if !preview {
    dependencies = [.package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.17.7", traits: [])]
}

let package = Package(
    name: "lisan",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "lisan", targets: ["VoiceBar"])],
    dependencies: dependencies,
    targets: [
        .target(name: "VoiceBarCore"),
        .executableTarget(
            name: "VoiceBar",
            dependencies: [.target(name: "VoiceBarCore")] + (preview ? [] : [.product(name: "FluidAudio", package: "FluidAudio")]),
            swiftSettings: preview ? [.define("VOICEBAR_PREVIEW")] : []
        ),
        .executableTarget(name: "VoiceBarCoreTests", dependencies: ["VoiceBarCore"], path: "Tests/VoiceBarCoreTests")
    ],
    swiftLanguageModes: [.v5]
)
