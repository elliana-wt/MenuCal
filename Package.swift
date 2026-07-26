// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MenuCal",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MenuCal", targets: ["MenuCal"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-testing.git", exact: "0.12.0")
    ],
    targets: [
        .executableTarget(
            name: "MenuCal",
            path: "Sources/MenuCal"
        ),
        .testTarget(
            name: "MenuCalTests",
            dependencies: [
                "MenuCal",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests/MenuCalTests"
        )
    ]
)
