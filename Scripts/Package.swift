// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "Automation",
    products: [
        .library(
            name: "Automation",
            targets: ["Automation"]),
        ],
    dependencies: [
        .package(url: "https://github.com/xcodeswift/xcproj.git", from: "4.0.0"),
        ],
    targets: [
        .target(
            name: "Automation",
            dependencies: ["xcproj"]),
        ]
)
