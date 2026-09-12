// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "FruitflyBrainPreview", platforms: [.macOS(.v14)], products: [
    .executable(name: "FruitflyBrainPreview", targets: ["BrainPreview"]),
    .executable(name: "BrainChecks", targets: ["BrainChecks"])
], targets: [
    .target(name: "BrainKernel", publicHeadersPath: "include", cxxSettings: [.unsafeFlags(["-ffp-contract=off"])]),
    .target(name: "BrainCore", dependencies: ["BrainKernel"]),
    .executableTarget(name: "BrainPreview", dependencies: ["BrainCore"]),
    .executableTarget(name: "BrainChecks", dependencies: ["BrainCore"])
], cxxLanguageStandard: .cxx17)
