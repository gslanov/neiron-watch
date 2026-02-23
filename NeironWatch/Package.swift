// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NeironWatch",
    platforms: [
        .watchOS(.v10),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "NeironWatch",
            targets: ["NeironWatch"]
        )
    ],
    targets: [
        .target(
            name: "NeironWatch",
            path: "NeironWatch"
        )
    ]
)
