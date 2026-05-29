import XCTest
@testable import AWSProfileKit

final class FileProfileRepositoryTests: XCTestCase {

    // MARK: - Surgical rewrite (pure, no filesystem)

    func test_rewriteDefault_copiesProfileFieldsIntoDefaultBlock() {
        let text = """
        [default]
        region = us-east-1
        [profile prod]
        sso_session = main
        sso_account_id = 674442970707
        sso_role_name = ReadOnlyAccess
        region = us-east-1
        """
        let document = INIDocument(text)
        let prod = document.section(type: "profile", name: "prod")!

        let result = FileProfileRepository.rewriteDefault(in: document, mirroring: prod)

        // The new default mirrors the profile's pairs...
        XCTAssertTrue(result.contains("[default]\nsso_session = main"))
        XCTAssertTrue(result.contains("sso_account_id = 674442970707"))
        XCTAssertTrue(result.contains("sso_role_name = ReadOnlyAccess"))
        // ...and the old region-only default line is gone.
        XCTAssertFalse(result.contains("[default]\nregion = us-east-1\n[profile prod]"))
        // ...while the profile section itself is untouched.
        XCTAssertTrue(result.contains("[profile prod]"))
    }

    func test_rewriteDefault_preservesCommentsAndOtherSections() {
        let text = """
        # my aws config
        [default]
        region = us-east-1

        [profile prod]
        sso_account_id = 999
        region = eu-west-1

        [sso-session main]
        sso_start_url = https://x
        """
        let document = INIDocument(text)
        let prod = document.section(type: "profile", name: "prod")!

        let result = FileProfileRepository.rewriteDefault(in: document, mirroring: prod)

        XCTAssertTrue(result.contains("# my aws config"))
        XCTAssertTrue(result.contains("[sso-session main]"))
        XCTAssertTrue(result.contains("sso_start_url = https://x"))
        // Blank separator before the next section survives.
        XCTAssertTrue(result.contains("\n\n[profile prod]"))
    }

    func test_rewriteDefault_insertsDefaultWhenAbsent() {
        let text = """
        [profile only]
        sso_account_id = 123
        """
        let document = INIDocument(text)
        let only = document.section(type: "profile", name: "only")!

        let result = FileProfileRepository.rewriteDefault(in: document, mirroring: only)

        XCTAssertTrue(result.hasPrefix("[default]\nsso_account_id = 123"))
        XCTAssertTrue(result.contains("[profile only]"))
    }

    // MARK: - setDefault (integration over a temp filesystem)

    func test_setDefault_writesBackupAndRewrites() throws {
        let env = try TempAWSEnvironment(config: """
        [default]
        region = us-east-1
        [profile prod]
        sso_session = main
        sso_account_id = 674442970707
        sso_role_name = ReadOnlyAccess
        region = us-east-1
        """)
        defer { env.cleanup() }

        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let repo = FileProfileRepository(paths: env.paths, now: { fixedDate })

        let backupURL = try repo.setDefault(profileNamed: "prod")

        // Backup exists and holds the ORIGINAL content.
        let backup = try String(contentsOf: backupURL, encoding: .utf8)
        XCTAssertTrue(backup.contains("[default]\nregion = us-east-1\n[profile prod]"))
        XCTAssertEqual(backupURL.lastPathComponent, "config.bak.20231114-221320")

        // Live config now reflects prod under [default].
        let updated = try repo.load()
        XCTAssertEqual(updated.defaultProfileName, "prod")
    }

    func test_setDefault_throwsForUnknownProfile() throws {
        let env = try TempAWSEnvironment(config: "[profile a]\nsso_account_id = 1")
        defer { env.cleanup() }
        let repo = FileProfileRepository(paths: env.paths)

        XCTAssertThrowsError(try repo.setDefault(profileNamed: "ghost")) { error in
            XCTAssertEqual(error as? RepositoryError, .profileNotFound(name: "ghost"))
        }
    }

    func test_load_returnsEmptyWhenConfigMissing() throws {
        let env = try TempAWSEnvironment(config: nil)
        defer { env.cleanup() }
        let repo = FileProfileRepository(paths: env.paths)

        let config = try repo.load()
        XCTAssertTrue(config.profiles.isEmpty)
    }
}

/// A throwaway `~/.aws` directory under the temp folder.
private struct TempAWSEnvironment {
    let home: URL
    let paths: AWSPaths

    init(config: String?) throws {
        home = FileManager.default.temporaryDirectory
            .appendingPathComponent("awspm-tests-\(UUID().uuidString)", isDirectory: true)
        let awsDir = home.appendingPathComponent(".aws", isDirectory: true)
        try FileManager.default.createDirectory(at: awsDir, withIntermediateDirectories: true)
        paths = AWSPaths(homeDirectory: home)
        if let config {
            try config.write(to: paths.configFile, atomically: true, encoding: .utf8)
        }
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: home)
    }
}
