import Foundation

/// Launches the AWS CLI. The login always runs with `--no-browser` so the
/// verification URL and code can be surfaced to the user; the runner opens the
/// URL in the chosen (or system default) browser as a convenience.
public protocol AWSCommandRunner: Sendable {
    /// Run `aws sso login --profile <name> --no-browser`.
    ///
    /// - Parameters:
    ///   - browser: opens the captured URL in this browser; nil = system default.
    ///   - onPrompt: called (off the main actor) when the verification URL/code
    ///     are first detected, so the UI can display the copyable code.
    /// - Throws: `AWSCommandError` on a non-zero exit or a missing binary.
    func login(
        profileNamed name: String,
        browser: BrowserChoice?,
        onPrompt: @escaping @Sendable (LoginPrompt) -> Void
    ) async throws

    /// Run `aws sts get-caller-identity --profile <name>`: a live check of who
    /// the profile's credentials authenticate as.
    /// - Throws: `AWSCommandError` if not authenticated or the binary is missing.
    func callerIdentity(profileNamed name: String) async throws -> CallerIdentity

    /// Run `aws configure export-credentials --profile <name>` to resolve the
    /// profile's current credentials (for federated console sign-in).
    func exportCredentials(profileNamed name: String) async throws -> TemporaryCredentials
}

public enum AWSCommandError: Error, Equatable, Sendable {
    /// The `aws` binary could not be located on disk.
    case binaryNotFound
    /// The CLI exited non-zero. Carries the exit code and captured output.
    case nonZeroExit(code: Int32, stderr: String)
}
