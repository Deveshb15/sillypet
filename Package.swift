// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenPet",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "OpenPet",
            path: "Sources/OpenPet"
        )
    ]
)
