import Foundation

/// Supplies the browsers installed on the system that can open http(s) URLs.
///
/// Implemented in the executable target via `NSWorkspace` — detection is a
/// platform detail the domain stays unaware of.
public protocol BrowserProvider: Sendable {
    func availableBrowsers() -> [BrowserChoice]
}
