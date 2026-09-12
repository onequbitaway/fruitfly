// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FruitflyRoyale", platforms: [.macOS(.v14)],
    products: [.executable(name: "FruitflyRoyale", targets: ["FruitflyRoyale"])],
    dependencies: [.package(path: "../full-map")],
    targets: [
        .target(name: "RoyaleCore", dependencies: [.product(name: "BrainCore", package: "full-map")]),
        .executableTarget(name: "FruitflyRoyale", dependencies: ["RoyaleCore"]),
        .executableTarget(name: "RoyaleChecks", dependencies: ["RoyaleCore"], path: "Tests")
    ])
