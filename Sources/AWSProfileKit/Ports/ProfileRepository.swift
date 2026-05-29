import Foundation

/// Reads and mutates the AWS config and credentials files. Implementations own
/// the on-disk format; callers work only with the domain aggregate.
public protocol ProfileRepository: Sendable {
    /// Parse `~/.aws/config` and `~/.aws/credentials` into the domain aggregate,
    /// with each profile enriched with its resolved SSO session and credentials.
    func load() throws -> AWSConfiguration

    /// Rewrite the `[default]` block to mirror the named profile's settings.
    /// Backs up config first and writes atomically.
    /// - Returns: the path of the backup that was created.
    @discardableResult
    func setDefault(profileNamed name: String) throws -> URL

    /// Create or update a profile across config (+ deduped sso-session) and
    /// credentials. Backs up both files before writing; credentials and their
    /// backups are written with `0600` permissions.
    func saveProfile(_ profile: Profile) throws

    /// Remove a profile from config and credentials.
    func deleteProfile(named name: String) throws
}
