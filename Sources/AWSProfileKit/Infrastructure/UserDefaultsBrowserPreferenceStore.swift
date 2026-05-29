import Foundation

/// `BrowserPreferenceStore` backed by `UserDefaults`.
///
/// `@unchecked Sendable`: `UserDefaults` is documented thread-safe but does not
/// conform to `Sendable`; the only stored state is that thread-safe reference.
public struct UserDefaultsBrowserPreferenceStore: BrowserPreferenceStore, @unchecked Sendable {
    private static let key = "selectedBrowserID"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func selectedBrowserID() -> String? {
        defaults.string(forKey: Self.key)
    }

    public func setSelectedBrowserID(_ id: String?) {
        if let id {
            defaults.set(id, forKey: Self.key)
        } else {
            defaults.removeObject(forKey: Self.key)
        }
    }
}
