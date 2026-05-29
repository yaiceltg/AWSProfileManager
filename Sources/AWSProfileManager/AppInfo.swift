import Foundation

/// App identity and version. Reads the bundled Info.plist when running as an
/// .app, with fallbacks for `swift run` (no bundle).
enum AppInfo {
    static let name = "AWS Profile Manager"

    static let version: String =
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.1"

    static let build: String =
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "2"
}
