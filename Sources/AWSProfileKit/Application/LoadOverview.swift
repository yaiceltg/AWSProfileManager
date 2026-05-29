import Foundation

/// Loads everything the UI needs in one pass: prefix-grouped profiles, token
/// status per sso-session, drift status per profile, and the current default.
public struct LoadOverview: Sendable {
    private let repository: ProfileRepository
    private let tokenReader: SSOTokenReader
    private let sync: SyncManifest

    public init(repository: ProfileRepository, tokenReader: SSOTokenReader, sync: SyncManifest) {
        self.repository = repository
        self.tokenReader = tokenReader
        self.sync = sync
    }

    public struct Result: Sendable {
        public let profiles: [Profile]
        public let groups: [ProfileDisplayGroup]
        public let tokenStatusBySession: [String: TokenStatus]
        public let driftByName: [String: DriftStatus]
        public let defaultProfileName: String?
    }

    public func callAsFunction(now: Date) throws -> Result {
        let config = try repository.load()

        var statusBySession: [String: TokenStatus] = [:]
        for session in config.ssoSessions {
            statusBySession[session.name] = tokenReader.status(for: session, now: now)
        }

        return Result(
            profiles: config.profiles,
            groups: ProfileGrouping.grouped(config.profiles, assignments: sync.groups()),
            tokenStatusBySession: statusBySession,
            driftByName: sync.diff(live: config.profiles),
            defaultProfileName: config.defaultProfileName
        )
    }
}
