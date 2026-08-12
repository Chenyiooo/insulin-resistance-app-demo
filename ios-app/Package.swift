// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "InsulinResistanceApp",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .executable(name: "InsulinResistanceApp", targets: ["InsulinResistanceApp"])
    ],
    targets: [
        .executableTarget(
            name: "InsulinResistanceApp",
            path: "Sources/InsulinResistanceApp"
        )
    ]
)
