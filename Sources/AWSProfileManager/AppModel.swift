import Foundation
import Observation
import AppKit
import AWSProfileKit

/// Coordinates the whole app: loads the overview, drives CRUD, refresh, default
/// switching, drift sync, and browser settings. Owns no business rules — it
/// composes use cases and exposes render-ready state to SwiftUI.
@Observable
@MainActor
final class AppModel {
    // MARK: Navigation
    enum Selection: Hashable {
        case profile(String)
        case settings
    }
    var selection: Selection?
    var searchText: String = ""

    // MARK: Data
    private(set) var groups: [ProfileDisplayGroup] = []
    private(set) var profilesByName: [String: Profile] = [:]
    private(set) var tokenStatusBySession: [String: TokenStatus] = [:]
    private(set) var driftByName: [String: DriftStatus] = [:]
    private(set) var defaultProfileName: String?
    private(set) var errorMessage: String?

    // MARK: Transient UI state
    private(set) var refreshingProfiles: Set<String> = []
    private(set) var openingConsole: Set<String> = []
    private(set) var identityByName: [String: VerifyState] = [:]
    var activeLogin: LoginSession?
    var editing: ProfileFormModel?

    /// Result of a `get-caller-identity` verification for a profile.
    enum VerifyState: Equatable {
        case verifying
        case ok(CallerIdentity)
        case failed(String)
    }

    // MARK: Settings
    private(set) var browsers: [BrowserChoice] = []
    var selectedBrowserID: String? {
        didSet { preferenceStore.setSelectedBrowserID(selectedBrowserID) }
    }

    // MARK: Dependencies
    private let loadOverview: LoadOverview
    private let setDefaultProfile: SetDefaultProfile
    private let saveProfileUseCase: SaveProfile
    private let deleteProfileUseCase: DeleteProfile
    private let refreshSession: RefreshSSOSession
    private let getCallerIdentity: GetCallerIdentity
    private let openConsoleUseCase: OpenConsole
    private let resolveBrowser: ResolveSelectedBrowser
    private let sync: SyncManifest
    private let browserProvider: BrowserProvider
    private let preferenceStore: BrowserPreferenceStore

    init(
        loadOverview: LoadOverview,
        setDefaultProfile: SetDefaultProfile,
        saveProfile: SaveProfile,
        deleteProfile: DeleteProfile,
        refreshSession: RefreshSSOSession,
        getCallerIdentity: GetCallerIdentity,
        openConsole: OpenConsole,
        resolveBrowser: ResolveSelectedBrowser,
        sync: SyncManifest,
        browserProvider: BrowserProvider,
        preferenceStore: BrowserPreferenceStore
    ) {
        self.loadOverview = loadOverview
        self.setDefaultProfile = setDefaultProfile
        self.saveProfileUseCase = saveProfile
        self.deleteProfileUseCase = deleteProfile
        self.refreshSession = refreshSession
        self.getCallerIdentity = getCallerIdentity
        self.openConsoleUseCase = openConsole
        self.resolveBrowser = resolveBrowser
        self.sync = sync
        self.browserProvider = browserProvider
        self.preferenceStore = preferenceStore
        self.selectedBrowserID = preferenceStore.selectedBrowserID()
        self.browsers = browserProvider.availableBrowsers()
    }

    // MARK: Loading

    func reload() {
        do {
            let result = try loadOverview(now: Date())
            groups = result.groups
            profilesByName = Dictionary(uniqueKeysWithValues: result.profiles.map { ($0.name, $0) })
            tokenStatusBySession = result.tokenStatusBySession
            driftByName = result.driftByName
            defaultProfileName = result.defaultProfileName
            errorMessage = nil
        } catch {
            errorMessage = "Could not read ~/.aws/config: \(error.localizedDescription)"
        }
    }

