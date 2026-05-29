import Foundation

/// Liveness of a cached SSO access token, derived from its `expiresAt`.
///
/// Derived purely from the cache's expiry timestamp — the access token itself
/// is never read. `expiringSoon` exists so the UI can warn before a hard expiry.
public enum TokenStatus: Equatable, Sendable {
    /// Valid with comfortable headroom. `remaining` is time until expiry.
    case valid(remaining: TimeInterval)
    /// Valid but within the warning window. `remaining` is time until expiry.
    case expiringSoon(remaining: TimeInterval)
    /// Past `expiresAt`, or no cache entry found for the session.
    case expired
    /// No cache file or unparseable expiry — login state unknown.
    case unknown

    /// Window (seconds) before expiry during which we surface a warning.
    public static let warningWindow: TimeInterval = 15 * 60

    /// Classifies a token given its expiry and the current instant.
    public static func from(expiresAt: Date?, now: Date) -> TokenStatus {
        guard let expiresAt else { return .unknown }
        let remaining = expiresAt.timeIntervalSince(now)
        if remaining <= 0 { return .expired }
        if remaining <= warningWindow { return .expiringSoon(remaining: remaining) }
        return .valid(remaining: remaining)
    }

    public var isActive: Bool {
        switch self {
        case .valid, .expiringSoon: return true
        case .expired, .unknown: return false
        }
    }
}
