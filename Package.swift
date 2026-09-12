// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Fruitfly",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Fruitfly", targets: ["Fruitfly"])],
    targets: [
        .executableTarget(name: "Fruitfly")
    ]
)
