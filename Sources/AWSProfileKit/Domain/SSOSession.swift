import Foundation

/// An `[sso-session NAME]` block from `~/.aws/config`.
///
/// The SSO access token is cached per *session*, not per profile — so a single
/// `aws sso login --sso-session <name>` refreshes every profile that shares it.
public struct SSOSession: Equatable, Identifiable, Sendable {
    public var id: String { name }

    public let name: String
    public let startURL: String?
    public let region: String?
    public let registrationScopes: String?

    public init(
        name: String,
        startURL: String? = nil,
        region: String? = nil,
        registrationScopes: String? = nil
    ) {
        self.name = name
        self.startURL = startURL
        self.region = region
        self.registrationScopes = registrationScopes
    }
}
