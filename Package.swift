// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "Spiritbound",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SpiritboundCore", targets: ["SpiritboundCore"]),
        .library(name: "SpiritboundUI", targets: ["SpiritboundUI"])
    ],
    targets: [
        .target(name: "SpiritboundCore", resources: [.process("Resources")]),
        .target(name: "SpiritboundUI", dependencies: ["SpiritboundCore"]),
        .testTarget(name: "SpiritboundCoreTests", dependencies: ["SpiritboundCore"])
    ]
)
