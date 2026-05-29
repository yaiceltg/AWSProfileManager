import Foundation
import Observation
import AWSProfileKit

/// Drives the profile list. Owns no business rules — it composes use cases and
/// exposes render-ready state to SwiftUI.
@Observable
@MainActor
final class ProfileViewModel {
    private(set) var groups: [LoadProfileGroups.ResolvedGroup] = []
    private(set) var defaultProfileName: String?
    private(set) var errorMessage: String?
    private(set) var lastBackupPath: String?

    /// Session names currently mid-login, so the UI can show progress.
    private(set) var refreshingSessions: Set<String> = []

    private let loadGroups: LoadProfileGroups
    private let setDefaultProfile: SetDefaultProfile
    private let refreshSession: RefreshSSOSession
    private let resolveBrowser: ResolveSelectedBrowser

    init(
        loadGroups: LoadProfileGroups,
        setDefaultProfile: SetDefaultProfile,
        refreshSession: RefreshSSOSession,
        resolveBrowser: ResolveSelectedBrowser
    ) {
        self.loadGroups = loadGroups
        self.setDefaultProfile = setDefaultProfile
        self.refreshSession = refreshSession
        self.resolveBrowser = resolveBrowser
    }

    func reload() {
        do {
            let result = try loadGroups(now: Date())
            groups = result.groups
            defaultProfileName = result.defaultProfileName
            errorMessage = nil
        } catch {
            errorMessage = "No se pudo leer ~/.aws/config: \(error.localizedDescription)"
        }
    }

    func makeDefault(profileNamed name: String) {
        do {
            let backup = try setDefaultProfile(profileNamed: name)
            lastBackupPath = backup.path
            errorMessage = nil
            reload()
        } catch {
            errorMessage = "No se pudo cambiar el default: \(error.localizedDescription)"
        }
    }

    func refresh(sessionNamed name: String) async {
        refreshingSessions.insert(name)
        defer { refreshingSessions.remove(name) }
        let browser = resolveBrowser()
        do {
            try await refreshSession(sessionNamed: name, browser: browser)
            errorMessage = nil
            reload()
        } catch let AWSCommandError.nonZeroExit(_, stderr) {
            errorMessage = "El login SSO falló: \(stderr.isEmpty ? "código de salida distinto de cero" : stderr)"
        } catch AWSCommandError.binaryNotFound {
            errorMessage = "No se encontró el binario `aws`. Instalá AWS CLI v2 o definí AWS_CLI_PATH."
        } catch {
            errorMessage = "El login SSO falló: \(error.localizedDescription)"
        }
    }

    func isRefreshing(sessionNamed name: String) -> Bool {
        refreshingSessions.contains(name)
    }
}
