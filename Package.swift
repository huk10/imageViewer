// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ImageViewer",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "ImageViewer",
            targets: [
                "ImageViewer-1",
                "ImageViewer-2",
                "ImageViewer-3",
                "ImageViewer-4"
            ]),
    ],
    targets: [
        .target(
            name: "ImageViewer-1",
            dependencies: [.target(name: "SharedResources")]
        ),
        .target(
            name: "ImageViewer-2",
            dependencies: [.target(name: "SharedResources")]
        ),
        .target(
            name: "ImageViewer-3",
            dependencies: [.target(name: "SharedResources")]
        ),
        .target(
            name: "ImageViewer-4",
            dependencies: [.target(name: "SharedResources")]
        ),
        .target(
            name: "SharedResources",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        ),
    ]
)
