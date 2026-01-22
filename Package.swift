// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NeverMiss",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "NeverMiss", targets: ["NeverMiss"])
    ],
    targets: [
        .executableTarget(
            name: "NeverMiss",
            path: "NeverMiss/Sources",
            exclude: ["Config.template.swift"],
            resources: [
                .process("../Info.plist")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Security"),
                .linkedFramework("AuthenticationServices"),
                .linkedFramework("ServiceManagement")
            ]
        )
    ]
)
