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
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

/// Composition root: the single place that picks concrete adapters and wires
/// them into use cases. Swap any adapter here without touching domain or UI.
@main
struct AWSProfileManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var viewModel: ProfileViewModel
    @State private var settingsViewModel: SettingsViewModel

    init() {
        let paths = AWSPaths.default
        let repository = FileProfileRepository(paths: paths)
        let tokenReader = SSOCacheReader(paths: paths)
        let runner = ProcessCommandRunner()
        let browserProvider = NSWorkspaceBrowserProvider()
        let preferenceStore = UserDefaultsBrowserPreferenceStore()

        _viewModel = State(initialValue: ProfileViewModel(
            loadGroups: LoadProfileGroups(repository: repository, tokenReader: tokenReader),
            setDefaultProfile: SetDefaultProfile(repository: repository),
            refreshSession: RefreshSSOSession(runner: runner),
            resolveBrowser: ResolveSelectedBrowser(store: preferenceStore, provider: browserProvider)
        ))
        _settingsViewModel = State(initialValue: SettingsViewModel(
            provider: browserProvider,
            store: preferenceStore
        ))
    }

    var body: some Scene {
        WindowGroup("AWS Profiles") {
            ContentView(viewModel: viewModel)
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView(model: settingsViewModel)
        }
    }
}
