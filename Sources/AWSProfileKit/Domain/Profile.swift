import Foundation

/// A single AWS profile, presented as the aggregate the user edits: config
/// fields, the resolved SSO session (start URL + region), and static
/// credentials. The repository splits these back across `config` and
/// `credentials` on save.
public struct Profile: Equatable, Identifiable, Sendable {
    public var id: String { name }

    /// Profile name without the `profile ` prefix (e.g. `fantaz-dev`).
    public let name: String

    // MARK: config → [profile X]
    public let ssoSessionName: String?
    public let accountId: String?
    public let roleName: String?
    public let region: String?

    // MARK: config → [sso-session Y] (resolved for display/edit)
    public let ssoStartURL: String?
    public let ssoRegion: String?

    // MARK: credentials → [X]
    public let accessKeyId: String?
    public let secretAccessKey: String?
    public let sessionToken: String?

    /// Free-form `[profile X]` keys not modeled explicitly, preserved on write.
    public let extraSettings: [String: String]

    public init(
        name: String,
        ssoSessionName: String? = nil,
        accountId: String? = nil,
        roleName: String? = nil,
        region: String? = nil,
        ssoStartURL: String? = nil,
        ssoRegion: String? = nil,
        accessKeyId: String? = nil,
        secretAccessKey: String? = nil,
        sessionToken: String? = nil,
        extraSettings: [String: String] = [:]
    ) {
        self.name = name
        self.ssoSessionName = ssoSessionName
        self.accountId = accountId
        self.roleName = roleName
        self.region = region
        self.ssoStartURL = ssoStartURL
        self.ssoRegion = ssoRegion
        self.accessKeyId = accessKeyId
        self.secretAccessKey = secretAccessKey
        self.sessionToken = sessionToken
        self.extraSettings = extraSettings
    }

    /// True when this profile authenticates through IAM Identity Center.
    public var isSSO: Bool { ssoSessionName != nil || ssoStartURL != nil }

    /// True when this profile carries static credentials.
    public var hasStaticCredentials: Bool {
        accessKeyId != nil || secretAccessKey != nil
    }

    /// Returns a copy with the SSO session details filled in.
    public func resolvingSession(startURL: String?, region: String?) -> Profile {
        Profile(
            name: name,
            ssoSessionName: ssoSessionName,
            accountId: accountId,
            roleName: roleName,
            region: self.region,
            ssoStartURL: startURL,
            ssoRegion: region,
            accessKeyId: accessKeyId,
            secretAccessKey: secretAccessKey,
            sessionToken: sessionToken,
            extraSettings: extraSettings
        )
    }

    /// Returns a copy with static credentials filled in.
    public func withCredentials(
        accessKeyId: String?,
        secretAccessKey: String?,
        sessionToken: String?
    ) -> Profile {
        Profile(
            name: name,
            ssoSessionName: ssoSessionName,
            accountId: accountId,
            roleName: roleName,
            region: region,
            ssoStartURL: ssoStartURL,
            ssoRegion: ssoRegion,
            accessKeyId: accessKeyId,
            secretAccessKey: secretAccessKey,
            sessionToken: sessionToken,
            extraSettings: extraSettings
        )
    }
}
