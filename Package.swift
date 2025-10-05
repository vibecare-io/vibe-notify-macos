// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VibeNotify",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "VibeNotify",
            targets: ["VibeNotify"]),
    ],
    dependencies: [
        .package(url: "https://github.com/exyte/SVGView.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "VibeNotify",
            dependencies: ["SVGView"]),
        .testTarget(
            name: "VibeNotifyTests",
            dependencies: ["VibeNotify"]
        ),
    ]
)
