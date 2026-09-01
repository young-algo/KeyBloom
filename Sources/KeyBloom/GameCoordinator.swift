import AppKit
import CoreGraphics
import Foundation
import SwiftUI

final class GameCoordinator: ObservableObject {
    static let shared = GameCoordinator()

    let model = GameModel()

    @Published var palette: BloomPalette {
        didSet { defaults.set(palette.rawValue, forKey: Keys.palette) }
    }

    @Published var showLabels: Bool {
        didSet { defaults.set(showLabels, forKey: Keys.showLabels) }
    }

    @Published var calmMotion: Bool {
        didSet { defaults.set(calmMotion, forKey: Keys.calmMotion) }
    }

    @Published var strongLock: Bool {
        didSet { defaults.set(strongLock, forKey: Keys.strongLock) }
    }

    @Published private(set) var accessibilityPermissionGranted: Bool
    @Published private(set) var isRunning = false
    @Published var statusMessage: String?

    private let defaults: UserDefaults
    private var setupWindows: [NSWindow] = []
    private var kioskWindows: [KioskWindow] = []
    private weak var primaryWindow: KioskWindow?
    private var previousPresentationOptions: NSApplication.PresentationOptions = []
    private var localEventMonitor: Any?
    private var strictEventTap: StrictEventTap?
    private var cursorIsHidden = false

    private var pressedKeyCodes = Set<UInt16>()
    private var chordAlreadyCelebrated = false
    private var lastRepeatTimeByKey: [UInt16: TimeInterval] = [:]
    private var unlockWorkItem: DispatchWorkItem?
    private var heldExitKeys = Set<UInt16>()
    private var exitModifiersHeld = false

    private enum Keys {
        static let palette = "palette"
        static let showLabels = "showLabels"
        static let calmMotion = "calmMotion"
        static let strongLock = "strongLock"
    }

    private init() {
        let defaults = UserDefaults.standard
        self.defaults = defaults
        palette = BloomPalette(rawValue: defaults.string(forKey: Keys.palette) ?? "") ?? .rainbow
        showLabels = defaults.object(forKey: Keys.showLabels) as? Bool ?? true
        calmMotion = defaults.object(forKey: Keys.calmMotion) as? Bool ?? true
        strongLock = defaults.object(forKey: Keys.strongLock) as? Bool ?? true
        accessibilityPermissionGranted = StrictEventTap.hasAccessibilityPermission(prompt: false)
    }

    func refreshAccessibilityPermission() {
        accessibilityPermissionGranted = StrictEventTap.hasAccessibilityPermission(prompt: false)
        if accessibilityPermissionGranted,
           statusMessage?.contains("Accessibility") == true {
            statusMessage = nil
        }
    }

    func requestAccessibilityPermission() {
        accessibilityPermissionGranted = StrictEventTap.hasAccessibilityPermission(prompt: true)

        if accessibilityPermissionGranted {
            statusMessage = nil
        } else {
            statusMessage = "In System Settings, enable KeyBloom under Privacy & Security → Accessibility. Then return here and press Start again."
        }
    }

    func startBabyMode() {
        guard !isRunning else { return }
        statusMessage = nil
        refreshAccessibilityPermission()

        if strongLock, !accessibilityPermissionGranted {
            requestAccessibilityPermission()
            return
        }

        let systemPrefersCalm = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        model.reset(
            palette: palette,
            showLabels: showLabels,
            calmMotion: calmMotion || systemPrefersCalm
        )
        pressedKeyCodes.removeAll(keepingCapacity: true)
        lastRepeatTimeByKey.removeAll(keepingCapacity: true)
        chordAlreadyCelebrated = false
        cancelUnlockHold()
        heldExitKeys.removeAll(keepingCapacity: true)
        exitModifiersHeld = false

        setupWindows = NSApp.windows.filter { !($0 is KioskWindow) }
        previousPresentationOptions = NSApp.presentationOptions
        isRunning = true

        createKioskWindows()
        applyKioskPresentation()

        let inputStarted: Bool
        if strongLock {
            let tap = StrictEventTap(coordinator: self)
            inputStarted = tap.start()
            if inputStarted {
                strictEventTap = tap
            }
        } else {
            installLocalEventMonitor()
            inputStarted = localEventMonitor != nil
        }

        guard inputStarted else {
            rollbackFailedStart()
            statusMessage = "KeyBloom could not start its input lock. Re-enable Accessibility permission, or turn off Strong lock and use Standard lock."
            return
        }

        setupWindows.forEach { $0.orderOut(nil) }
        hideCursor()
        bringKioskToFront()
    }

