import Foundation

/// The result of `aws sts get-caller-identity`, enriched with fields derived
/// from the ARN. This is the real identity AWS sees for the profile's
/// credentials — a live check that the session works and who you are.
public struct CallerIdentity: Equatable, Sendable {
    public let account: String
    public let arn: String
    public let userId: String

    /// ARN partition: `aws`, `aws-cn`, `aws-us-gov`.
    public let partition: String?
    /// First resource segment: `assumed-role`, `user`, `root`, `federated-user`…
    public let identityType: String?
    /// Role name when this is an assumed role.
    public let roleName: String?
    /// Session name when this is an assumed role.
    public let sessionName: String?

    public init(account: String, arn: String, userId: String) {
        self.account = account
        self.arn = arn
        self.userId = userId

        // arn:partition:service:region:account:resource(/...)
        let fields = arn.components(separatedBy: ":")
        self.partition = fields.count > 1 && !fields[1].isEmpty ? fields[1] : nil

        let resource = fields.count > 5 ? fields[5...].joined(separator: ":") : ""
        let segments = resource.split(separator: "/").map(String.init)
        self.identityType = segments.first

        if segments.first == "assumed-role" {
            self.roleName = segments.count > 1 ? segments[1] : nil
            self.sessionName = segments.count > 2 ? segments[2...].joined(separator: "/") : nil
        } else {
            self.roleName = nil
            self.sessionName = nil
        }
    }

    /// Parse the CLI's `--output json` payload (keys are PascalCase).
    public init?(json: String) {
        struct Raw: Decodable { let UserId: String; let Account: String; let Arn: String }
        guard
            let data = json.data(using: .utf8),
            let raw = try? JSONDecoder().decode(Raw.self, from: data)
        else { return nil }
        self.init(account: raw.Account, arn: raw.Arn, userId: raw.UserId)
    }
}
