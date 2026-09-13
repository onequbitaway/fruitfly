// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "FlyPilot", platforms: [.macOS(.v14)],
    products: [.executable(name: "FlyBrainService", targets: ["BrainService"])],
    dependencies: [.package(path: "../full-map")],
    targets: [.executableTarget(name: "BrainService", dependencies: [.product(name: "BrainCore", package: "full-map")])])
