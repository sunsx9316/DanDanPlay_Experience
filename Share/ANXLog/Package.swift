// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ANXLog",
    platforms: [.iOS(.v12), .macOS(.v10_13), .tvOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ANXLog",
            type: .dynamic,
            targets: ["ANXLog", "ANXLog_Objc"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .binaryTarget(name: "mars", path: "ANXLog/Resources/mars.xcframework"),
        .target(
            name: "ANXLog_Objc",
            dependencies: [
                .target(name: "mars", condition: .when(platforms: [.iOS, .macOS]))
            ],
            path: "ANXLog/Classes/Objc",
            publicHeadersPath: "include",
            linkerSettings: [.linkedFramework("SystemConfiguration"),
                             .linkedLibrary("resolv.9"), .linkedLibrary("z")]),
        .target(
            name: "ANXLog",
            dependencies: ["ANXLog_Objc"],
            path: "ANXLog/Classes/Swift",
            swiftSettings: [.define("SPM_MODE")]),
    ]
)
