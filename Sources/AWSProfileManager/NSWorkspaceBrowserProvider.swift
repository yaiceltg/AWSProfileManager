import AppKit
import AWSProfileKit

/// Detects installed browsers via LaunchServices: every app registered to open
/// http(s) URLs. Lives in the executable target because `NSWorkspace` is AppKit.
struct NSWorkspaceBrowserProvider: BrowserProvider {
    func availableBrowsers() -> [BrowserChoice] {
        guard let probe = URL(string: "https://example.com") else { return [] }

        let appURLs = NSWorkspace.shared.urlsForApplications(toOpen: probe)
        return appURLs
            .map { url -> BrowserChoice in
                let bundleID = Bundle(url: url)?.bundleIdentifier ?? url.path
                let name = FileManager.default
                    .displayName(atPath: url.path)
                    .replacingOccurrences(of: ".app", with: "")
                return BrowserChoice(id: bundleID, name: name, appPath: url.path)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
