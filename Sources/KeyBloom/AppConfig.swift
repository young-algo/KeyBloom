import Foundation

/// Centralized settings that are useful to tweak without touching the rest of the app.
enum AppConfig {
    static let displayName = "KeyBloom"

    /// Adult-only exit: hold Control + Option + Shift + Command + one exit key.
    ///
    /// Escape is kept for the emergency path, but it is NOT reliable as part of the
    /// four-modifier chord: once Command + Option are held, macOS routes Escape to its
    /// own Force Quit handler and the key event is never delivered to this app. Delete
    /// and Backslash have no system binding under these modifiers, so the chord
    /// actually reaches us.
    static let exitHoldDuration: TimeInterval = 1.5
    static let escapeKeyCode: UInt16 = 53
    static let deleteKeyCode: UInt16 = 51
    static let backslashKeyCode: UInt16 = 42

    /// Any of these, held with all four modifiers, starts the unlock countdown.
    static let exitKeyCodes: Set<UInt16> = [deleteKeyCode, backslashKeyCode, escapeKeyCode]

    static func isExitKey(_ keyCode: UInt16) -> Bool {
        exitKeyCodes.contains(keyCode)
    }

    /// Visual limits keep long key holds responsive without allowing an unbounded scene.
    static let maximumBursts = 84
    static let burstLifetime: TimeInterval = 3.4
    static let repeatKeyMinimumInterval: TimeInterval = 0.065
}
