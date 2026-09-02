// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Homie",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "lilhomie", targets: ["lilhomie"])
    ],
    targets: [
        .target(
            name: "DeviceNameMatching",
            path: "Homie/HomeKit",
            sources: ["DeviceNameMatcher.swift"]
        ),
        .executableTarget(
            name: "lilhomie",
            path: "lilhomie-cli"
        ),
        .testTarget(
            name: "DeviceNameMatchingTests",
            dependencies: ["DeviceNameMatching"],
            path: "Tests",
            sources: ["DeviceNameMatcherTests.swift"]
        )
    ]
)
