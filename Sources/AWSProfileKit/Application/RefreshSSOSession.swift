import Foundation

/// Triggers the SSO browser login for a session, refreshing the token shared by
/// every profile under it.
public struct RefreshSSOSession: Sendable {
    private let runner: AWSCommandRunner

    public init(runner: AWSCommandRunner) {
        self.runner = runner
    }

    /// - Parameter browser: the browser to open the login in; nil uses the
    ///   system default.
    public func callAsFunction(sessionNamed name: String, browser: BrowserChoice?) async throws {
        try await runner.login(ssoSessionNamed: name, browser: browser)
    }
}
