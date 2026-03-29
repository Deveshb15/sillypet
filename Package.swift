// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SillyPet",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SillyPet",
            path: "Sources/SillyPet"
        ),
        .testTarget(
            name: "SillyPetTests",
            dependencies: ["SillyPet"],
            path: "Tests/SillyPetTests"
        )
    ]
)
