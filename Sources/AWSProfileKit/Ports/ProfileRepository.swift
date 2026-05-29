import Foundation

/// Reads and mutates the AWS config files. Implementations own the on-disk
/// format; callers work only with the domain aggregate.
public protocol ProfileRepository: Sendable {
    /// Parse `~/.aws/config` into the domain aggregate.
    func load() throws -> AWSConfiguration

    /// Rewrite the `[default]` block to mirror the named profile's settings.
    ///
    /// Implementations MUST back up the existing config before writing, and the
    /// write MUST be atomic (no torn file if the process dies mid-write).
    /// - Returns: the path of the backup that was created.
    @discardableResult
    func setDefault(profileNamed name: String) throws -> URL
}
