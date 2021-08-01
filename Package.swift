// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "xcframework-now",
    platforms: [
        .macOS(.v11),
    ],
    products: [
        .executable(
            name: "xcframework-now",
            targets: ["XCFrameworkNowExecutable"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "0.4.0"),
    ],
    targets: [
        .target(
            name: "XCFrameworkNowExecutable",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "XCFrameworkNow"
            ]),
        .target(
            name: "XCFrameworkNow",
            dependencies: ["arm64-to-sim"]),
        .target(
            name: "arm64-to-sim",
            dependencies: [],
            exclude: ["LICENSE.txt"]),
        .testTarget(
            name: "XCFrameworkNowTests",
            dependencies: ["XCFrameworkNow"]),
    ]
)
