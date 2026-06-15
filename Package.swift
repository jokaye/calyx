// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Calyx",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Calyx", targets: ["Portainer"])
    ],
    targets: [
        .executableTarget(
            name: "Portainer",
            path: "Sources/Portainer"
        ),
        .testTarget(
            name: "PortainerTests",
            dependencies: ["Portainer"],
            path: "Tests/PortainerTests"
        )
    ]
)
