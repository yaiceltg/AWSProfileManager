import XCTest
@testable import AWSProfileKit

final class SSOCacheReaderTests: XCTestCase {
    func test_parsesISO8601WithZSuffix() {
        let date = SSOCacheReader.parseDate("2026-05-29T20:00:00Z")
        XCTAssertEqual(date, Date(timeIntervalSince1970: 1_780_084_800))
    }

    func test_parsesISO8601WithFractionalSeconds() {
        let date = SSOCacheReader.parseDate("2026-05-29T20:00:00.123Z")
        XCTAssertNotNil(date)
    }

    func test_parsesLegacyUTCSuffix() {
        // Older boto caches wrote a `UTC` suffix instead of `Z`.
        let z = SSOCacheReader.parseDate("2026-05-29T20:00:00Z")
        let utc = SSOCacheReader.parseDate("2026-05-29T20:00:00UTC")
        XCTAssertEqual(utc, z)
    }

    func test_returnsNilForGarbage() {
        XCTAssertNil(SSOCacheReader.parseDate("not-a-date"))
    }

    // MARK: - Matching against the cache directory

    func test_expiresAt_matchesByStartURL_andPicksLatest() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("awspm-cache-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: home) }

        let paths = AWSPaths(homeDirectory: home)
        try FileManager.default.createDirectory(
            at: paths.ssoCacheDirectory, withIntermediateDirectories: true
        )

        // Two entries for our session (latest should win) + one unrelated entry.
        try writeEntry(in: paths, name: "a", startURL: "https://mine", expiresAt: "2026-05-29T18:00:00Z")
        try writeEntry(in: paths, name: "b", startURL: "https://mine", expiresAt: "2026-05-29T20:00:00Z")
        try writeEntry(in: paths, name: "c", startURL: "https://other", expiresAt: "2030-01-01T00:00:00Z")

        let reader = SSOCacheReader(paths: paths)
        let session = SSOSession(name: "x", startURL: "https://mine")

        let result = try reader.expiresAt(for: session)
        XCTAssertEqual(result, Date(timeIntervalSince1970: 1_780_084_800)) // the 20:00 entry
    }

    func test_expiresAt_nilWhenNoStartURL() throws {
        let reader = SSOCacheReader(paths: .default)
        XCTAssertNil(try reader.expiresAt(for: SSOSession(name: "x", startURL: nil)))
    }

    private func writeEntry(
        in paths: AWSPaths, name: String, startURL: String, expiresAt: String
    ) throws {
        // Includes an accessToken on disk to prove the reader never surfaces it.
        let json = """
        {"startUrl":"\(startURL)","region":"us-east-1","accessToken":"SECRET","expiresAt":"\(expiresAt)"}
        """
        let url = paths.ssoCacheDirectory.appendingPathComponent("\(name).json")
        try json.write(to: url, atomically: true, encoding: .utf8)
    }
}
