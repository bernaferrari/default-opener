// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Opener",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "opener", targets: ["OpenerCLI"]),
        .library(name: "OpenerCore", targets: ["OpenerCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "OpenerCore",
            dependencies: []
        ),
        .executableTarget(
            name: "OpenerCLI",
            dependencies: [
                "OpenerCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "OpenerCoreTests",
            dependencies: ["OpenerCore"]
        ),
    ]
)
