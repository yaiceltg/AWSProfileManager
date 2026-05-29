import Foundation

/// Verifies a profile by asking AWS who its credentials authenticate as.
public struct GetCallerIdentity: Sendable {
    private let runner: AWSCommandRunner

    public init(runner: AWSCommandRunner) {
        self.runner = runner
    }

    public func callAsFunction(profileNamed name: String) async throws -> CallerIdentity {
        try await runner.callerIdentity(profileNamed: name)
    }
}
