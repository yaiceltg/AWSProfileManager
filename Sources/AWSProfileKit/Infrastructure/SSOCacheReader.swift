import Foundation

/// `SSOTokenReader` backed by `~/.aws/sso/cache/*.json`.
///
/// Security: the decoded model declares only `startUrl`, `region`, and
/// `expiresAt` — the `accessToken` field present in the file is never read into
/// memory. Entries are matched to a session by `startUrl`, since the cache file
/// naming scheme has changed across CLI versions.
public struct SSOCacheReader: SSOTokenReader {
    private let paths: AWSPaths

    public init(paths: AWSPaths = .default) {
        self.paths = paths
    }

    private struct CacheEntry: Decodable {
        let startUrl: String?
        let region: String?
        let expiresAt: String?
    }

    public func expiresAt(for session: SSOSession) throws -> Date? {
        guard let startURL = session.startURL else { return nil }
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: paths.ssoCacheDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return nil
        }

        var latest: Date?
        for file in files where file.pathExtension == "json" {
            guard
                let data = try? Data(contentsOf: file),
                let entry = try? JSONDecoder().decode(CacheEntry.self, from: data),
                entry.startUrl == startURL,
                let raw = entry.expiresAt,
                let date = Self.parseDate(raw)
            else { continue }

            if latest == nil || date > latest! {
                latest = date
            }
        }
        return latest
    }

    /// Parses the `expiresAt` timestamp. The CLI emits ISO-8601 with a `Z`
    /// suffix; older boto caches used a `UTC` suffix instead.
    static func parseDate(_ raw: String) -> Date? {
        let normalized = raw.hasSuffix("UTC")
            ? String(raw.dropLast(3)) + "Z"
            : raw

        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: normalized) { return date }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: normalized)
    }
}
