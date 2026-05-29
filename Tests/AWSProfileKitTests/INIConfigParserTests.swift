import XCTest
@testable import AWSProfileKit

final class INIConfigParserTests: XCTestCase {
    private let parser = INIConfigParser()

    // Mirrors the real-world modern SSO layout: many profiles, one shared session.
    private let sample = """
    [default]
    region = us-east-1
    [profile fantaz-dev]
    sso_session = fantaz-dev
    sso_account_id = 413107053704
    sso_role_name = AWSAdministratorAccess
    region = us-east-1
    [profile fantaz-prod]
    sso_session = fantaz-dev
    sso_account_id = 674442970707
    sso_role_name = ReadOnlyAccess
    region = us-east-1

    [sso-session fantaz-dev]
    sso_start_url = https://example.awsapps.com/start
    sso_region = us-east-1
    sso_registration_scopes = sso:account:access
    """

    func test_parsesAllProfiles() {
        let config = parser.parse(sample)
        XCTAssertEqual(config.profiles.map(\.name), ["fantaz-dev", "fantaz-prod"])
    }

    func test_parsesProfileFields() {
        let config = parser.parse(sample)
        let prod = config.profile(named: "fantaz-prod")
        XCTAssertEqual(prod?.ssoSessionName, "fantaz-dev")
        XCTAssertEqual(prod?.accountId, "674442970707")
        XCTAssertEqual(prod?.roleName, "ReadOnlyAccess")
        XCTAssertEqual(prod?.region, "us-east-1")
        XCTAssertTrue(prod?.isSSO == true)
    }

    func test_parsesSSOSession() {
        let config = parser.parse(sample)
        let session = config.session(named: "fantaz-dev")
        XCTAssertEqual(session?.startURL, "https://example.awsapps.com/start")
        XCTAssertEqual(session?.region, "us-east-1")
        XCTAssertEqual(session?.registrationScopes, "sso:account:access")
    }

    func test_regionOnlyDefault_matchesNoProfile() {
        let config = parser.parse(sample)
        XCTAssertNil(config.defaultProfileName)
    }

    func test_defaultMatchesProfile_whenIdentityEqual() {
        let withDefault = """
        [default]
        sso_session = fantaz-dev
        sso_account_id = 674442970707
        sso_role_name = ReadOnlyAccess
        region = us-east-1
        [profile fantaz-prod]
        sso_session = fantaz-dev
        sso_account_id = 674442970707
        sso_role_name = ReadOnlyAccess
        region = us-east-1
        """
        XCTAssertEqual(parser.parse(withDefault).defaultProfileName, "fantaz-prod")
    }

    func test_ignoresCommentsAndBlankLines() {
        let withNoise = """
        # this is a comment
        [profile solo]
        ; inline-style comment
        sso_account_id = 111122223333

        """
        let config = parser.parse(withNoise)
        XCTAssertEqual(config.profiles.count, 1)
        XCTAssertEqual(config.profiles.first?.accountId, "111122223333")
    }

    func test_preservesUnknownKeysAsExtras() {
        let withExtra = """
        [profile custom]
        sso_account_id = 1
        output = json
        cli_pager =
        """
        let profile = parser.parse(withExtra).profile(named: "custom")
        XCTAssertEqual(profile?.extraSettings["output"], "json")
        XCTAssertEqual(profile?.extraSettings["cli_pager"], "")
    }
}
