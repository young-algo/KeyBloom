import AppKit

final class KioskWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        setFrame(screen.frame, display: true)
        backgroundColor = .black
        isOpaque = true
        hasShadow = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
        animationBehavior = .none
        title = AppConfig.displayName
    }

    override func cancelOperation(_ sender: Any?) {
        // Escape is intentionally treated like every other baby input unless the
        // complete adult unlock chord is held.
    }

    override func performClose(_ sender: Any?) {
        // The window is closed only through GameCoordinator's deliberate unlock path.
    }
}
