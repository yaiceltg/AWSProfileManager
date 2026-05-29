import Foundation

/// Promotes a profile to `[default]`, backing up the previous config first.
public struct SetDefaultProfile: Sendable {
    private let repository: ProfileRepository

    public init(repository: ProfileRepository) {
        self.repository = repository
    }

    /// - Returns: the URL of the backup created before the rewrite.
    @discardableResult
    public func callAsFunction(profileNamed name: String) throws -> URL {
        try repository.setDefault(profileNamed: name)
    }
}
