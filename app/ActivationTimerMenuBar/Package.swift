// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ActivationTimerMenuBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ActivationTimerMenuBar", targets: ["ActivationTimerMenuBar"])
    ],
    targets: [
        .executableTarget(
            name: "ActivationTimerMenuBar",
            dependencies: ["ActivationTimerCore"],
            linkerSettings: [
                .linkedFramework("ServiceManagement")
            ]
        ),
        .target(name: "ActivationTimerCore")
    ]
)
