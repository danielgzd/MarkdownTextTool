// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "MarkdownTextTool",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(name: "MarkdownCore", targets: ["MarkdownCore"])
    ],
    targets: [
        .target(name: "MarkdownCore"),
        .testTarget(name: "MarkdownCoreTests", dependencies: ["MarkdownCore"])
    ]
)
