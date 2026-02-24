// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EnterpriseAppModules",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "Core", targets: ["Core"]),
        .library(name: "AppNetwork", targets: ["AppNetwork"]),
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "AppData", targets: ["AppData"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "FeatureAuth", targets: ["FeatureAuth"]),
        .library(name: "FeatureDashboard", targets: ["FeatureDashboard"]),
    ],
    dependencies: [
        .package(path: "../SharedModels"),
    ],
    targets: [
        .target(
            name: "Core"
        ),
        .target(
            name: "AppNetwork",
            dependencies: [
                "Core",
                .product(name: "SharedModels", package: "SharedModels"),
            ]
        ),
        .target(
            name: "Domain",
            dependencies: [
                "Core",
                .product(name: "SharedModels", package: "SharedModels"),
            ]
        ),
        .target(
            name: "AppData",
            dependencies: [
                "Core",
                "Domain",
                "AppNetwork",
                .product(name: "SharedModels", package: "SharedModels"),
            ]
        ),
        .target(
            name: "DesignSystem",
            dependencies: ["Core"]
        ),
        .target(
            name: "FeatureAuth",
            dependencies: ["Core", "Domain", "AppData", "DesignSystem", "AppNetwork"]
        ),
        .target(
            name: "FeatureDashboard",
            dependencies: ["Core", "Domain", "DesignSystem"]
        ),
        .testTarget(
            name: "EnterpriseAppModulesTests",
            dependencies: ["Core", "AppNetwork", "Domain", "AppData", "DesignSystem", "FeatureAuth", "FeatureDashboard"]
        ),
    ]
)
