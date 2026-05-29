import XCTest
@testable import AWSProfileKit

final class FileProfileRepositoryTests: XCTestCase {

    private static let fixedDate = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14T22:13:20Z

    // MARK: - Set default

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
        let repo = FileProfileRepository(paths: env.paths, now: { Self.fixedDate })

        let backupURL = try repo.setDefault(profileNamed: "prod")

        let backup = try String(contentsOf: backupURL, encoding: .utf8)
        XCTAssertTrue(backup.contains("[default]\nregion = us-east-1\n[profile prod]"))
        XCTAssertEqual(backupURL.lastPathComponent, "config.bak.20231114-221320")
        XCTAssertEqual(try repo.load().defaultProfileName, "prod")
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
        XCTAssertTrue(try FileProfileRepository(paths: env.paths).load().profiles.isEmpty)
    }

    // MARK: - Load enrichment

    func test_load_enrichesWithSessionAndCredentials() throws {
        let env = try TempAWSEnvironment(
            config: """
            [profile dev]
            sso_session = main
            sso_account_id = 111
            region = us-east-1
            [sso-session main]
            sso_start_url = https://mine
            sso_region = us-east-1
            """,
            credentials: """
            [dev]
            aws_access_key_id = AKIAEXAMPLE
            aws_secret_access_key = secretvalue
            """
        )
        defer { env.cleanup() }

        let dev = try FileProfileRepository(paths: env.paths).load().profile(named: "dev")
        XCTAssertEqual(dev?.ssoStartURL, "https://mine")
        XCTAssertEqual(dev?.ssoRegion, "us-east-1")
        XCTAssertEqual(dev?.accessKeyId, "AKIAEXAMPLE")
        XCTAssertEqual(dev?.secretAccessKey, "secretvalue")
    }

    // MARK: - Save

    func test_saveProfile_dedupsSessionByStartURL() throws {
        let env = try TempAWSEnvironment(config: """
        [profile fantaz-dev]
        sso_session = fantaz-dev
        sso_account_id = 111
        region = us-east-1
        [sso-session fantaz-dev]
        sso_start_url = https://mine
        sso_region = us-east-1
        """)
        defer { env.cleanup() }
        let repo = FileProfileRepository(paths: env.paths, now: { Self.fixedDate })

        try repo.saveProfile(Profile(
            name: "fantaz-prod", accountId: "222", roleName: "ReadOnly",
            region: "us-east-1", ssoStartURL: "https://mine", ssoRegion: "us-east-1"
        ))

        let config = try repo.load()
        XCTAssertEqual(config.profile(named: "fantaz-prod")?.ssoSessionName, "fantaz-dev")
        XCTAssertEqual(config.ssoSessions.count, 1, "should reuse the existing session, not create a new one")
    }

    func test_saveProfile_createsNewSessionForNewURL() throws {
        let env = try TempAWSEnvironment(config: """
        [profile fantaz-dev]
        sso_session = fantaz-dev
        [sso-session fantaz-dev]
        sso_start_url = https://mine
        sso_region = us-east-1
        """)
        defer { env.cleanup() }
        let repo = FileProfileRepository(paths: env.paths, now: { Self.fixedDate })

        try repo.saveProfile(Profile(
            name: "acme-dev", accountId: "333", roleName: "Admin",
            region: "eu-west-1", ssoStartURL: "https://other", ssoRegion: "eu-west-1"
        ))

        let config = try repo.load()
        XCTAssertEqual(config.profile(named: "acme-dev")?.ssoSessionName, "acme")
        XCTAssertEqual(config.session(named: "acme")?.startURL, "https://other")
        XCTAssertEqual(config.ssoSessions.count, 2)
    }

    func test_saveProfile_writesCredentialsWith0600() throws {
        let env = try TempAWSEnvironment(config: "")
        defer { env.cleanup() }
        let repo = FileProfileRepository(paths: env.paths, now: { Self.fixedDate })

        try repo.saveProfile(Profile(
            name: "static1", region: "us-east-1",
            accessKeyId: "AKIAEXAMPLE", secretAccessKey: "secretvalue"
        ))

        let creds = try String(contentsOf: env.paths.credentialsFile, encoding: .utf8)
        XCTAssertTrue(creds.contains("[static1]"))
        XCTAssertTrue(creds.contains("aws_access_key_id = AKIAEXAMPLE"))

        let perms = try FileManager.default
            .attributesOfItem(atPath: env.paths.credentialsFile.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(perms?.intValue, 0o600)
    }

    // MARK: - Delete

    func test_deleteProfile_removesFromBothFiles() throws {
        let env = try TempAWSEnvironment(
            config: "[profile gone]\nregion = us-east-1\n[profile keep]\nregion = us-east-1",
            credentials: "[gone]\naws_access_key_id = AKIA"
        )
        defer { env.cleanup() }
        let repo = FileProfileRepository(paths: env.paths, now: { Self.fixedDate })

        try repo.deleteProfile(named: "gone")

        let config = try repo.load()
        XCTAssertNil(config.profile(named: "gone"))
        XCTAssertNotNil(config.profile(named: "keep"))
        let creds = try String(contentsOf: env.paths.credentialsFile, encoding: .utf8)
        XCTAssertFalse(creds.contains("[gone]"))
    }
}

/// A throwaway `~/.aws` directory under the temp folder.
struct TempAWSEnvironment {
    let home: URL
    let paths: AWSPaths

    init(config: String?, credentials: String? = nil) throws {
        home = FileManager.default.temporaryDirectory
            .appendingPathComponent("awspm-tests-\(UUID().uuidString)", isDirectory: true)
        let awsDir = home.appendingPathComponent(".aws", isDirectory: true)
        try FileManager.default.createDirectory(at: awsDir, withIntermediateDirectories: true)
        paths = AWSPaths(homeDirectory: home)
        if let config {
            try config.write(to: paths.configFile, atomically: true, encoding: .utf8)
        }
        if let credentials {
            try credentials.write(to: paths.credentialsFile, atomically: true, encoding: .utf8)
        }
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: home)
    }
}
