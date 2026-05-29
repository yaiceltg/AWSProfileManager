import XCTest
@testable import AWSProfileKit

final class CallerIdentityTests: XCTestCase {
    func test_parsesAssumedRoleArn() {
        let id = CallerIdentity(
            account: "413107053704",
            arn: "arn:aws:sts::413107053704:assumed-role/AWSAdministratorAccess_abc/yaicel",
            userId: "AROAEXAMPLE:yaicel"
        )
        XCTAssertEqual(id.partition, "aws")
        XCTAssertEqual(id.identityType, "assumed-role")
        XCTAssertEqual(id.roleName, "AWSAdministratorAccess_abc")
        XCTAssertEqual(id.sessionName, "yaicel")
    }

    func test_parsesIamUserArn() {
        let id = CallerIdentity(
            account: "123456789012",
            arn: "arn:aws:iam::123456789012:user/yaicel",
            userId: "AIDAEXAMPLE"
        )
        XCTAssertEqual(id.identityType, "user")
        XCTAssertNil(id.roleName)
        XCTAssertNil(id.sessionName)
    }

    func test_parsesGovCloudPartition() {
        let id = CallerIdentity(
            account: "1",
            arn: "arn:aws-us-gov:sts::1:assumed-role/Role/sess",
            userId: "x"
        )
        XCTAssertEqual(id.partition, "aws-us-gov")
    }

    func test_parsesFromJSON() {
        let json = """
        {"UserId": "AROAEXAMPLE:yaicel", "Account": "413107053704", "Arn": "arn:aws:sts::413107053704:assumed-role/Admin/yaicel"}
        """
        let id = CallerIdentity(json: json)
        XCTAssertEqual(id?.account, "413107053704")
        XCTAssertEqual(id?.roleName, "Admin")
    }

    func test_returnsNilForInvalidJSON() {
        XCTAssertNil(CallerIdentity(json: "not json"))
    }
}
