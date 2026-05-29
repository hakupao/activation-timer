// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "StokerMenuBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "StokerMenuBar", targets: ["StokerMenuBar"])
    ],
    targets: [
        .executableTarget(
            name: "StokerMenuBar",
            dependencies: ["StokerCore"],
            linkerSettings: [
                .linkedFramework("ServiceManagement")
            ]
        ),
        .target(name: "StokerCore")
    ]
)
