import ApplicationServices
import CoreGraphics
import Foundation

/// Optional strong-lock input capture. It is enabled only after the user explicitly
/// grants Accessibility permission in macOS System Settings.
final class StrictEventTap {
    private weak var coordinator: GameCoordinator?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(coordinator: GameCoordinator) {
        self.coordinator = coordinator
    }

    static func hasAccessibilityPermission(prompt: Bool) -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func start() -> Bool {
        guard eventTap == nil else { return true }

        let eventTypes: [CGEventType] = [
            .keyDown,
            .keyUp,
            .flagsChanged,
            .leftMouseDown,
            .leftMouseUp,
            .rightMouseDown,
            .rightMouseUp,
            .otherMouseDown,
            .otherMouseUp,
            .mouseMoved,
            .leftMouseDragged,
            .rightMouseDragged,
            .otherMouseDragged,
            .scrollWheel
        ]

        let mask = eventTypes.reduce(CGEventMask(0)) { partial, type in
            partial | (CGEventMask(1) << type.rawValue)
        }

        let opaqueSelf = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: Self.callback,
            userInfo: opaqueSelf
        ) else {
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            return false
        }

        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = eventTap {
            CFMachPortInvalidate(tap)
        }
        runLoopSource = nil
        eventTap = nil
    }

    private static let callback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let controller = Unmanaged<StrictEventTap>
            .fromOpaque(userInfo)
            .takeUnretainedValue()

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = controller.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        controller.handle(type: type, event: event)
        return nil
    }

    private func handle(type: CGEventType, event: CGEvent) {
        guard let coordinator else { return }

        switch type {
        case .keyDown:
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            let flags = event.flags
            DispatchQueue.main.async {
                coordinator.handleStrictKeyDown(keyCode: keyCode, flags: flags, isRepeat: isRepeat)
            }

        case .keyUp:
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags
            DispatchQueue.main.async {
                coordinator.handleStrictKeyUp(keyCode: keyCode, flags: flags)
            }

        case .flagsChanged:
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags
            DispatchQueue.main.async {
                coordinator.handleStrictFlagsChanged(keyCode: keyCode, flags: flags)
            }

        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            let point = event.location
            DispatchQueue.main.async {
                coordinator.handleGlobalPointer(point)
            }

        case .scrollWheel:
            let delta = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)
            DispatchQueue.main.async {
                coordinator.handleScroll(delta: CGFloat(delta))
            }

        default:
            break
        }
    }

    deinit {
        stop()
    }
}
