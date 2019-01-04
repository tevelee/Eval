// swift-tools-version:4.2

import PackageDescription

let package = Package(
    name: "TemplateExample",
    products: [
        .library(
            name: "TemplateExample",
            targets: ["TemplateExample"])
    ],
    dependencies: [
        .package(url: "../../", from: "1.4.0")
    ],
    targets: [
        .target(
            name: "TemplateExample",
            dependencies: ["Eval"]),
        .testTarget(
            name: "TemplateExampleTests",
            dependencies: ["TemplateExample"])
    ]
)
