// swift-tools-version:4.2

import PackageDescription

let package = Package(
    name: "ColorParserExample",
    products: [
        .library(
            name: "ColorParserExample",
            targets: ["ColorParserExample"])
    ],
    dependencies: [
        .package(url: "../../", from: "1.4.0")
    ],
    targets: [
        .target(
            name: "ColorParserExample",
            dependencies: ["Eval"]),
        .testTarget(
            name: "ColorParserExampleTests",
            dependencies: ["ColorParserExample"])
    ]
)
