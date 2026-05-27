// swift-tools-version: 6.1

import PackageDescription

let tvBinary = Target.binaryTarget(name: "TVVLCKit-all", path: "Sources/TVVLCKitSPM/TVVLCKit.xcframework")

let package = Package(
    name: "tvvlckit-spm",
    platforms: [.tvOS(.v12)],
    products: [
        .library(
            name: "TVVLCKitSPM",
            targets: ["TVVLCKitSPM"]),
    ],
    dependencies: [],
    targets: [
        tvBinary,
        .target(
            name: "TVVLCKitSPM",
            dependencies: [
                .target(name: "TVVLCKit-all")
            ],
            linkerSettings: [
                .linkedFramework("CoreText", .when(platforms: [.tvOS])),
                .linkedFramework("AVFoundation", .when(platforms: [.tvOS])),
                .linkedFramework("AudioToolbox", .when(platforms: [.tvOS])),
                .linkedFramework("OpenGLES", .when(platforms: [.tvOS])),
                .linkedFramework("VideoToolbox", .when(platforms: [.tvOS])),
                .linkedFramework("CoreMedia", .when(platforms: [.tvOS])),
                .linkedLibrary("c++", .when(platforms: [.tvOS])),
                .linkedLibrary("xml2", .when(platforms: [.tvOS])),
                .linkedLibrary("z", .when(platforms: [.tvOS])),
                .linkedLibrary("bz2", .when(platforms: [.tvOS])),
                .linkedLibrary("iconv")
            ]),
    ]
)
