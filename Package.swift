// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TalkType",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "TalkType", targets: ["TalkType"])],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.6")
    ],
    targets: [
        .executableTarget(
            name: "TalkType",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/TalkType",
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        )
    ]
)
