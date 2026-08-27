// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TrackpadWizard",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "TrackpadWizard", targets: ["TrackpadWizard"])
    ],
    targets: [
        .executableTarget(
            name: "TrackpadWizard",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("IOKit")
            ]
        ),
        .testTarget(
            name: "TrackpadWizardTests",
            dependencies: ["TrackpadWizard"]
        )
    ]
)
