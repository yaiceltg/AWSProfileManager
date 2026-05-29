import Foundation

/// Launches the AWS CLI. The app never handles credentials itself — it delegates
/// the entire SSO browser flow to `aws sso login`.
public protocol AWSCommandRunner: Sendable {
    /// Run the SSO login for a session.
    ///
    /// - Parameter browser: when nil, the CLI opens the system default browser
    ///   itself. When set, the CLI runs with `--no-browser` and the runner opens
    ///   the captured authorization URL in that browser via `open -a`.
    /// - Throws: `AWSCommandError` on a non-zero exit or a missing binary.
    func login(ssoSessionNamed name: String, browser: BrowserChoice?) async throws
}

public enum AWSCommandError: Error, Equatable, Sendable {
    /// The `aws` binary could not be located on disk.
    case binaryNotFound
    /// The CLI exited non-zero. Carries the exit code and captured stderr.
    case nonZeroExit(code: Int32, stderr: String)
}
