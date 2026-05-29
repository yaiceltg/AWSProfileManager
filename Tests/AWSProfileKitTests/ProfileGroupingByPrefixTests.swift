import XCTest
@testable import AWSProfileKit

final class ProfileGroupingByPrefixTests: XCTestCase {
    func test_groupsByPrefixWithDisplayNames() {
        let profiles = [
            Profile(name: "fantaz-dev"),
            Profile(name: "fantaz-prod"),
            Profile(name: "fantaz-prod-admin-sso")
        ]
        let groups = ProfileGrouping.byPrefix(profiles)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].title, "Fantaz")
        XCTAssertEqual(groups[0].items.map(\.displayName), ["dev", "prod", "prod-admin-sso"])
        XCTAssertEqual(groups[0].items.map(\.profile.name), ["fantaz-dev", "fantaz-prod", "fantaz-prod-admin-sso"])
    }

    func test_separateGroupsPreserveOrder() {
        let groups = ProfileGrouping.byPrefix([
            Profile(name: "acme-dev"),
            Profile(name: "fantaz-dev"),
            Profile(name: "acme-prod")
        ])
        XCTAssertEqual(groups.map(\.title), ["Acme", "Fantaz"])
        XCTAssertEqual(groups[0].items.count, 2)
    }

    func test_customDisplayNameOverridesDerived() {
        let groups = ProfileGrouping.grouped(
            [Profile(name: "fantaz-dev"), Profile(name: "fantaz-prod")],
            assignments: [:],
            displayNames: ["fantaz-dev": "Dev Admin"]
        )
        let items = groups[0].items
        XCTAssertEqual(items.first { $0.profile.name == "fantaz-dev" }?.displayName, "Dev Admin")
        // Others keep the derived name.
        XCTAssertEqual(items.first { $0.profile.name == "fantaz-prod" }?.displayName, "prod")
    }

    func test_nameWithoutDashBecomesOwnGroup() {
        let groups = ProfileGrouping.byPrefix([Profile(name: "standalone")])
        XCTAssertEqual(groups[0].title, "Standalone")
        XCTAssertEqual(groups[0].items.first?.displayName, "standalone")
    }

    func test_manualAssignmentOverridesPrefix_andShowsFullKey() {
        let profiles = [Profile(name: "prod-acct-1"), Profile(name: "fantaz-dev")]
        let groups = ProfileGrouping.grouped(profiles, assignments: ["prod-acct-1": "Fantaz"])

        // Both land under "Fantaz" (one manual, one via prefix title-casing).
        XCTAssertEqual(groups.map(\.title), ["Fantaz"])
        let items = groups[0].items
        XCTAssertEqual(Set(items.map(\.profile.name)), ["prod-acct-1", "fantaz-dev"])
        // Manual assignment shows the full key; prefix one shows the remainder.
        XCTAssertEqual(items.first { $0.profile.name == "prod-acct-1" }?.displayName, "prod-acct-1")
        XCTAssertEqual(items.first { $0.profile.name == "fantaz-dev" }?.displayName, "dev")
    }
}
