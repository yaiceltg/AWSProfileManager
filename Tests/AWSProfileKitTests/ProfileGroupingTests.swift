import XCTest
@testable import AWSProfileKit

final class ProfileGroupingTests: XCTestCase {
    func test_groupsProfilesBySharedSession() {
        let config = AWSConfiguration(
            profiles: [
                Profile(name: "dev", ssoSessionName: "main"),
                Profile(name: "prod", ssoSessionName: "main"),
                Profile(name: "legacy") // no session
            ],
            ssoSessions: [SSOSession(name: "main", startURL: "https://x")]
        )

        let groups = config.groupedBySession()

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].sessionName, "main")
        XCTAssertEqual(groups[0].profiles.map(\.name), ["dev", "prod"])
        XCTAssertNotNil(groups[0].session)
        XCTAssertTrue(groups[0].isSSOGroup)

        XCTAssertNil(groups[1].sessionName)
        XCTAssertEqual(groups[1].profiles.map(\.name), ["legacy"])
        XCTAssertNil(groups[1].session)
        XCTAssertFalse(groups[1].isSSOGroup)
    }

    func test_preservesEncounterOrderOfSessions() {
        let config = AWSConfiguration(
            profiles: [
                Profile(name: "a", ssoSessionName: "second"),
                Profile(name: "b", ssoSessionName: "first"),
                Profile(name: "c", ssoSessionName: "second")
            ],
            ssoSessions: []
        )
        XCTAssertEqual(config.groupedBySession().map(\.sessionName), ["second", "first"])
    }

    func test_groupWithMissingSessionBlock_stillGroups() {
        // Profiles reference a session that has no [sso-session] block.
        let config = AWSConfiguration(
            profiles: [Profile(name: "x", ssoSessionName: "ghost")],
            ssoSessions: []
        )
        let group = config.groupedBySession()[0]
        XCTAssertEqual(group.sessionName, "ghost")
        XCTAssertNil(group.session) // unresolved — a misconfiguration the UI can flag
    }
}
