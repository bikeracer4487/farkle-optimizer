// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "FarkleOptimizer",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "FarkleCore", targets: ["FarkleCore"]),
        .executable(name: "FarkleOptimizer", targets: ["FarkleOptimizer"]),
    ],
    targets: [
        .target(name: "FarkleCore", swiftSettings: [.unsafeFlags(["-Ounchecked"], .when(configuration: .release))]),
        .executableTarget(name: "FarkleOptimizer", dependencies: ["FarkleCore"]),
        .executableTarget(name: "farkle-bench", dependencies: ["FarkleCore"], path: "Sources/FarkleBench"),
        .testTarget(name: "FarkleCoreTests", dependencies: ["FarkleCore"]),
    ]
)
