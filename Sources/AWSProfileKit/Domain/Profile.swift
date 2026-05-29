import Foundation

/// A single AWS profile as declared in `~/.aws/config`.
///
/// In the modern SSO format (AWS CLI ≥ 2.9), a profile references a shared
/// `sso-session` by name rather than embedding the start URL inline.
public struct Profile: Equatable, Identifiable, Sendable {
    public var id: String { name }

    /// Profile name without the `profile ` prefix (e.g. `fantaz-dev`).
    public let name: String
    public let ssoSessionName: String?
    public let accountId: String?
    public let roleName: String?
    public let region: String?

    /// Free-form key/value pairs not modeled explicitly, preserved on write.
    public let extraSettings: [String: String]

    public init(
        name: String,
        ssoSessionName: String? = nil,
        accountId: String? = nil,
        roleName: String? = nil,
        region: String? = nil,
        extraSettings: [String: String] = [:]
    ) {
        self.name = name
        self.ssoSessionName = ssoSessionName
        self.accountId = accountId
        self.roleName = roleName
        self.region = region
        self.extraSettings = extraSettings
    }

    /// True when this profile authenticates through IAM Identity Center.
    public var isSSO: Bool { ssoSessionName != nil }
}
