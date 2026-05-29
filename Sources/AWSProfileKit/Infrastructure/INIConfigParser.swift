import Foundation

/// Maps a generic `INIDocument` into the AWS domain aggregate.
public struct INIConfigParser: Sendable {
    public init() {}

    // Keys we model explicitly; everything else is preserved as extraSettings.
    private static let profileKnownKeys: Set<String> = [
        "sso_session", "sso_account_id", "sso_role_name", "region"
    ]

    public func parse(_ text: String) -> AWSConfiguration {
        let document = INIDocument(text)

        var profiles: [Profile] = []
        var sessions: [SSOSession] = []
        var defaultPairs: [INIDocument.KeyValue] = []

        for section in document.sections {
            switch section.type {
            case "default":
                defaultPairs = section.pairs
            case "profile":
                guard let name = section.name else { continue }
                profiles.append(makeProfile(name: name, pairs: section.pairs))
            case "sso-session":
                guard let name = section.name else { continue }
                sessions.append(makeSession(name: name, pairs: section.pairs))
            default:
                continue
            }
        }

        let defaultName = matchDefault(pairs: defaultPairs, against: profiles)
        return AWSConfiguration(
            profiles: profiles,
            ssoSessions: sessions,
            defaultProfileName: defaultName
        )
    }

    private func makeProfile(name: String, pairs: [INIDocument.KeyValue]) -> Profile {
        var extras: [String: String] = [:]
        for pair in pairs where !Self.profileKnownKeys.contains(pair.key) {
            extras[pair.key] = pair.value
        }
        return Profile(
            name: name,
            ssoSessionName: pairs.value(for: "sso_session"),
            accountId: pairs.value(for: "sso_account_id"),
            roleName: pairs.value(for: "sso_role_name"),
            region: pairs.value(for: "region"),
            extraSettings: extras
        )
    }

    private func makeSession(name: String, pairs: [INIDocument.KeyValue]) -> SSOSession {
        SSOSession(
            name: name,
            startURL: pairs.value(for: "sso_start_url"),
            region: pairs.value(for: "sso_region"),
            registrationScopes: pairs.value(for: "sso_registration_scopes")
        )
    }

    /// The `[default]` block mirrors a profile when their SSO identity matches
    /// (session + account + role). A region-only default matches nothing.
    private func matchDefault(
        pairs: [INIDocument.KeyValue],
        against profiles: [Profile]
    ) -> String? {
        let session = pairs.value(for: "sso_session")
        let account = pairs.value(for: "sso_account_id")
        let role = pairs.value(for: "sso_role_name")
        guard session != nil || account != nil || role != nil else { return nil }
        return profiles.first {
            $0.ssoSessionName == session
                && $0.accountId == account
                && $0.roleName == role
        }?.name
    }
}

private extension Array where Element == INIDocument.KeyValue {
    func value(for key: String) -> String? {
        first { $0.key == key }?.value
    }
}
