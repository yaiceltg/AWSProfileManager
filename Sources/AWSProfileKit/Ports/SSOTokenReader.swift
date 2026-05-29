import Foundation

/// Reads the expiry of a cached SSO token without ever touching the token value.
///
/// The AWS CLI caches tokens in `~/.aws/sso/cache/*.json`. Each file is matched
/// to a session by its `startUrl`/`region`; we read only `expiresAt`.
public protocol SSOTokenReader: Sendable {
    /// The expiry timestamp of the cached token for the given session, or nil
    /// when no matching cache entry exists.
    func expiresAt(for session: SSOSession) throws -> Date?
}

public extension SSOTokenReader {
    /// Convenience: classify the session's token relative to `now`.
    func status(for session: SSOSession, now: Date) -> TokenStatus {
        let expiry = try? expiresAt(for: session)
        return TokenStatus.from(expiresAt: expiry, now: now)
    }
}
