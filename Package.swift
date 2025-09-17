// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "KajimiruKit",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "KajimiruKit",
            targets: ["KajimiruKit"]
        ),
    ],
    targets: [
        .target(
            name: "KajimiruKit"
        ),
        .testTarget(
            name: "KajimiruKitTests",
            dependencies: ["KajimiruKit"]
        ),
    ]
)
