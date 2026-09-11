// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Bezel",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Bezel",
            path: "Sources/Bezel"
        )
    ]
)
