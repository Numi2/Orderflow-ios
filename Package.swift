// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "FinancialDashboard",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "FinancialDashboard", targets: ["FinancialDashboard"])
    ],
    targets: [
        .target(
            name: "FinancialDashboard",
            path: ".",
            exclude: [
                "Tests",
                "FinancialDashboardWidget",
                "FinancialDashboard",
                ".git",
                "Models/FinancialData.xcdatamodeld"
            ],
            sources: ["Models", "Networking", "Utils", "ViewModels", "Views"]
        ),
        .testTarget(
            name: "FinancialDashboardTests",
            dependencies: ["FinancialDashboard"],
            path: "Tests"
        )
    ]
)
