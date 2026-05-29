import Foundation

public enum RepositoryError: Error, Equatable, Sendable {
    case configFileNotFound(path: String)
    case profileNotFound(name: String)
}

/// `ProfileRepository` backed by the real `~/.aws/config` file.
public struct FileProfileRepository: ProfileRepository {
    private let paths: AWSPaths
    private let parser: INIConfigParser
    private let now: @Sendable () -> Date

    public init(
        paths: AWSPaths = .default,
        parser: INIConfigParser = INIConfigParser(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.paths = paths
        self.parser = parser
        self.now = now
    }

    // MARK: - Load

    public func load() throws -> AWSConfiguration {
        guard FileManager.default.fileExists(atPath: paths.configFile.path) else {
            return AWSConfiguration(profiles: [], ssoSessions: [])
        }
        let text = try String(contentsOf: paths.configFile, encoding: .utf8)
        return parser.parse(text)
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

        let backupURL = try writeBackup(of: text)
        let newText = Self.rewriteDefault(in: document, mirroring: profile)
        try newText.write(to: paths.configFile, atomically: true, encoding: .utf8)
        return backupURL
    }

    // MARK: - Backup

    private func writeBackup(of text: String) throws -> URL {
        let stamp = Self.timestamp(from: now())
        let backupURL = paths.configFile
            .deletingLastPathComponent()
            .appendingPathComponent("config.bak.\(stamp)", isDirectory: false)
        try text.write(to: backupURL, atomically: true, encoding: .utf8)
        return backupURL
    }

    static func timestamp(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }

    // MARK: - Surgical rewrite

    /// Replaces the `[default]` block's key/value lines with those of `profile`,
    /// leaving every other line (comments, blanks, other sections) untouched.
    /// Trailing blank/comment lines inside the old block are preserved.
    static func rewriteDefault(
        in document: INIDocument,
        mirroring profile: INIDocument.Section
    ) -> String {
        let block = renderDefaultBlock(from: profile.pairs)
        var lines = document.lines

        if let existing = document.section(type: "default", name: nil) {
            let replaceRange = effectiveContentRange(of: existing, in: lines)
            lines.replaceSubrange(replaceRange, with: block)
        } else {
            // No default yet: prepend it, followed by a blank separator.
            lines.insert(contentsOf: block + [""], at: 0)
        }
        return lines.joined(separator: "\n")
    }

    /// The header line plus a rendered line per key/value pair.
    private static func renderDefaultBlock(from pairs: [INIDocument.KeyValue]) -> [String] {
        ["[default]"] + pairs.map { "\($0.key) = \($0.value)" }
    }

    /// Narrows a section's full line range to exclude trailing blank/comment
    /// lines, so separators before the next section survive the splice.
    private static func effectiveContentRange(
        of section: INIDocument.Section,
        in lines: [String]
    ) -> Range<Int> {
        var end = section.lineRange.upperBound
        while end - 1 > section.lineRange.lowerBound {
            let candidate = lines[end - 1].trimmingCharacters(in: .whitespaces)
            if candidate.isEmpty || candidate.hasPrefix("#") || candidate.hasPrefix(";") {
                end -= 1
            } else {
                break
            }
        }
        return section.lineRange.lowerBound..<end
    }
}
