import Foundation

/// A non-secret fingerprint of a profile, persisted in the app manifest to
/// detect drift against the live config.
///
/// Security: secret VALUES are never stored — only booleans recording whether
/// each credential field was present. That detects credentials being added or
/// removed without writing secrets to the (plaintext) manifest.
public struct ProfileSnapshot: Codable, Equatable, Sendable {
    public let name: String
    public let ssoSessionName: String?
    public let accountId: String?
    public let roleName: String?
    public let region: String?
    public let ssoStartURL: String?
    public let ssoRegion: String?
    public let hasAccessKey: Bool
    public let hasSecret: Bool
    public let hasSessionToken: Bool

    public init(from profile: Profile) {
        name = profile.name
        ssoSessionName = profile.ssoSessionName
        accountId = profile.accountId
        roleName = profile.roleName
        region = profile.region
        ssoStartURL = profile.ssoStartURL
        ssoRegion = profile.ssoRegion
        hasAccessKey = profile.accessKeyId?.isEmpty == false
        hasSecret = profile.secretAccessKey?.isEmpty == false
        hasSessionToken = profile.sessionToken?.isEmpty == false
    }
}

/// The app's record of profiles it manages.
///
/// `groups` maps a profile name to a user-assigned display group, kept separate
/// from the drift snapshots so reassigning a group never reads as a config edit.
public struct ProfileManifest: Codable, Equatable, Sendable {
    public var profiles: [ProfileSnapshot]
    /// Profile name → user-assigned display group.
    public var groups: [String: String]
    /// Profile name → user-assigned display name (shown instead of the key).
    public var displayNames: [String: String]

    public init(
        profiles: [ProfileSnapshot] = [],
        groups: [String: String] = [:],
        displayNames: [String: String] = [:]
    ) {
        self.profiles = profiles
        self.groups = groups
        self.displayNames = displayNames
    }

    public func snapshot(named name: String) -> ProfileSnapshot? {
        profiles.first { $0.name == name }
    }

    // Backward-compatible decoding: older manifests lacked groups/displayNames.
    private enum CodingKeys: String, CodingKey { case profiles, groups, displayNames }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profiles = try container.decodeIfPresent([ProfileSnapshot].self, forKey: .profiles) ?? []
        groups = try container.decodeIfPresent([String: String].self, forKey: .groups) ?? [:]
        displayNames = try container.decodeIfPresent([String: String].self, forKey: .displayNames) ?? [:]
    }
}

/// How a profile in the live config compares to what the app recorded.
public enum DriftStatus: Equatable, Sendable {
    /// Live matches the manifest and the profile is usable.
    case ok
    /// Tracked, but some field was changed outside the app.
    case modified
    /// Usable check failed (e.g. an SSO profile with no resolvable start URL).
    case broken(reason: String)
    /// In the manifest but no longer in the live config.
    case removed
    /// In the live config but never recorded by the app.
    case untracked
}
