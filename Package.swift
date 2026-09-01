// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "KeyBloom",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "KeyBloom", targets: ["KeyBloom"])
    ],
    targets: [
        .executableTarget(
            name: "KeyBloom",
            path: "Sources/KeyBloom"
        )
    ]
)
