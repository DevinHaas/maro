// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Maro",
    platforms: [.macOS(.v13)],
    products: [.library(name: "MaroCore", targets: ["MaroCore"]),
               .executable(name: "maroctl", targets: ["MaroCLI"]),
               .executable(name: "Maro", targets: ["MaroApp"])],
    targets: [
        .target(name: "MaroCore"),
        .executableTarget(name: "MaroCLI", dependencies: ["MaroCore"]),
        .executableTarget(name: "MaroApp", dependencies: ["MaroCore"]),
        .testTarget(name: "MaroCoreTests", dependencies: ["MaroCore"]),
        .testTarget(name: "MaroAppTests", dependencies: ["MaroApp", "MaroCore"])
    ]
)
