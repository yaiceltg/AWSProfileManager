import XCTest
@testable import AWSProfileKit

final class AuthorizationURLExtractionTests: XCTestCase {
    func test_extractsURLFromTypicalNoBrowserOutput() {
        let output = """
        Attempting to automatically open the SSO authorization page in your default browser.
        If the browser does not open or you wish to use a different device to authorize this request, open the following URL:

        https://oidc.us-east-1.amazonaws.com/authorize?response_type=code&client_id=abc&redirect_uri=http%3A%2F%2F127.0.0.1%3A50123

        """
        let url = ProcessCommandRunner.extractAuthorizationURL(from: output)
        XCTAssertEqual(
            url,
            "https://oidc.us-east-1.amazonaws.com/authorize?response_type=code&client_id=abc&redirect_uri=http%3A%2F%2F127.0.0.1%3A50123"
        )
    }

    func test_prefersAWSAuthURLOverOtherLinks() {
        let output = """
        See docs at https://docs.aws.amazon.com/cli first.
        Then open https://device.sso.us-east-1.amazonaws.com/?user_code=ABCD-EFGH
        """
        let url = ProcessCommandRunner.extractAuthorizationURL(from: output)
        XCTAssertEqual(url, "https://device.sso.us-east-1.amazonaws.com/?user_code=ABCD-EFGH")
    }

    func test_trimsTrailingPunctuation() {
        let output = "Open (https://oidc.us-east-1.amazonaws.com/authorize?x=1)."
        let url = ProcessCommandRunner.extractAuthorizationURL(from: output)
        XCTAssertEqual(url, "https://oidc.us-east-1.amazonaws.com/authorize?x=1")
    }

    func test_returnsNilWhenNoURL() {
        XCTAssertNil(ProcessCommandRunner.extractAuthorizationURL(from: "already logged in"))
    }

    func test_handlesPartialBufferGracefully() {
        // A chunk arriving before the URL line should yield nil, not a crash.
        XCTAssertNil(ProcessCommandRunner.extractAuthorizationURL(from: "Attempting to open the"))
    }
}

final class UserCodeExtractionTests: XCTestCase {
    func test_extractsDeviceCode() {
        let output = """
        Then enter the code:

        ABCD-EFGH
        """
        XCTAssertEqual(ProcessCommandRunner.extractUserCode(from: output), "ABCD-EFGH")
    }

    func test_extractsCodeAmidProse() {
        let output = "Confirm the following code in the browser: 7H2K-9QWZ before continuing."
        XCTAssertEqual(ProcessCommandRunner.extractUserCode(from: output), "7H2K-9QWZ")
    }

    func test_ignoresLowercaseAndRegions() {
        // Region strings and lowercase tokens must not be mistaken for a code.
        XCTAssertNil(ProcessCommandRunner.extractUserCode(from: "region us-east-1 sso fantaz-dev"))
    }

    func test_returnsNilWhenNoCode() {
        XCTAssertNil(ProcessCommandRunner.extractUserCode(from: "https://oidc.us-east-1.amazonaws.com/authorize"))
    }
}

final class UserDefaultsBrowserPreferenceStoreTests: XCTestCase {
    private func makeStore() -> (UserDefaultsBrowserPreferenceStore, UserDefaults, String) {
        let suite = "awspm-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (UserDefaultsBrowserPreferenceStore(defaults: defaults), defaults, suite)
    }

    func test_defaultsToNil() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertNil(store.selectedBrowserID())
    }

    func test_persistsAndReadsBack() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        store.setSelectedBrowserID("com.google.Chrome")
        XCTAssertEqual(store.selectedBrowserID(), "com.google.Chrome")
    }

    func test_nilClearsSelection() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        store.setSelectedBrowserID("com.apple.Safari")
        store.setSelectedBrowserID(nil)
        XCTAssertNil(store.selectedBrowserID())
    }
}
