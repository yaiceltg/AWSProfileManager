// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AWSProfileManager",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        // Executable: SwiftUI app entry + presentation wiring.
        .executableTarget(
            name: "AWSProfileManager",
            dependencies: ["AWSProfileKit"],
            path: "Sources/AWSProfileManager",
            resources: [.copy("Resources/AppIcon.icns")]
        ),
        // Library: domain + application + infrastructure (framework-agnostic, fully testable).
        .target(
            name: "AWSProfileKit",
            path: "Sources/AWSProfileKit"
        ),
        .testTarget(
            name: "AWSProfileKitTests",
            dependencies: ["AWSProfileKit"],
            path: "Tests/AWSProfileKitTests"
        )
    ]
)
