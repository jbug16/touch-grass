// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TouchGrass",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .target(name: "TouchGrassCore"),
        .executableTarget(
            name: "TouchGrass",
            dependencies: ["TouchGrassCore"]
        ),
        .testTarget(
            name: "TouchGrassCoreTests",
            dependencies: ["TouchGrassCore"]
        )
    ]
)
