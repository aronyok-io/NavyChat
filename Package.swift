// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Relayline",
    products: [
        .library(name: "MeshChatCore", targets: ["MeshChatCore"]),
        .executable(name: "RelaylineCLI", targets: ["RelaylineCLI"])
    ],
    targets: [
        .target(name: "MeshChatCore"),
        .executableTarget(name: "RelaylineCLI", dependencies: ["MeshChatCore"]),
        .testTarget(name: "MeshChatCoreTests", dependencies: ["MeshChatCore"])
    ]
)
