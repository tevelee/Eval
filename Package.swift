// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "Eval",
    products: [
        .library(
            name: "Eval",
            targets: ["Eval"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Eval",
            dependencies: []),
        .testTarget(
            name: "EvalTests",
            dependencies: ["Eval"]),
    ]
)
