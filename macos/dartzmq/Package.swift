// swift-tools-version: 5.9

import Foundation
import PackageDescription

let packageRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path

let package = Package(
    name: "dartzmq",
    platforms: [
        .macOS("15.0"),
    ],
    products: [
        .library(name: "dartzmq", type: .static, targets: ["dartzmq"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .target(
            name: "dartzmq",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ],
            path: "Sources/dartzmq",
            linkerSettings: [
                // Dart looks up libzmq symbols in the process at runtime, so
                // retain every symbol from the bundled static archive.
                .unsafeFlags([
                    "-Xlinker", "-force_load",
                    "-Xlinker", "\(packageRoot)/../Frameworks/libdartzmq.a",
                ]),
                .linkedLibrary("c++"),
            ]
        ),
    ]
)
