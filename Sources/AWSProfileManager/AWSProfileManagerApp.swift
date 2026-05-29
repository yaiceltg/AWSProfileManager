import SwiftUI
import AppKit
import AWSProfileKit

/// Promotes the process to a regular foreground app and brings it to front.
///
/// A SwiftUI executable launched outside an `.app` bundle is otherwise treated
/// as a background agent (no window, no Dock icon). The proper distribution fix
/// is bundling; this keeps `swift run` usable during development.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Show the app icon in the Dock even without an .app bundle.
        if let url = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = icon
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

/// Composition root: the single place that picks concrete adapters and wires
/// them into use cases. Swap any adapter here without touching domain or UI.
/// Launched from `main.swift` (after CLI-flag handling), not via `@main`.
struct AWSProfileManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model: AppModel

    init() {
        let paths = AWSPaths.default
        let repository = FileProfileRepository(paths: paths)
        let tokenReader = SSOCacheReader(paths: paths)
        let runner = ProcessCommandRunner()
        let browserProvider = NSWorkspaceBrowserProvider()
        let preferenceStore = UserDefaultsBrowserPreferenceStore()
        let sync = SyncManifest(store: JSONManifestStore())

        _model = State(initialValue: AppModel(
            loadOverview: LoadOverview(repository: repository, tokenReader: tokenReader, sync: sync),
            setDefaultProfile: SetDefaultProfile(repository: repository),
            saveProfile: SaveProfile(repository: repository),
            deleteProfile: DeleteProfile(repository: repository),
            refreshSession: RefreshSSOSession(runner: runner),
            resolveBrowser: ResolveSelectedBrowser(store: preferenceStore, provider: browserProvider),
            sync: sync,
            browserProvider: browserProvider,
            preferenceStore: preferenceStore
        ))
    }

    var body: some Scene {
        WindowGroup("AWS Profiles") {
            RootView(model: model)
        }
    }
}
