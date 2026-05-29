import Foundation

public enum RepositoryError: Error, Equatable, Sendable {
    case configFileNotFound(path: String)
    case profileNotFound(name: String)
}

/// `ProfileRepository` backed by the real `~/.aws/config` and `~/.aws/credentials`.
public struct FileProfileRepository: ProfileRepository {
    private let paths: AWSPaths
    private let parser: INIConfigParser
    private let credentialsParser: CredentialsParser
    private let now: @Sendable () -> Date

    private static let defaultScopes = "sso:account:access"

    public init(
        paths: AWSPaths = .default,
        parser: INIConfigParser = INIConfigParser(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.paths = paths
        self.parser = parser
        self.credentialsParser = CredentialsParser()
        self.now = now
    }

    // MARK: - Load

    public func load() throws -> AWSConfiguration {
        let configText = readIfPresent(paths.configFile)
        let base = parser.parse(configText ?? "")

        let credentials = credentialsParser.parse(readIfPresent(paths.credentialsFile) ?? "")

        let enriched = base.profiles.map { profile -> Profile in
            var result = profile
            if let sessionName = profile.ssoSessionName,
               let session = base.session(named: sessionName) {
                result = result.resolvingSession(startURL: session.startURL, region: session.region)
            }
            if let entry = credentials[profile.name] {
                result = result.withCredentials(
                    accessKeyId: entry.accessKeyId,
                    secretAccessKey: entry.secretAccessKey,
                    sessionToken: entry.sessionToken
                )
            }
            return result
        }

        return AWSConfiguration(
            profiles: enriched,
            ssoSessions: base.ssoSessions,
            defaultProfileName: base.defaultProfileName
        )
    }

    // MARK: - Set default

    @discardableResult
    public func setDefault(profileNamed name: String) throws -> URL {
        guard FileManager.default.fileExists(atPath: paths.configFile.path) else {
            throw RepositoryError.configFileNotFound(path: paths.configFile.path)
        }
        let text = try String(contentsOf: paths.configFile, encoding: .utf8)
        let document = INIDocument(text)

        guard let profile = document.section(type: "profile", name: name) else {
            throw RepositoryError.profileNotFound(name: name)
        }

        let backupURL = try writeBackup(of: text, basename: "config")
        let newText = INIEditor.upsert(
            header: "default",
            pairs: profile.pairs.map { ($0.key, $0.value) },
            in: text
        )
        try writeFile(newText, to: paths.configFile, secure: false)
        return backupURL
    }

    // MARK: - Save (upsert)

    public func saveProfile(_ profile: Profile) throws {
        var configText = readIfPresent(paths.configFile) ?? ""

        // 1. Resolve or create the sso-session, deduping by start URL.
        var sessionName: String?
        if let startURL = profile.ssoStartURL, !startURL.isEmpty {
            let existing = parser.parse(configText)
            if let match = existing.ssoSessions.first(where: { $0.startURL == startURL }) {
                sessionName = match.name
            } else {
                let name = uniqueSessionName(
                    base: prefix(of: profile.name),
                    existing: existing.ssoSessions.map(\.name)
                )
                sessionName = name
                configText = INIEditor.upsert(
                    header: "sso-session \(name)",
                    pairs: ssoSessionPairs(startURL: startURL, region: profile.ssoRegion),
                    in: configText
                )
            }
        }

        // 2. Upsert the [profile X] block.
        configText = INIEditor.upsert(
            header: "profile \(profile.name)",
            pairs: profilePairs(for: profile, sessionName: sessionName),
            in: configText
        )

        // 3. Persist config (with backup).
        if let original = readIfPresent(paths.configFile) {
            try writeBackup(of: original, basename: "config")
        }
        try writeFile(configText, to: paths.configFile, secure: false)

        // 4. Persist credentials when present; otherwise clear any stale block.
        try updateCredentials(for: profile)
    }

    // MARK: - Delete

    public func deleteProfile(named name: String) throws {
        if let configText = readIfPresent(paths.configFile) {
            try writeBackup(of: configText, basename: "config")
            let updated = INIEditor.remove(header: "profile \(name)", in: configText)
            try writeFile(updated, to: paths.configFile, secure: false)
        }
        if let credText = readIfPresent(paths.credentialsFile) {
            try writeBackup(of: credText, basename: "credentials", secure: true)
            let updated = INIEditor.remove(header: name, in: credText)
            try writeFile(updated, to: paths.credentialsFile, secure: true)
        }
    }

    // MARK: - Credentials

    private func updateCredentials(for profile: Profile) throws {
        let hasCreds = [profile.accessKeyId, profile.secretAccessKey, profile.sessionToken]
            .contains { ($0?.isEmpty == false) }

        let current = readIfPresent(paths.credentialsFile)

        if hasCreds {
            if let current { try writeBackup(of: current, basename: "credentials", secure: true) }
            let updated = INIEditor.upsert(
                header: profile.name,
                pairs: credentialPairs(for: profile),
                in: current ?? ""
            )
            try writeFile(updated, to: paths.credentialsFile, secure: true)
        } else if let current, INIDocument(current).sections.contains(where: { $0.rawHeader == profile.name }) {
            // Editing removed the static credentials — drop the stale block.
            try writeBackup(of: current, basename: "credentials", secure: true)
            let updated = INIEditor.remove(header: profile.name, in: current)
            try writeFile(updated, to: paths.credentialsFile, secure: true)
        }
    }

    // MARK: - Pair builders

    private func profilePairs(for profile: Profile, sessionName: String?) -> [(String, String)] {
        var pairs: [(String, String)] = []
        if let sessionName { pairs.append(("sso_session", sessionName)) }
        if let account = profile.accountId { pairs.append(("sso_account_id", account)) }
        if let role = profile.roleName { pairs.append(("sso_role_name", role)) }
        if let region = profile.region { pairs.append(("region", region)) }
        for key in profile.extraSettings.keys.sorted() {
            pairs.append((key, profile.extraSettings[key] ?? ""))
        }
        return pairs
    }

    private func ssoSessionPairs(startURL: String, region: String?) -> [(String, String)] {
        var pairs: [(String, String)] = [("sso_start_url", startURL)]
        if let region { pairs.append(("sso_region", region)) }
        pairs.append(("sso_registration_scopes", Self.defaultScopes))
        return pairs
    }

    private func credentialPairs(for profile: Profile) -> [(String, String)] {
        var pairs: [(String, String)] = []
        if let v = profile.accessKeyId, !v.isEmpty { pairs.append(("aws_access_key_id", v)) }
        if let v = profile.secretAccessKey, !v.isEmpty { pairs.append(("aws_secret_access_key", v)) }
        if let v = profile.sessionToken, !v.isEmpty { pairs.append(("aws_session_token", v)) }
        return pairs
    }

    // MARK: - Session naming

    private func prefix(of name: String) -> String {
        guard let dash = name.firstIndex(of: "-") else { return name }
        return String(name[..<dash])
    }

    private func uniqueSessionName(base: String, existing: [String]) -> String {
        guard existing.contains(base) else { return base }
        var index = 2
        while existing.contains("\(base)-\(index)") { index += 1 }
        return "\(base)-\(index)"
    }

    // MARK: - IO

    private func readIfPresent(_ url: URL) -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// Atomic write, optionally restricting to `0600` (for credentials).
    private func writeFile(_ contents: String, to url: URL, secure: Bool) throws {
        try contents.write(to: url, atomically: true, encoding: .utf8)
        if secure {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600], ofItemAtPath: url.path
            )
        }
    }

    @discardableResult
    private func writeBackup(of contents: String, basename: String, secure: Bool = false) throws -> URL {
        let stamp = Self.timestamp(from: now())
        let backupURL = paths.configFile
            .deletingLastPathComponent()
            .appendingPathComponent("\(basename).bak.\(stamp)", isDirectory: false)
        try writeFile(contents, to: backupURL, secure: secure)
        return backupURL
    }

    static func timestamp(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }
}
