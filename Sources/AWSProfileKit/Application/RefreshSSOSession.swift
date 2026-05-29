import Foundation

/// Triggers the SSO login for a single profile, surfacing the verification
/// prompt and refreshing the token shared by its sso-session.
public struct RefreshSSOSession: Sendable {
    private let runner: AWSCommandRunner

    public init(runner: AWSCommandRunner) {
        self.runner = runner
    }

    /// - Parameters:
    ///   - browser: browser to open the login URL in; nil uses the system default.
    ///   - onPrompt: receives the URL/code when detected.
    public func callAsFunction(
        profileNamed name: String,
        browser: BrowserChoice?,
        onPrompt: @escaping @Sendable (LoginPrompt) -> Void
    ) async throws {
        try await runner.login(profileNamed: name, browser: browser, onPrompt: onPrompt)
    }
}
