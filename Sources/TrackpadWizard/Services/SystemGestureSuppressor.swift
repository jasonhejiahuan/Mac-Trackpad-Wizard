import ApplicationServices
import Foundation

/// Process-scoped suppression for gesture events while Enhanced Mode is active.
/// The event tap is owned by this process, so macOS removes it automatically if
/// the app crashes or is force-quit. No trackpad preferences are modified.
final class SystemGestureSuppressor: @unchecked Sendable {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let touchCountLock = NSLock()
    private var activeEnhancedTouchCount = 0
    private var isSuppressingTrackpadDrag = false

    private(set) var isActive = false
    private(set) var lastError: String?

    @discardableResult
    func start() -> Bool {
        stop()
        guard AXIsProcessTrusted() else {
            lastError = "Accessibility access is required to suppress system gestures."
            return false
        }

        let mask = Self.observedEventTypes.reduce(CGEventMask(0)) { partial, rawValue in
            partial | (CGEventMask(1) << CGEventMask(rawValue))
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: systemGestureEventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            lastError = "macOS did not allow a gesture-filtering event tap."
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        runLoopSource = source
        isActive = true
        lastError = nil
        return true
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isActive = false
        isSuppressingTrackpadDrag = false
    }

    func updateEnhancedTouchCount(_ count: Int) {
        touchCountLock.lock()
        activeEnhancedTouchCount = max(0, count)
        touchCountLock.unlock()
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        if type == .scrollWheel {
            let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
            return isContinuous ? nil : Unmanaged.passUnretained(event)
        }

        if type == .leftMouseDown, enhancedTouchCount >= 3 {
            isSuppressingTrackpadDrag = true
            return nil
        }
        if type == .leftMouseDragged,
           isSuppressingTrackpadDrag || enhancedTouchCount >= 3 {
            isSuppressingTrackpadDrag = true
            return nil
        }
        if type == .leftMouseUp, isSuppressingTrackpadDrag {
            isSuppressingTrackpadDrag = false
            return nil
        }

        return Self.gestureEventTypes.contains(type.rawValue)
            ? nil
            : Unmanaged.passUnretained(event)
    }

    private var enhancedTouchCount: Int {
        touchCountLock.lock()
        defer { touchCountLock.unlock() }
        return activeEnhancedTouchCount
    }

    private static let gestureEventTypes: Set<UInt32> = [
        CGEventType.scrollWheel.rawValue,
        18, // NSEvent.EventType.rotate
        29, // NSEvent.EventType.gesture
        30, // NSEvent.EventType.magnify
        31, // NSEvent.EventType.swipe
        32  // NSEvent.EventType.smartMagnify
    ]

    private static let observedEventTypes = gestureEventTypes.union([
        CGEventType.leftMouseDown.rawValue,
        CGEventType.leftMouseUp.rawValue,
        CGEventType.leftMouseDragged.rawValue
    ])
}

private let systemGestureEventCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let suppressor = Unmanaged<SystemGestureSuppressor>.fromOpaque(userInfo).takeUnretainedValue()
    return suppressor.handle(type: type, event: event)
}
