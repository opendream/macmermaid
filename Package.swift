// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MacMermaid",
    platforms: [.macOS(.v26)],
    products: [.executable(name: "MacMermaid", targets: ["MacMermaid"])],
    targets: [
        .executableTarget(name: "MacMermaid", resources: [.copy("Resources/Web")]),
        .testTarget(name: "MacMermaidTests", dependencies: ["MacMermaid"])
    ],
    swiftLanguageModes: [.v5]
)