    func quitFromSetup() {
        NSApp.terminate(nil)
    }

    func reclaimFocusIfNeeded() {
        guard isRunning else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
            guard let self, self.isRunning else { return }
            NSApp.activate(ignoringOtherApps: true)
            self.primaryWindow?.makeKeyAndOrderFront(nil)
            self.kioskWindows.forEach { $0.orderFrontRegardless() }
        }
    }

    // MARK: - Standard-lock input

    private func installLocalEventMonitor() {
        let mask: NSEvent.EventTypeMask = [
            .keyDown,
            .keyUp,
            .flagsChanged,
            .leftMouseDown,
            .rightMouseDown,
            .otherMouseDown,
            .leftMouseDragged,
            .rightMouseDragged,
            .otherMouseDragged,
            .scrollWheel
        ]

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            guard let self, self.isRunning else { return event }
            self.handleLocalEvent(event)
            return nil
        }
    }

    private func handleLocalEvent(_ event: NSEvent) {
        switch event.type {
        case .keyDown:
            handleKeyDown(
                keyCode: event.keyCode,
                label: displayLabel(from: event),
                isRepeat: event.isARepeat,
                hasExitModifiers: hasExitModifiers(event.modifierFlags),
                hasEmergencyExitModifiers: hasEmergencyExitModifiers(event.modifierFlags)
            )

        case .keyUp:
            handleKeyUp(keyCode: event.keyCode, hasExitModifiers: hasExitModifiers(event.modifierFlags))

        case .flagsChanged:
            handleFlagsChanged(
                keyCode: event.keyCode,
                hasExitModifiers: hasExitModifiers(event.modifierFlags),
                modifierIsPressed: modifierIsPressed(keyCode: event.keyCode, flags: event.modifierFlags)
            )

        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            handleLocalPointer(event)

        case .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            handleLocalDrag(event)

        case .scrollWheel:
            handleScroll(delta: event.scrollingDeltaY)

        default:
            break
        }
    }

    // MARK: - Strong-lock input

    func handleStrictKeyDown(keyCode: UInt16, flags: CGEventFlags, isRepeat: Bool) {
        guard isRunning else { return }
        handleKeyDown(
            keyCode: keyCode,
            label: KeyboardLayout.label(for: keyCode),
            isRepeat: isRepeat,
            hasExitModifiers: hasExitModifiers(flags),
            hasEmergencyExitModifiers: hasEmergencyExitModifiers(flags)
        )
    }

    func handleStrictKeyUp(keyCode: UInt16, flags: CGEventFlags) {
        guard isRunning else { return }
        handleKeyUp(keyCode: keyCode, hasExitModifiers: hasExitModifiers(flags))
    }

    func handleStrictFlagsChanged(keyCode: UInt16, flags: CGEventFlags) {
        guard isRunning else { return }
        handleFlagsChanged(
            keyCode: keyCode,
            hasExitModifiers: hasExitModifiers(flags),
            modifierIsPressed: modifierIsPressed(keyCode: keyCode, flags: flags)
        )
    }

    func handleGlobalPointer(_ point: CGPoint) {
        guard isRunning else { return }
        guard let bounds = displayBounds(containing: point) else { return }

        let normalized = CGPoint(
            x: (point.x - bounds.minX) / bounds.width,
            y: (point.y - bounds.minY) / bounds.height
        )
        model.registerPointer(normalizedPosition: normalized)
    }

    func handleGlobalDrag(_ point: CGPoint) {
        guard isRunning, let bounds = displayBounds(containing: point) else { return }
        model.registerDrag(normalizedPosition: CGPoint(
            x: (point.x - bounds.minX) / bounds.width,
            y: (point.y - bounds.minY) / bounds.height
        ))
    }

    func handleScroll(delta: CGFloat) {
        guard isRunning, abs(delta) > 0.01 else { return }
        model.registerScroll(direction: delta)
    }

    // MARK: - Shared input behavior

    private func handleKeyDown(
        keyCode: UInt16,
        label: String,
        isRepeat: Bool,
        hasExitModifiers: Bool,
        hasEmergencyExitModifiers: Bool
    ) {
        exitModifiersHeld = hasExitModifiers
        if AppConfig.isExitKey(keyCode) {
            heldExitKeys.insert(keyCode)
            // Order-independent: the chord completes whenever an exit key and all four
            // modifiers are down, regardless of which was pressed first.
            if hasExitModifiers {
                evaluateExitChord()
                return
            }
            if keyCode == AppConfig.escapeKeyCode, hasEmergencyExitModifiers {
                stopAndTerminate()
                return
            }
            // Incomplete chord — fall through to bloom, but keep chord state in sync.
            evaluateExitChord()
        } else {
            if model.unlockStartedAt != nil {
                cancelUnlockHold()
            }
        }

        pressedKeyCodes.insert(keyCode)

        let now = ProcessInfo.processInfo.systemUptime
        if isRepeat {
            let previous = lastRepeatTimeByKey[keyCode] ?? 0
            guard now - previous >= AppConfig.repeatKeyMinimumInterval else { return }
        }
        lastRepeatTimeByKey[keyCode] = now

        model.registerKey(keyCode: keyCode, label: label, isRepeat: isRepeat)

        if pressedKeyCodes.count >= 3, !chordAlreadyCelebrated {
            model.registerChord(keyCount: pressedKeyCodes.count)
            chordAlreadyCelebrated = true
        }
    }

    private func handleKeyUp(keyCode: UInt16, hasExitModifiers: Bool) {
        exitModifiersHeld = hasExitModifiers
        heldExitKeys.remove(keyCode)
        evaluateExitChord()

        pressedKeyCodes.remove(keyCode)
        lastRepeatTimeByKey.removeValue(forKey: keyCode)

        if pressedKeyCodes.count < 3 {
            chordAlreadyCelebrated = false
        }
    }

    private func handleFlagsChanged(
        keyCode: UInt16,
        hasExitModifiers: Bool,
        modifierIsPressed: Bool
    ) {
        exitModifiersHeld = hasExitModifiers
        evaluateExitChord()

        if modifierIsPressed {
            model.registerModifier(keyCode: keyCode)
        }
    }

    private func evaluateExitChord() {
        let shouldHold = !heldExitKeys.isEmpty && exitModifiersHeld
        if shouldHold {
            beginUnlockHold()
        } else if model.unlockStartedAt != nil {
            cancelUnlockHold()
        }
    }

    private func beginUnlockHold() {
        guard unlockWorkItem == nil else { return }

        model.unlockStartedAt = Date()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.isRunning, self.model.unlockStartedAt != nil else { return }
            self.stopAndTerminate()
        }
        unlockWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + AppConfig.exitHoldDuration,
            execute: workItem
        )
    }

    private func cancelUnlockHold() {
        unlockWorkItem?.cancel()
        unlockWorkItem = nil
        model.unlockStartedAt = nil
    }

    // MARK: - Window and lifecycle management

    private func createKioskWindows() {
        kioskWindows = NSScreen.screens.map { screen in
            let window = KioskWindow(screen: screen)
            window.contentView = NSHostingView(rootView: GameView(model: model))
            window.orderFrontRegardless()
            return window
        }

        let mainFrame = NSScreen.main?.frame
        primaryWindow = kioskWindows.first { $0.screen?.frame == mainFrame } ?? kioskWindows.first
    }

    private func applyKioskPresentation() {
        NSApp.presentationOptions = [
            .hideDock,
            .hideMenuBar,
            .disableAppleMenu,
            .disableProcessSwitching,
            .disableHideApplication
        ]
    }

    private func bringKioskToFront() {
        NSApp.activate(ignoringOtherApps: true)
        kioskWindows.forEach { $0.orderFrontRegardless() }
        primaryWindow?.makeKeyAndOrderFront(nil)
    }

    private func stopAndTerminate() {
        guard isRunning else { return }
        isRunning = false
        cancelUnlockHold()
        removeInputCapture()
        restoreCursor()
        NSApp.presentationOptions = previousPresentationOptions
        kioskWindows.forEach { $0.close() }
        kioskWindows.removeAll()
        NSApp.terminate(nil)
    }

    private func rollbackFailedStart() {
        isRunning = false
        cancelUnlockHold()
        removeInputCapture()
        restoreCursor()
        NSApp.presentationOptions = previousPresentationOptions
        kioskWindows.forEach { $0.close() }
        kioskWindows.removeAll()
        setupWindows.forEach {
            $0.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func removeInputCapture() {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        strictEventTap?.stop()
        strictEventTap = nil
    }

    private func hideCursor() {
        guard !cursorIsHidden else { return }
        NSCursor.hide()
        cursorIsHidden = true
    }

    private func restoreCursor() {
        guard cursorIsHidden else { return }
        NSCursor.unhide()
        cursorIsHidden = false
    }

    // MARK: - Helpers

    private func handleLocalPointer(_ event: NSEvent) {
        guard let normalized = normalizedLocalPosition(for: event) else { return }
        model.registerPointer(normalizedPosition: normalized)
    }

    private func handleLocalDrag(_ event: NSEvent) {
        guard let normalized = normalizedLocalPosition(for: event) else { return }
        model.registerDrag(normalizedPosition: normalized)
    }

    private func normalizedLocalPosition(for event: NSEvent) -> CGPoint? {
        guard let window = event.window ?? primaryWindow,
              let contentView = window.contentView,
              contentView.bounds.width > 0,
              contentView.bounds.height > 0 else {
            return nil
        }

        let point = event.locationInWindow
        return CGPoint(
            x: point.x / contentView.bounds.width,
            y: 1.0 - (point.y / contentView.bounds.height)
        )
    }

    private func displayBounds(containing point: CGPoint) -> CGRect? {
        var display = CGMainDisplayID()
        var found = CGDirectDisplayID(0)
        var matches: UInt32 = 0
        if CGGetDisplaysWithPoint(point, 1, &found, &matches) == .success, matches > 0 {
            display = found
        }
        let bounds = CGDisplayBounds(display)
        return bounds.width > 0 && bounds.height > 0 ? bounds : nil
    }

    private func displayLabel(from event: NSEvent) -> String {
        guard let characters = event.charactersIgnoringModifiers,
              characters.count == 1,
              let scalar = characters.unicodeScalars.first,
              !CharacterSet.controlCharacters.contains(scalar) else {
            return KeyboardLayout.label(for: event.keyCode)
        }
        return characters.uppercased()
    }

    private func hasExitModifiers(_ flags: NSEvent.ModifierFlags) -> Bool {
        flags.contains(.control)
            && flags.contains(.option)
            && flags.contains(.shift)
            && flags.contains(.command)
    }

    private func hasExitModifiers(_ flags: CGEventFlags) -> Bool {
        flags.contains(.maskControl)
            && flags.contains(.maskAlternate)
            && flags.contains(.maskShift)
            && flags.contains(.maskCommand)
    }

    private func hasEmergencyExitModifiers(_ flags: NSEvent.ModifierFlags) -> Bool {
        flags.contains(.option) && flags.contains(.command)
    }

    private func hasEmergencyExitModifiers(_ flags: CGEventFlags) -> Bool {
        flags.contains(.maskAlternate) && flags.contains(.maskCommand)
    }

    private func modifierIsPressed(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        switch keyCode {
        case 54, 55:
            return flags.contains(.command)
        case 56, 60:
            return flags.contains(.shift)
        case 58, 61:
            return flags.contains(.option)
        case 59, 62:
            return flags.contains(.control)
        case 57:
            return flags.contains(.capsLock)
        case 63:
            return flags.contains(.function)
        default:
            return false
        }
    }

    private func modifierIsPressed(keyCode: UInt16, flags: CGEventFlags) -> Bool {
        switch keyCode {
        case 54, 55:
            return flags.contains(.maskCommand)
        case 56, 60:
            return flags.contains(.maskShift)
        case 58, 61:
            return flags.contains(.maskAlternate)
        case 59, 62:
            return flags.contains(.maskControl)
        case 57:
            return flags.contains(.maskAlphaShift)
        case 63:
            return flags.contains(.maskSecondaryFn)
        default:
            return false
        }
    }
}
