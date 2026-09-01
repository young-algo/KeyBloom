import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        GameCoordinator.shared.refreshAccessibilityPermission()
    }

    func applicationDidResignActive(_ notification: Notification) {
        GameCoordinator.shared.reclaimFocusIfNeeded()
    }

    func applicationDidChangeScreenParameters(_ notification: Notification) {
        GameCoordinator.shared.reclaimFocusIfNeeded()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !GameCoordinator.shared.isRunning
    }
}
