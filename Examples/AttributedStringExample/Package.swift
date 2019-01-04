// swift-tools-version:4.2

import PackageDescription

let package = Package(
    name: "AttributedStringExample",
    products: [
        .library(
            name: "AttributedStringExample",
            targets: ["AttributedStringExample"])
    ],
    dependencies: [
        .package(url: "../../", from: "1.4.0")
    ],
    targets: [
        .target(
            name: "AttributedStringExample",
            dependencies: ["Eval"]),
        .testTarget(
            name: "AttributedStringExampleTests",
            dependencies: ["AttributedStringExample"])
    ]
)
