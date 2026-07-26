// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "matte-lab",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "matte-lab")
    ]
)
