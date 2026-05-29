import XCTest
@testable import AWSProfileKit

final class TemporaryCredentialsTests: XCTestCase {
    func test_parsesExportCredentialsJSON() {
        let json = """
        {"Version":1,"AccessKeyId":"AKIA","SecretAccessKey":"sec+ret/v=","SessionToken":"tok+en/=="}
        """
        let creds = TemporaryCredentials(json: json)
        XCTAssertEqual(creds?.accessKeyId, "AKIA")
        XCTAssertEqual(creds?.secretAccessKey, "sec+ret/v=")
        XCTAssertEqual(creds?.sessionToken, "tok+en/==")
    }

    func test_nilWithoutSessionToken_isParsedButTokenNil() {
        let json = #"{"AccessKeyId":"AKIA","SecretAccessKey":"s"}"#
        let creds = TemporaryCredentials(json: json)
        XCTAssertNotNil(creds)
        XCTAssertNil(creds?.sessionToken)
    }
}

final class ConsoleFederationTests: XCTestCase {
    func test_encodeEscapesBase64Characters() {
        // +, /, = must be percent-encoded (query encoding leaves + alone otherwise).
        let encoded = AWSConsoleFederation.encode("a+b/c=d")
        XCTAssertFalse(encoded.contains("+"))
        XCTAssertFalse(encoded.contains("/"))
        XCTAssertFalse(encoded.contains("="))
        XCTAssertEqual(encoded, "a%2Bb%2Fc%3Dd")
    }

    func test_sessionJSONContainsCredentialKeys() {
        let json = AWSConsoleFederation.sessionJSON(
            credentials: TemporaryCredentials(accessKeyId: "AKIA", secretAccessKey: "S", sessionToken: "T"),
            sessionToken: "T"
        )
        XCTAssertTrue(json.contains("\"sessionId\":\"AKIA\""))
        XCTAssertTrue(json.contains("\"sessionKey\":\"S\""))
        XCTAssertTrue(json.contains("\"sessionToken\":\"T\""))
    }

    func test_destinationUsesRegionWhenPresent() {
        XCTAssertEqual(
            AWSConsoleFederation.destination(region: "us-east-1"),
            "https://console.aws.amazon.com/console/home?region=us-east-1"
        )
        XCTAssertEqual(
            AWSConsoleFederation.destination(region: nil),
            "https://console.aws.amazon.com/"
        )
    }

    func test_loginURLStructure() {
        let url = AWSConsoleFederation.loginURL(signinToken: "tok/en+", destination: "https://console.aws.amazon.com/")
        XCTAssertTrue(url.hasPrefix("https://signin.aws.amazon.com/federation?Action=login"))
        XCTAssertTrue(url.contains("&Issuer="))
        XCTAssertTrue(url.contains("&Destination="))
        XCTAssertTrue(url.contains("&SigninToken="))
        XCTAssertFalse(url.contains("tok/en+")) // token is encoded
    }

    func test_parsesSigninTokenFromResponse() {
        let data = Data(#"{"SigninToken":"abc123"}"#.utf8)
        XCTAssertEqual(AWSConsoleFederation.parseSigninToken(data), "abc123")
    }
}
