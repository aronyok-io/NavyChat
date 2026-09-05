// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RelaylineDesktopDemo",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "RelaylineDesktopDemo", targets: ["RelaylineDesktopDemo"])
    ],
    targets: [
        .executableTarget(
            name: "RelaylineDesktopDemo",
            path: "Sources"
        )
    ]
)
