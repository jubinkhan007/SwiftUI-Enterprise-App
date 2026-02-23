// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EnterpriseAppModules",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "Core", targets: ["Core"]),
        .library(name: "Network", targets: ["Network"]),
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Data", targets: ["Data"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "FeatureDashboard", targets: ["FeatureDashboard"]),
        .library(name: "FeatureAuth", targets: ["FeatureAuth"]),
    ],
    targets: [
        .target(name: "Core", path: "Packages/Core/Sources/Core"),
        .target(name: "Network", dependencies: ["Core"], path: "Packages/Network/Sources/Network"),
        .target(name: "Domain", path: "Packages/Domain/Sources/Domain"),
        .target(name: "Data", dependencies: ["Domain", "Network"], path: "Packages/Data/Sources/Data"),
        .target(name: "DesignSystem", dependencies: ["Core"], path: "Packages/DesignSystem/Sources/DesignSystem"),
        .target(name: "FeatureDashboard", dependencies: ["Domain", "DesignSystem"], path: "Packages/FeatureDashboard/Sources/FeatureDashboard"),
        .target(name: "FeatureAuth", dependencies: ["Domain", "DesignSystem"], path: "Packages/FeatureAuth/Sources/FeatureAuth")
    ]
)
