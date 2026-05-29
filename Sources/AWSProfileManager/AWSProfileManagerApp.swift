import SwiftUI
import AWSProfileKit

/// Composition root: builds the AppModel and hands it to the delegate (which
/// owns the menu bar status item) and the main window. Launched from main.swift.
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

        let appModel = AppModel(
            loadOverview: LoadOverview(repository: repository, tokenReader: tokenReader, sync: sync),
            setDefaultProfile: SetDefaultProfile(repository: repository),
            saveProfile: SaveProfile(repository: repository),
            deleteProfile: DeleteProfile(repository: repository),
            refreshSession: RefreshSSOSession(runner: runner),
            resolveBrowser: ResolveSelectedBrowser(store: preferenceStore, provider: browserProvider),
            sync: sync,
            browserProvider: browserProvider,
            preferenceStore: preferenceStore
        )
        appModel.reload()
        _model = State(initialValue: appModel)

        // The delegate owns the menu bar status item and needs the same model.
        appDelegate.model = appModel
    }

    var body: some Scene {
        WindowGroup("AWS Profiles", id: "main") {
            RootView(model: model)
                .background(WindowOpener(delegate: appDelegate))
        }
    }
}

/// Captures SwiftUI's openWindow action so the menu bar can reopen the window.
private struct WindowOpener: View {
    let delegate: AppDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear { delegate.openMainWindow = { openWindow(id: "main") } }
    }
}
