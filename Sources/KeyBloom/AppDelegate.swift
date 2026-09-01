import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if ProcessInfo.processInfo.environment["KEYBLOOM_SELF_CHECK"] == "1" {
            do {
                try KeyBloomSelfCheck.run()
                print("KeyBloom self-check passed")
            } catch {
                fputs("KeyBloom self-check failed: \(error.localizedDescription)\n", stderr)
                exit(1)
            }
            NSApp.terminate(nil)
            return
        }

        if let path = ProcessInfo.processInfo.environment["KEYBLOOM_SNAPSHOT_DIR"] {
            Task { @MainActor in
                do {
                    let outputs = try ShowcaseSnapshotRenderer.writeAll(
                        to: URL(fileURLWithPath: path, isDirectory: true)
                    )
                    outputs.forEach { print($0.path) }
                } catch {
                    fputs("KeyBloom snapshot error: \(error.localizedDescription)\n", stderr)
                }
                NSApp.terminate(nil)
            }
        }

        if let value = ProcessInfo.processInfo.environment["KEYBLOOM_PROFILE_SECONDS"],
           let seconds = Double(value), seconds > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
                NSApp.terminate(nil)
            }
        }
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
