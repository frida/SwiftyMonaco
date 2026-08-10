// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftyMonaco",
    platforms: [
        .macOS(.v11), .iOS(.v14)
    ],
    products: [
        .library(
            name: "SwiftyMonaco",
            targets: ["SwiftyMonaco"]),
        .library(
            name: "SwiftyMonacoDynamic",
            type: .dynamic,
            targets: ["SwiftyMonaco"]),
        .library(
            name: "MonacoWebBundle",
            targets: ["MonacoWebBundle"]),
    ],
    targets: [
        .target(
            name: "MonacoWebBundle",
            resources: [
                .copy("Monaco"),
            ]),
        .target(
            name: "SwiftyMonaco",
            dependencies: ["MonacoWebBundle"],
            resources: [
                .copy("Highlighting/Languages"),
            ]),
        .testTarget(
            name: "SwiftyMonacoTests",
            dependencies: ["SwiftyMonaco"]),
    ]
)
