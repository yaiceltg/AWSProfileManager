import Foundation

/// Loads the config and resolves each group's live token status in one shot,
/// so the presentation layer receives a ready-to-render snapshot.
public struct LoadProfileGroups: Sendable {
    private let repository: ProfileRepository
    private let tokenReader: SSOTokenReader

    public init(repository: ProfileRepository, tokenReader: SSOTokenReader) {
        self.repository = repository
        self.tokenReader = tokenReader
    }

    public struct Result: Equatable, Sendable {
        public let groups: [ResolvedGroup]
        public let defaultProfileName: String?
    }

    public struct ResolvedGroup: Equatable, Identifiable, Sendable {
        public var id: String { group.id }
        public let group: ProfileGroup
        public let tokenStatus: TokenStatus
    }

    /// - Parameter now: injected clock, so token classification is deterministic
    ///   in tests.
    public func callAsFunction(now: Date) throws -> Result {
        let config = try repository.load()
        let resolved = config.groupedBySession().map { group in
            let status: TokenStatus = group.session.map {
                tokenReader.status(for: $0, now: now)
            } ?? .unknown
            return ResolvedGroup(group: group, tokenStatus: status)
        }
        return Result(groups: resolved, defaultProfileName: config.defaultProfileName)
    }
}
