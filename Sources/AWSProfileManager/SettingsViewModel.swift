import Foundation
import Observation
import AWSProfileKit

/// Backs the Settings window: lists installed browsers and persists the choice.
@Observable
@MainActor
final class SettingsViewModel {
    private(set) var browsers: [BrowserChoice] = []

    /// nil = use the system default browser. Persisted on change.
    var selectedID: String? {
        didSet { store.setSelectedBrowserID(selectedID) }
    }

    private let provider: BrowserProvider
    private let store: BrowserPreferenceStore

    init(provider: BrowserProvider, store: BrowserPreferenceStore) {
        self.provider = provider
        self.store = store
        // Assignments in init do not trigger didSet, so no redundant write here.
        self.selectedID = store.selectedBrowserID()
        self.browsers = provider.availableBrowsers()
    }

    func reload() {
        browsers = provider.availableBrowsers()
        // Drop a stale selection whose browser is no longer installed.
        if let id = selectedID, !browsers.contains(where: { $0.id == id }) {
            selectedID = nil
        }
    }
}
