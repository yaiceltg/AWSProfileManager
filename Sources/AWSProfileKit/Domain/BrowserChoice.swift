import Foundation

/// A browser the user can pick to open the SSO authorization page.
///
/// `id` is a stable identifier (bundle identifier when available); `appPath`
/// is the concrete `.app` location used to launch it via `open -a`.
public struct BrowserChoice: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let appPath: String

    public init(id: String, name: String, appPath: String) {
        self.id = id
        self.name = name
        self.appPath = appPath
    }
}
