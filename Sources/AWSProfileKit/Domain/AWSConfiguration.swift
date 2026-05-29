import Foundation

/// Aggregate root: the full parsed view of `~/.aws/config`.
///
/// Holds every profile, every sso-session, and which profile (if any) currently
/// occupies the `[default]` block. Grouping logic lives here so the application
/// layer stays thin.
public struct AWSConfiguration: Equatable, Sendable {
    public let profiles: [Profile]
    public let ssoSessions: [SSOSession]

    /// The profile whose settings the `[default]` block currently mirrors,
    /// matched by comparing SSO identity (session + account + role). Nil when
    /// `[default]` is empty, region-only, or doesn't match any named profile.
    public let defaultProfileName: String?

    public init(
        profiles: [Profile],
        ssoSessions: [SSOSession],
        defaultProfileName: String? = nil
    ) {
        self.profiles = profiles
        self.ssoSessions = ssoSessions
        self.defaultProfileName = defaultProfileName
    }

    public func session(named name: String) -> SSOSession? {
        ssoSessions.first { $0.name == name }
    }

    public func profile(named name: String) -> Profile? {
        profiles.first { $0.name == name }
    }

    /// Profiles grouped by their `sso-session`. Profiles without a session
    /// (e.g. static credentials) land in a trailing group with a nil session.
    public func groupedBySession() -> [ProfileGroup] {
        var orderedSessionNames: [String?] = []
        var buckets: [String?: [Profile]] = [:]

        for profile in profiles {
            let key = profile.ssoSessionName
            if buckets[key] == nil {
                buckets[key] = []
                orderedSessionNames.append(key)
            }
            buckets[key]?.append(profile)
        }

        return orderedSessionNames.map { key in
            ProfileGroup(
                session: key.flatMap { session(named: $0) },
                sessionName: key,
                profiles: buckets[key] ?? []
            )
        }
    }
}
