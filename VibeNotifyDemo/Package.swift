// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VibeNotifyDemo",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [
        .package(path: "../")
    ],
    targets: [
        .executableTarget(
            name: "VibeNotifyDemo",
            dependencies: [
                .product(name: "VibeNotify", package: "simple-alerts")
            ]),
    ]
)
