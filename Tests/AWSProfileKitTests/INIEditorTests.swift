import XCTest
@testable import AWSProfileKit

final class INIEditorTests: XCTestCase {
    func test_upsert_replacesExistingSectionContent() {
        let text = """
        [default]
        region = us-east-1
        [profile prod]
        sso_session = main
        """
        let result = INIEditor.upsert(
            header: "default",
            pairs: [("sso_session", "main"), ("sso_account_id", "999")],
            in: text
        )
        XCTAssertTrue(result.contains("[default]\nsso_session = main\nsso_account_id = 999"))
        XCTAssertFalse(result.contains("region = us-east-1\n[profile prod]"))
        XCTAssertTrue(result.contains("[profile prod]")) // untouched
    }

    func test_upsert_preservesCommentsAndSeparators() {
        let text = """
        # header comment
        [default]
        region = us-east-1

        [profile prod]
        sso_account_id = 1
        """
        let result = INIEditor.upsert(header: "default", pairs: [("region", "eu-west-1")], in: text)
        XCTAssertTrue(result.contains("# header comment"))
        XCTAssertTrue(result.contains("\n\n[profile prod]")) // blank separator survives
        XCTAssertTrue(result.contains("[default]\nregion = eu-west-1"))
    }

    func test_upsert_appendsWhenAbsent() {
        let text = "[profile a]\nregion = us-east-1"
        let result = INIEditor.upsert(header: "profile b", pairs: [("region", "eu-west-1")], in: text)
        XCTAssertTrue(result.contains("[profile a]"))
        XCTAssertTrue(result.hasSuffix("[profile b]\nregion = eu-west-1"))
        XCTAssertTrue(result.contains("region = us-east-1\n\n[profile b]")) // one blank separator
    }

    func test_upsert_intoEmptyText() {
        let result = INIEditor.upsert(header: "sso-session main", pairs: [("sso_start_url", "https://x")], in: "")
        XCTAssertEqual(result, "[sso-session main]\nsso_start_url = https://x")
    }

    func test_remove_deletesSectionLeavingRest() {
        let text = """
        [profile a]
        region = us-east-1
        [profile b]
        region = eu-west-1
        """
        let result = INIEditor.remove(header: "profile a", in: text)
        XCTAssertFalse(result.contains("[profile a]"))
        XCTAssertTrue(result.contains("[profile b]"))
    }

    func test_remove_noopWhenAbsent() {
        let text = "[profile a]\nregion = us-east-1"
        XCTAssertEqual(INIEditor.remove(header: "profile ghost", in: text), text)
    }
}
