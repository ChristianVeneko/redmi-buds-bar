// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RedmiBudsBar",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "BudsProtocol", targets: ["BudsProtocol"]),
        .executable(name: "RedmiBudsBar", targets: ["RedmiBudsBar"]),
    ],
    targets: [
        // Pure Swift protocol implementation. No IOBluetooth dependency.
        .target(name: "BudsProtocol"),
        // Menu bar app: IOBluetooth RFCOMM transport, view model and SwiftUI views.
        .executableTarget(
            name: "RedmiBudsBar",
            dependencies: ["BudsProtocol"],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(name: "BudsProtocolTests", dependencies: ["BudsProtocol"]),
    ]
)
