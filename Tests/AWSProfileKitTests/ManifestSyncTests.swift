import XCTest
@testable import AWSProfileKit

final class ManifestSyncTests: XCTestCase {
    private func makeStore() -> (JSONManifestStore, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("awspm-manifest-\(UUID().uuidString).json")
        return (JSONManifestStore(fileURL: url), url)
    }

    private func ssoProfile(_ name: String, account: String? = "111", role: String? = "Admin") -> Profile {
        Profile(
            name: name, ssoSessionName: "main", accountId: account, roleName: role,
            region: "us-east-1", ssoStartURL: "https://mine", ssoRegion: "us-east-1"
        )
    }

    func test_ok_whenLiveMatchesManifest() {
        let (store, url) = makeStore(); defer { try? FileManager.default.removeItem(at: url) }
        let sync = SyncManifest(store: store)
        let p = ssoProfile("fantaz-dev")
        sync.adopt(live: [p])
        XCTAssertEqual(sync.diff(live: [p])["fantaz-dev"], .ok)
    }

    func test_modified_whenFieldChangedOutsideApp() {
        let (store, url) = makeStore(); defer { try? FileManager.default.removeItem(at: url) }
        let sync = SyncManifest(store: store)
        sync.adopt(live: [ssoProfile("fantaz-dev", role: "Admin")])
        let changed = ssoProfile("fantaz-dev", role: "ReadOnly")
        XCTAssertEqual(sync.diff(live: [changed])["fantaz-dev"], .modified)
    }

    func test_untracked_whenNotInManifest() {
        let (store, url) = makeStore(); defer { try? FileManager.default.removeItem(at: url) }
        let sync = SyncManifest(store: store)
        XCTAssertEqual(sync.diff(live: [ssoProfile("new")])["new"], .untracked)
    }

    func test_removed_whenInManifestButNotLive() {
        let (store, url) = makeStore(); defer { try? FileManager.default.removeItem(at: url) }
        let sync = SyncManifest(store: store)
        sync.adopt(live: [ssoProfile("gone")])
        XCTAssertEqual(sync.diff(live: [])["gone"], .removed)
    }

    func test_broken_whenSSOProfileHasNoStartURL() {
        let (store, url) = makeStore(); defer { try? FileManager.default.removeItem(at: url) }
        let sync = SyncManifest(store: store)
        let broken = Profile(name: "x", ssoSessionName: "main", accountId: "1", roleName: "r")
        if case .broken = sync.diff(live: [broken])["x"] {} else {
            XCTFail("expected broken")
        }
    }

    func test_recordAndForget() {
        let (store, url) = makeStore(); defer { try? FileManager.default.removeItem(at: url) }
        let sync = SyncManifest(store: store)
        sync.record(ssoProfile("a"))
        XCTAssertEqual(sync.diff(live: [ssoProfile("a")])["a"], .ok)
        sync.forget(named: "a")
        XCTAssertEqual(sync.diff(live: [ssoProfile("a")])["a"], .untracked)
    }

    func test_setAndClearGroup() {
        let (store, url) = makeStore(); defer { try? FileManager.default.removeItem(at: url) }
        let sync = SyncManifest(store: store)
        sync.setGroup("Fantaz", for: "prod-acct-1")
        XCTAssertEqual(sync.groups()["prod-acct-1"], "Fantaz")
        sync.setGroup(nil, for: "prod-acct-1")
        XCTAssertNil(sync.groups()["prod-acct-1"])
    }

    func test_adoptPreservesGroupAssignments() {
        let (store, url) = makeStore(); defer { try? FileManager.default.removeItem(at: url) }
        let sync = SyncManifest(store: store)
        sync.setGroup("Fantaz", for: "a")
        sync.adopt(live: [ssoProfile("a")])
        XCTAssertEqual(sync.groups()["a"], "Fantaz")
    }

    func test_forgetClearsGroup() {
        let (store, url) = makeStore(); defer { try? FileManager.default.removeItem(at: url) }
        let sync = SyncManifest(store: store)
        sync.setGroup("Fantaz", for: "a")
        sync.forget(named: "a")
        XCTAssertNil(sync.groups()["a"])
    }

    func test_doesNotStoreSecretsInManifest() throws {
        let (store, url) = makeStore(); defer { try? FileManager.default.removeItem(at: url) }
        let sync = SyncManifest(store: store)
        sync.record(Profile(name: "s", accessKeyId: "AKIASECRET", secretAccessKey: "topsecret"))
        let json = try String(contentsOf: url, encoding: .utf8)
        XCTAssertFalse(json.contains("AKIASECRET"))
        XCTAssertFalse(json.contains("topsecret"))
        XCTAssertTrue(json.contains("hasAccessKey"))
    }
}
