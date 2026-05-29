import Foundation

/// Removes a profile from config and credentials.
public struct DeleteProfile: Sendable {
    private let repository: ProfileRepository

    public init(repository: ProfileRepository) {
        self.repository = repository
    }

    public func callAsFunction(named name: String) throws {
        try repository.deleteProfile(named: name)
    }
}
