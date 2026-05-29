import Foundation

/// Filesystem locations and binary resolution for the AWS CLI ecosystem.
///
/// A GUI app does not inherit the shell `PATH`, so the `aws` binary is resolved
/// against known install locations rather than relying on the environment.
public struct AWSPaths: Sendable {
    public let configFile: URL
    public let credentialsFile: URL
    public let ssoCacheDirectory: URL

    public init(homeDirectory: URL) {
        let awsDir = homeDirectory.appendingPathComponent(".aws", isDirectory: true)
        self.configFile = awsDir.appendingPathComponent("config", isDirectory: false)
        self.credentialsFile = awsDir.appendingPathComponent("credentials", isDirectory: false)
        self.ssoCacheDirectory = awsDir
            .appendingPathComponent("sso", isDirectory: true)
            .appendingPathComponent("cache", isDirectory: true)
    }

    public static var `default`: AWSPaths {
        AWSPaths(homeDirectory: FileManager.default.homeDirectoryForCurrentUser)
    }

    /// Candidate locations for the `aws` binary, in priority order. Honors an
    /// explicit override via `AWS_CLI_PATH` for non-standard installs.
    public static var awsBinaryCandidates: [String] {
        var candidates: [String] = []
        if let override = ProcessInfo.processInfo.environment["AWS_CLI_PATH"], !override.isEmpty {
            candidates.append(override)
        }
        candidates.append(contentsOf: [
            "/usr/local/bin/aws",   // Intel Homebrew / official pkg
            "/opt/homebrew/bin/aws" // Apple Silicon Homebrew
        ])
        return candidates
    }

    /// First existing `aws` binary, or nil if none is installed where expected.
    public static func resolveAWSBinary(
        fileManager: FileManager = .default
    ) -> String? {
        awsBinaryCandidates.first { fileManager.isExecutableFile(atPath: $0) }
    }
}
