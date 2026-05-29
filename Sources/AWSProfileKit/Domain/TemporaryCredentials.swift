import Foundation

/// Resolved credentials for a profile, as produced by
/// `aws configure export-credentials`. Federated console sign-in needs the
/// `sessionToken` (i.e. temporary credentials, e.g. from SSO/assumed roles).
public struct TemporaryCredentials: Equatable, Sendable {
    public let accessKeyId: String
    public let secretAccessKey: String
    public let sessionToken: String?

    public init(accessKeyId: String, secretAccessKey: String, sessionToken: String?) {
        self.accessKeyId = accessKeyId
        self.secretAccessKey = secretAccessKey
        self.sessionToken = sessionToken
    }

    /// Parses `aws configure export-credentials --format process` output.
    public init?(json: String) {
        struct Raw: Decodable {
            let AccessKeyId: String
            let SecretAccessKey: String
            let SessionToken: String?
        }
        guard
            let data = json.data(using: .utf8),
            let raw = try? JSONDecoder().decode(Raw.self, from: data)
        else { return nil }
        self.init(
            accessKeyId: raw.AccessKeyId,
            secretAccessKey: raw.SecretAccessKey,
            sessionToken: raw.SessionToken
        )
    }
}
