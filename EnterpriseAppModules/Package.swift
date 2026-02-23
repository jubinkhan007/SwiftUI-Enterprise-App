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
        .library(name: "Network", targets: ["Network"]),
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Data", targets: ["Data"]),
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
            name: "Network",
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
            name: "Data",
            dependencies: [
                "Core",
                "Domain",
                "Network",
                .product(name: "SharedModels", package: "SharedModels"),
            ]
        ),
        .target(
            name: "DesignSystem",
            dependencies: ["Core"]
        ),
        .target(
            name: "FeatureAuth",
            dependencies: ["Core", "Domain", "DesignSystem"]
        ),
        .target(
            name: "FeatureDashboard",
            dependencies: ["Core", "Domain", "DesignSystem"]
        ),
        .testTarget(
            name: "EnterpriseAppModulesTests",
            dependencies: ["Core", "Network", "Domain", "Data", "DesignSystem", "FeatureAuth", "FeatureDashboard"]
        ),
    ]
)
