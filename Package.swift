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
        .executableTarget(
            name: "lilhomie",
            path: "lilhomie-cli"
        )
    ]
)
