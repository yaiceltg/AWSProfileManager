import Foundation

/// Persists which browser the user chose for SSO login.
///
/// A nil id means "use the system default browser" (the CLI's own behavior).
public protocol BrowserPreferenceStore: Sendable {
    func selectedBrowserID() -> String?
    func setSelectedBrowserID(_ id: String?)
}
