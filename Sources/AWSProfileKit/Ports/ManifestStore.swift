import Foundation

/// Persists the app's profile manifest (names + non-secret snapshot).
public protocol ManifestStore: Sendable {
    func load() -> ProfileManifest
    func save(_ manifest: ProfileManifest)
}
