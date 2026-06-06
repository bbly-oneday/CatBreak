// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CatBreak",
    platforms: [.macOS("13.0")],
    products: [
        .executable(
            name: "CatBreak",
            targets: ["CatBreak"]
        )
    ],
    targets: [
        .executableTarget(
            name: "CatBreak",
            dependencies: [],
            path: "Sources/CatBreak",
            resources: [.copy("../../Resources")]
        )
    ]
)
