import Foundation

/// Creates or updates a profile across config, sso-session, and credentials.
public struct SaveProfile: Sendable {
    private let repository: ProfileRepository

    public init(repository: ProfileRepository) {
        self.repository = repository
    }

    public func callAsFunction(_ profile: Profile) throws {
        try repository.saveProfile(profile)
    }
}
