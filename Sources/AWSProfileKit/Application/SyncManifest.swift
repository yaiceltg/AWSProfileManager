import Foundation

/// Compares the live config against the app manifest to classify each profile,
/// and lets the app adopt the current live state as the new baseline.
public struct SyncManifest: Sendable {
    private let store: ManifestStore

    public init(store: ManifestStore) {
        self.store = store
    }

    /// Drift status for every profile (union of live + manifest), keyed by name.
    public func diff(live: [Profile]) -> [String: DriftStatus] {
        let manifest = store.load()
        let liveByName = Dictionary(uniqueKeysWithValues: live.map { ($0.name, $0) })
        let manifestNames = Set(manifest.profiles.map(\.name))

        var result: [String: DriftStatus] = [:]

        for profile in live {
            if let reason = brokenReason(for: profile) {
                result[profile.name] = .broken(reason: reason)
            } else if let recorded = manifest.snapshot(named: profile.name) {
                result[profile.name] = recorded == ProfileSnapshot(from: profile) ? .ok : .modified
            } else {
                result[profile.name] = .untracked
            }
        }

        for name in manifestNames where liveByName[name] == nil {
            result[name] = .removed
        }

        return result
    }

    /// Record the live profiles as the manifest baseline (everything becomes ok).
    /// Group assignments are preserved.
    public func adopt(live: [Profile]) {
        var manifest = store.load()
        manifest.profiles = live.map(ProfileSnapshot.init)
        store.save(manifest)
    }

    // MARK: - Group assignments

    /// Current name → group assignments (only profiles with a manual group).
    public func groups() -> [String: String] {
        store.load().groups
    }

    /// Assign (or, with nil/empty, clear) a profile's display group.
    public func setGroup(_ group: String?, for name: String) {
        var manifest = store.load()
        if let group, !group.trimmingCharacters(in: .whitespaces).isEmpty {
            manifest.groups[name] = group.trimmingCharacters(in: .whitespaces)
        } else {
            manifest.groups[name] = nil
        }
        store.save(manifest)
    }

    /// Update a single profile's baseline after the app writes it.
    public func record(_ profile: Profile) {
        var manifest = store.load()
        manifest.profiles.removeAll { $0.name == profile.name }
        manifest.profiles.append(ProfileSnapshot(from: profile))
        store.save(manifest)
    }

    /// Drop a profile from the baseline (and its group) after the app deletes it.
    public func forget(named name: String) {
        var manifest = store.load()
        manifest.profiles.removeAll { $0.name == name }
        manifest.groups[name] = nil
        store.save(manifest)
    }

    /// A usable SSO profile needs a resolvable start URL plus account and role.
    private func brokenReason(for profile: Profile) -> String? {
        guard profile.isSSO else { return nil }
        if profile.ssoStartURL == nil { return "SSO session has no start URL" }
        if profile.accountId == nil { return "Missing account ID" }
        if profile.roleName == nil { return "Missing role name" }
        return nil
    }
}
