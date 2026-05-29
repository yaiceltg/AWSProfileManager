import Foundation

/// What the SSO login surfaces to the UI during `--no-browser` flow: the
/// authorization URL to open and the verification code to confirm in the
/// browser. `rawOutput` is the full captured CLI text — a safety net so the
/// user can always copy the code by hand if parsing misses the exact format.
public struct LoginPrompt: Equatable, Sendable {
    public let verificationURL: String?
    public let userCode: String?
    public let rawOutput: String

    public init(verificationURL: String?, userCode: String?, rawOutput: String) {
        self.verificationURL = verificationURL
        self.userCode = userCode
        self.rawOutput = rawOutput
    }
}
