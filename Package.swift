// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FlowerRescue",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "FlowerRescueCore", targets: ["FlowerRescueCore"])],
    targets: [
        .target(name: "FlowerRescueCore"),
        .testTarget(name: "FlowerRescueCoreTests", dependencies: ["FlowerRescueCore"])
    ]
)
