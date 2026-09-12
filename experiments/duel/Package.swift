// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "FruitflyDuel", platforms: [.macOS(.v14)],
  products: [.executable(name: "FruitflyDuel", targets: ["FruitflyDuel"])],
  dependencies: [.package(path: "../full-map")],
  targets: [
    .target(
      name: "DuelCore", dependencies: [.product(name: "BrainCore", package: "full-map")],
      resources: [.copy("Resources/engine.js")]),
    .executableTarget(name: "FruitflyDuel", dependencies: ["DuelCore"]),
    .executableTarget(name: "DuelChecks", dependencies: ["DuelCore"], path: "Tests"),
  ])
