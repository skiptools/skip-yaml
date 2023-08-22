// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "skip-yaml",
    defaultLocalization: "en",
    platforms: [.iOS(.v16), .macOS(.v13), .tvOS(.v16), .watchOS(.v9), .macCatalyst(.v16)],
    products: [
    .library(name: "SkipYAML", targets: ["SkipYAML"]),
    .library(name: "SkipYAMLKt", targets: ["SkipYAMLKt"]),
    ],
    dependencies: [
        .package(url: "https://source.skip.tools/skip.git", from: "0.0.0"),
        .package(url: "https://source.skip.tools/skip-unit.git", from: "0.0.0"),
        .package(url: "https://source.skip.tools/skip-lib.git", from: "0.0.0"),
        .package(url: "https://source.skip.tools/skip-foundation.git", from: "0.0.0"),
    ],
    targets: [
    .target(name: "SkipYAML", plugins: [.plugin(name: "preflight", package: "skip")]),
    .target(name: "SkipYAMLKt", dependencies: [
        "SkipYAML",
        .product(name: "SkipUnitKt", package: "skip-unit"),
        .product(name: "SkipLibKt", package: "skip-lib"),
        .product(name: "SkipFoundationKt", package: "skip-foundation"),
    ], resources: [.process("Skip")], plugins: [.plugin(name: "transpile", package: "skip")]),
    .testTarget(name: "SkipYAMLTests", dependencies: [
        "SkipYAML"
    ], plugins: [.plugin(name: "preflight", package: "skip")]),
    .testTarget(name: "SkipYAMLKtTests", dependencies: [
        "SkipYAMLKt",
        .product(name: "SkipUnit", package: "skip-unit"),
    ], resources: [.process("Skip")], plugins: [.plugin(name: "transpile", package: "skip")]),
    ]
)
