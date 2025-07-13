// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NestCore",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "NestCore",
            targets: ["NestCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.13.3"),
        .package(url: "https://github.com/gaaurav/sqlcipher.git", branch: "master"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "NestCore",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "SQLCipher", package: "sqlcipher"),
            ],
            swiftSettings: [
                .define("SQLITE_ENABLE_FTS5"),
                .define("SQLITE_ENABLE_VECTOR"),
            ]
        ),
        .testTarget(
            name: "NestCoreTests",
            dependencies: ["NestCore"]
        ),
    ]
)
