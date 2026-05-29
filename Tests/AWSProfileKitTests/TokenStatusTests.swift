import XCTest
@testable import AWSProfileKit

final class TokenStatusTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    func test_unknown_whenNoExpiry() {
        XCTAssertEqual(TokenStatus.from(expiresAt: nil, now: now), .unknown)
    }

    func test_expired_whenExpiryInPast() {
        let past = now.addingTimeInterval(-1)
        XCTAssertEqual(TokenStatus.from(expiresAt: past, now: now), .expired)
    }

    func test_expired_whenExpiryExactlyNow() {
        XCTAssertEqual(TokenStatus.from(expiresAt: now, now: now), .expired)
    }

    func test_expiringSoon_withinWarningWindow() {
        let soon = now.addingTimeInterval(TokenStatus.warningWindow - 1)
        guard case let .expiringSoon(remaining) = TokenStatus.from(expiresAt: soon, now: now) else {
            return XCTFail("expected expiringSoon")
        }
        XCTAssertEqual(remaining, TokenStatus.warningWindow - 1, accuracy: 0.001)
    }

    func test_valid_beyondWarningWindow() {
        let later = now.addingTimeInterval(TokenStatus.warningWindow + 60)
        guard case let .valid(remaining) = TokenStatus.from(expiresAt: later, now: now) else {
            return XCTFail("expected valid")
        }
        XCTAssertEqual(remaining, TokenStatus.warningWindow + 60, accuracy: 0.001)
    }

    func test_isActive() {
        XCTAssertTrue(TokenStatus.valid(remaining: 100).isActive)
        XCTAssertTrue(TokenStatus.expiringSoon(remaining: 100).isActive)
        XCTAssertFalse(TokenStatus.expired.isActive)
        XCTAssertFalse(TokenStatus.unknown.isActive)
    }
}
