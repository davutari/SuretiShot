// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SuretiShot",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SuretiShot", targets: ["SuretiShot"])
    ],
    targets: [
        .executableTarget(
            name: "SuretiShot",
            path: "SuretiShot",
            exclude: ["Info.plist", "SuretiShot.entitlements"],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
