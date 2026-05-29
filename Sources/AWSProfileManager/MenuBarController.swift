import SwiftUI
import AppKit
import AWSProfileKit

/// App lifecycle + the menu bar status item. Owns the status item and a popover
/// hosting the SwiftUI panel. Stays running when the main window closes so the
/// menu bar item persists.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Set by the App during init (composition root lives in the App struct).
    var model: AppModel?
    /// Registered by the main window so the popular can reopen it.
    var openMainWindow: (() -> Void)?

    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if let url = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = icon
        }

        if let model {
            statusBar = StatusBarController(model: model) { [weak self] in
                self?.showMainWindow()
            }
        }
    }

    /// Keep running in the menu bar when the last window closes.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Reopen the window when the Dock icon is clicked with no window visible.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showMainWindow() }
        return true
    }

    func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        openMainWindow?()
    }
}

/// Manages the `NSStatusItem` and its popover.
@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()

    init(model: AppModel, onOpenWindow: @escaping () -> Void) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 320, height: 440)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView(model: model, onOpenWindow: onOpenWindow)
        )

        if let button = statusItem.button {
            let image = NSImage(
                systemSymbolName: "rectangle.stack.fill",
                accessibilityDescription: "AWS Profiles"
            )
            image?.isTemplate = true
            button.image = image
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
