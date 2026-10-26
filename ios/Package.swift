// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MomentoSDUI",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MomentoSDUI", targets: ["MomentoSDUI"]),
    ],
    targets: [
        .target(name: "MomentoSDUI"),
        .testTarget(name: "MomentoSDUITests", dependencies: ["MomentoSDUI"]),
    ]
)
