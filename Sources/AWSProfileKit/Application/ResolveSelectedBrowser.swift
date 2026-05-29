import Foundation

/// Resolves the persisted browser preference into a concrete `BrowserChoice`,
/// or nil when the user wants the system default (or the saved browser is gone).
public struct ResolveSelectedBrowser: Sendable {
    private let store: BrowserPreferenceStore
    private let provider: BrowserProvider

    public init(store: BrowserPreferenceStore, provider: BrowserProvider) {
        self.store = store
        self.provider = provider
    }

    public func callAsFunction() -> BrowserChoice? {
        guard let id = store.selectedBrowserID() else { return nil }
        return provider.availableBrowsers().first { $0.id == id }
    }
}
