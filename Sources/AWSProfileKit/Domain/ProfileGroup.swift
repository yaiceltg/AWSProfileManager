import Foundation

/// Profiles that share one `sso-session`, presented together so the UI can
/// offer a single login/refresh action for the whole group.
public struct ProfileGroup: Equatable, Identifiable, Sendable {
    public var id: String { sessionName ?? "__no_session__" }

    /// The resolved sso-session block, when one exists in config.
    public let session: SSOSession?
    /// The session name as referenced by the profiles (may exist even if the
    /// `[sso-session]` block itself is missing — a misconfiguration worth showing).
    public let sessionName: String?
    public let profiles: [Profile]

    public init(session: SSOSession?, sessionName: String?, profiles: [Profile]) {
        self.session = session
        self.sessionName = sessionName
        self.profiles = profiles
    }

    public var isSSOGroup: Bool { sessionName != nil }
}