    /// Groups filtered by the search text (matches group title, key, or display name).
    var filteredGroups: [ProfileDisplayGroup] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return groups }
        return groups.compactMap { group in
            let items = group.items.filter {
                $0.profile.name.lowercased().contains(query)
                    || $0.displayName.lowercased().contains(query)
                    || group.title.lowercased().contains(query)
            }
            return items.isEmpty ? nil : ProfileDisplayGroup(title: group.title, items: items)
        }
    }

    func profile(named name: String) -> Profile? { profilesByName[name] }

    func tokenStatus(for profile: Profile) -> TokenStatus {
        guard let session = profile.ssoSessionName else { return .unknown }
        return tokenStatusBySession[session] ?? .unknown
    }

    func drift(for name: String) -> DriftStatus { driftByName[name] ?? .untracked }

    var isDefault: (String) -> Bool { { [defaultProfileName] in $0 == defaultProfileName } }

    // MARK: Actions

    func makeDefault(profileNamed name: String) {
        run { try setDefaultProfile(profileNamed: name); reload() }
    }

    func refresh(profileNamed name: String) async {
        refreshingProfiles.insert(name)
        activeLogin = LoginSession(profileName: name, phase: .starting)
        let browser = resolveBrowser()
        defer { refreshingProfiles.remove(name) }

        do {
            try await refreshSession(profileNamed: name, browser: browser) { prompt in
                Task { @MainActor [weak self] in
                    guard let self, self.activeLogin?.profileName == name else { return }
                    self.activeLogin?.phase = .prompt(prompt)
                }
            }
            if activeLogin?.profileName == name { activeLogin?.phase = .success }
            reload()
        } catch let AWSCommandError.nonZeroExit(_, stderr) {
            failLogin(name, message: stderr.isEmpty ? "Login exited with a non-zero status." : stderr)
        } catch AWSCommandError.binaryNotFound {
            failLogin(name, message: "aws CLI not found. Install AWS CLI v2 or set AWS_CLI_PATH.")
        } catch {
            failLogin(name, message: error.localizedDescription)
        }
    }

    /// Live-verify a profile via get-caller-identity.
    func verify(profileNamed name: String) async {
        identityByName[name] = .verifying
        do {
            let identity = try await getCallerIdentity(profileNamed: name)
            identityByName[name] = .ok(identity)
        } catch let AWSCommandError.nonZeroExit(_, stderr) {
            identityByName[name] = .failed(stderr.isEmpty ? "Verification failed." : stderr)
        } catch AWSCommandError.binaryNotFound {
            identityByName[name] = .failed("aws CLI not found. Install AWS CLI v2 or set AWS_CLI_PATH.")
        } catch {
            identityByName[name] = .failed(error.localizedDescription)
        }
    }

    func identity(for name: String) -> VerifyState? { identityByName[name] }

    /// Open the AWS web console signed in as this profile (federated sign-in).
    func openConsole(profileNamed name: String) async {
        openingConsole.insert(name)
        defer { openingConsole.remove(name) }
        do {
            let region = profilesByName[name]?.region
            let url = try await openConsoleUseCase(profileNamed: name, region: region)
            openInBrowser(url)
            errorMessage = nil
        } catch ConsoleSignInError.requiresTemporaryCredentials {
            errorMessage = "Console sign-in needs temporary credentials. Refresh the SSO session first."
        } catch let AWSCommandError.nonZeroExit(_, stderr) {
            errorMessage = "Could not open console: \(stderr.isEmpty ? "failed to resolve credentials" : stderr)"
        } catch {
            errorMessage = "Could not open console: \(error.localizedDescription)"
        }
    }

    /// Open a URL in the selected browser, or the system default.
    private func openInBrowser(_ url: URL) {
        if let path = resolveBrowser()?.appPath {
            NSWorkspace.shared.open(
                [url], withApplicationAt: URL(fileURLWithPath: path),
                configuration: NSWorkspace.OpenConfiguration()
            )
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    func save(form: ProfileFormModel) {
        let profile = form.build()
        run {
            try saveProfileUseCase(profile)
            sync.setGroup(form.group, for: profile.name)
            sync.setDisplayName(form.displayName, for: profile.name)
            reload()
            if let live = profilesByName[profile.name] { sync.record(live) }
            editing = nil
            selection = .profile(profile.name)
        }
    }

    /// Rename a group, reassigning every profile currently shown under it.
    func renameGroup(from oldTitle: String, to newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != oldTitle,
              let group = groups.first(where: { $0.title == oldTitle })
        else { return }
        sync.renameGroup(to: trimmed, profileNames: group.items.map(\.profile.name))
        reload()
    }

    /// Distinct group titles currently shown, for the form's group picker.
    var existingGroups: [String] {
        Array(Set(groups.map(\.title))).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    func delete(profileNamed name: String) {
        run {
            try deleteProfileUseCase(named: name)
            sync.forget(named: name)
            if selection == .profile(name) { selection = nil }
            reload()
        }
    }

    /// Accept the live config as the new baseline — clears "modified"/"untracked".
    func adoptAll() {
        sync.adopt(live: Array(profilesByName.values))
        reload()
    }

    func refreshBrowsers() {
        browsers = browserProvider.availableBrowsers()
        if let id = selectedBrowserID, !browsers.contains(where: { $0.id == id }) {
            selectedBrowserID = nil
        }
    }

    // MARK: Form helpers

    func beginAdd() { editing = ProfileFormModel() }
    func beginEdit(profileNamed name: String) {
        guard let profile = profilesByName[name] else { return }
        let form = ProfileFormModel(editing: profile)
        form.group = sync.groups()[name] ?? ""
        form.displayName = sync.displayNames()[name] ?? ""
        editing = form
    }

    // MARK: Internals

    private func failLogin(_ name: String, message: String) {
        if activeLogin?.profileName == name { activeLogin?.phase = .failed(message) }
    }

    private func run(_ work: () throws -> Void) {
        do { try work(); errorMessage = nil }
        catch { errorMessage = error.localizedDescription }
    }
}

/// One in-flight SSO login, surfaced as a sheet.
struct LoginSession: Identifiable {
    enum Phase: Equatable {
        case starting
        case prompt(LoginPrompt)
        case success
        case failed(String)
    }
    var id: String { profileName }
    let profileName: String
    var phase: Phase
}
