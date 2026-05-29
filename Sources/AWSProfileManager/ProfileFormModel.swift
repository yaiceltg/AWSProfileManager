import Foundation
import Observation
import AWSProfileKit

/// Editable state for the add/edit profile sheet. Builds a `Profile`; the
/// repository resolves/creates the sso-session from the start URL on save.
@Observable
@MainActor
final class ProfileFormModel: Identifiable {
    let id = UUID()
    let isNew: Bool
    let originalName: String?

    var name: String = ""
    /// App-only display group (empty = automatic by prefix). Persisted in the manifest, not the config.
    var group: String = ""
    // config
    var accountId: String = ""
    var roleName: String = ""
    var region: String = ""
    // sso-session
    var ssoStartURL: String = ""
    var ssoRegion: String = ""
    // credentials
    var accessKeyId: String = ""
    var secretAccessKey: String = ""
    var sessionToken: String = ""

    init() {
        isNew = true
        originalName = nil
    }

    init(editing profile: Profile) {
        isNew = false
        originalName = profile.name
        name = profile.name
        accountId = profile.accountId ?? ""
        roleName = profile.roleName ?? ""
        region = profile.region ?? ""
        ssoStartURL = profile.ssoStartURL ?? ""
        ssoRegion = profile.ssoRegion ?? ""
        accessKeyId = profile.accessKeyId ?? ""
        secretAccessKey = profile.secretAccessKey ?? ""
        sessionToken = profile.sessionToken ?? ""
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func build() -> Profile {
        Profile(
            name: name.trimmingCharacters(in: .whitespaces),
            accountId: blankToNil(accountId),
            roleName: blankToNil(roleName),
            region: blankToNil(region),
            ssoStartURL: blankToNil(ssoStartURL),
            ssoRegion: blankToNil(ssoRegion),
            accessKeyId: blankToNil(accessKeyId),
            secretAccessKey: blankToNil(secretAccessKey),
            sessionToken: blankToNil(sessionToken)
        )
    }

    private func blankToNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
}
