import Foundation

/// Builds a federated AWS console sign-in URL from temporary credentials.
public protocol ConsoleSignInService: Sendable {
    /// Exchanges the credentials for a sign-in token and returns a console
    /// login URL. Opening it signs the browser into the console.
    func signInURL(for credentials: TemporaryCredentials, region: String?) async throws -> URL
}

public enum ConsoleSignInError: Error, Equatable, Sendable {
    /// Federation needs temporary credentials (a session token); static IAM
    /// user keys can't be used for console sign-in.
    case requiresTemporaryCredentials
    /// The federation endpoint didn't return a usable sign-in token.
    case federationFailed
}
