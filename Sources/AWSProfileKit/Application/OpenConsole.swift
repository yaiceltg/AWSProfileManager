import Foundation

/// Produces a federated AWS console sign-in URL for a profile: resolve its
/// credentials, then exchange them for a console login URL.
public struct OpenConsole: Sendable {
    private let runner: AWSCommandRunner
    private let federation: ConsoleSignInService

    public init(runner: AWSCommandRunner, federation: ConsoleSignInService) {
        self.runner = runner
        self.federation = federation
    }

    public func callAsFunction(profileNamed name: String, region: String?) async throws -> URL {
        let credentials = try await runner.exportCredentials(profileNamed: name)
        return try await federation.signInURL(for: credentials, region: region)
    }
}
