import Cocoa
import os

final class HotkeyManager {
    private let logger = Logger(subsystem: "com.parrot", category: "Hotkey")
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var hotkeyKeyCode: UInt16

    var onRecordingStarted: (() -> Void)?
    var onRecordingStopped: (() -> Void)?

    private var hotkeyModifiers: UInt32 = 0

    private var _isHolding = false
    private var _isCapturing = false
    private let stateLock = NSLock()
    private var isHolding: Bool {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _isHolding }
        set { stateLock.lock(); defer { stateLock.unlock() }; _isHolding = newValue }
    }
    private var isCapturing: Bool {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _isCapturing }
        set { stateLock.lock(); defer { stateLock.unlock() }; _isCapturing = newValue }
    }
    /// Tracks modifier flags at capture start so we detect newly pressed modifiers only.
    private var captureBaseFlags: CGEventFlags = []
    /// Modifiers held during capture (for building combos)
    private var captureModifiers: CGEventFlags = []

    init(keyCode: UInt16 = 61, modifiers: UInt32 = 0) { // 61 = Right Option
        self.hotkeyKeyCode = keyCode
        self.hotkeyModifiers = modifiers
    }

    func start() -> Bool {
        guard PermissionsManager.shared.isAccessibilityGranted else {
            logger.error("Accessibility permission not granted")
            ActivityLog.shared.log(.error, category: "Hotkey", message: "Accessibility permission not granted")
            PermissionsManager.shared.requestAccessibilityIfNeeded()
            return false
        }

        let eventMask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)

        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: hotkeyCallback,
            userInfo: userInfo
        ) else {
            logger.error("Failed to create CGEvent tap")
            ActivityLog.shared.log(.error, category: "Hotkey", message: "Failed to create CGEvent tap")
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        logger.info("Hotkey listener started (keyCode: \(self.hotkeyKeyCode))")
        ActivityLog.shared.log(.info, category: "Hotkey", message: "Hotkey listener started (keyCode: \(self.hotkeyKeyCode))")
        return true
    }

    func updateKeyCode(_ newKeyCode: UInt16, modifiers: UInt32 = 0) {
        stop()
        hotkeyKeyCode = newKeyCode
        hotkeyModifiers = modifiers
        _ = start()
        logger.info("Hotkey updated to keyCode: \(newKeyCode), modifiers: \(modifiers)")
        ActivityLog.shared.log(.info, category: "Hotkey", message: "Hotkey updated to keyCode: \(newKeyCode), modifiers: \(modifiers)")
    }

    /// Enter capture mode: the tap stays active and swallows all key events,
    /// posting `.hotkeyCaptured` with the key + modifiers pressed (or `.hotkeyCancelled` on Escape).
    func startCapture() {
        // Snapshot current modifier flags so we only detect *new* presses
        if let event = CGEvent(source: nil) {
            captureBaseFlags = event.flags
        }
        captureModifiers = []
        isCapturing = true
        logger.debug("Capture mode started")
        ActivityLog.shared.log(.debug, category: "Hotkey", message: "Capture mode started")
    }

    func stopCapture() {
        isCapturing = false
        logger.debug("Capture mode stopped")
        ActivityLog.shared.log(.debug, category: "Hotkey", message: "Capture mode stopped")
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isHolding = false
        logger.info("Hotkey listener stopped")
        ActivityLog.shared.log(.info, category: "Hotkey", message: "Hotkey listener stopped")
    }

    fileprivate func handleEvent(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let eventType = event.type

        // --- Capture mode: accumulate modifiers, finalize on key press ---
        if isCapturing {
            if eventType == .keyDown {
                isCapturing = false
                if keyCode == 53 && captureModifiers.isEmpty { // Escape with no modifiers — cancel
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .hotkeyCancelled, object: nil)
                    }
                } else {
                    let mods = UInt32(captureModifiers.intersection([.maskShift, .maskControl, .maskAlternate, .maskCommand]).rawValue)
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: .hotkeyCaptured,
                            object: nil,
                            userInfo: ["keyCode": keyCode, "modifiers": mods]
                        )
                    }
                }
                return nil // swallow
            }

            if eventType == .flagsChanged {
                guard KeyCodeNames.modifierKeyCodes.contains(keyCode) else {
                    return nil // swallow unknown modifier events
                }
                let relevantFlags: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]
                let currentFlags = event.flags.intersection(relevantFlags)
                let baseRelevant = captureBaseFlags.intersection(relevantFlags)
                let newlyPressed = currentFlags.subtracting(baseRelevant)

                if !newlyPressed.isEmpty {
                    // Modifier pressed — accumulate it
                    captureModifiers = captureModifiers.union(newlyPressed)
                } else if !captureModifiers.isEmpty && currentFlags.subtracting(baseRelevant).isEmpty {
                    // All new modifiers released without a key press — capture as modifier-only shortcut
                    isCapturing = false
                    let mods = UInt32(captureModifiers.rawValue)
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: .hotkeyCaptured,
                            object: nil,
                            userInfo: ["keyCode": keyCode, "modifiers": mods]
                        )
                    }
                }
                return nil // swallow all modifier events during capture
            }

            // Swallow keyUp events during capture too
            return nil
        }

        // --- Normal hotkey mode ---

        let isModifierOnly = KeyCodeNames.modifierKeyCodes.contains(hotkeyKeyCode)
        let requiredFlags = CGEventFlags(rawValue: UInt64(hotkeyModifiers))

        if isModifierOnly {
            // Modifier-only hotkey (e.g. Right Option)
            if eventType == .flagsChanged && keyCode == hotkeyKeyCode {
                let flags = event.flags
                let modDown = flags.contains(.maskAlternate) || flags.contains(.maskCommand)
                    || flags.contains(.maskShift) || flags.contains(.maskControl)

                if modDown && !isHolding {
                    isHolding = true
                    logger.debug("Recording started (modifier \(keyCode) held)")
                    ActivityLog.shared.log(.debug, category: "Hotkey", message: "Recording started (modifier \(keyCode) held)")
                    onRecordingStarted?()
                    return nil
                } else if !modDown && isHolding {
                    isHolding = false
                    logger.debug("Recording stopped (modifier \(keyCode) released)")
                    ActivityLog.shared.log(.debug, category: "Hotkey", message: "Recording stopped (modifier \(keyCode) released)")
                    onRecordingStopped?()
                    return nil
                }
            }
        } else {
            // Key (possibly with modifiers) hold-to-record
            let currentMods = event.flags.intersection([.maskShift, .maskControl, .maskAlternate, .maskCommand])
            let modsMatch = hotkeyModifiers == 0 || currentMods.contains(requiredFlags)

            if eventType == .keyDown && keyCode == hotkeyKeyCode && modsMatch && !isHolding {
                isHolding = true
                logger.debug("Recording started (key \(keyCode) held, mods: \(self.hotkeyModifiers))")
                ActivityLog.shared.log(.debug, category: "Hotkey", message: "Recording started (key \(keyCode) held)")
                onRecordingStarted?()
                return nil
            } else if eventType == .keyUp && keyCode == hotkeyKeyCode && isHolding {
                isHolding = false
                logger.debug("Recording stopped (key \(keyCode) released)")
                ActivityLog.shared.log(.debug, category: "Hotkey", message: "Recording stopped (key \(keyCode) released)")
                onRecordingStopped?()
                return nil
            }
        }

        return Unmanaged.passRetained(event)
    }

    fileprivate func reEnableTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }
}

extension Notification.Name {
    static let hotkeyDidChange = Notification.Name("hotkeyDidChange")
    static let hotkeyStartCapture = Notification.Name("hotkeyStartCapture")
    static let hotkeyCaptured = Notification.Name("hotkeyCaptured")
    static let hotkeyCancelled = Notification.Name("hotkeyCancelled")
}

private func hotkeyCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // Handle tap disabled events (system can disable taps under load)
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let userInfo = userInfo {
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
            manager.reEnableTap()
        }
        return Unmanaged.passRetained(event)
    }

    guard let userInfo = userInfo else {
        return Unmanaged.passRetained(event)
    }

    let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
    return manager.handleEvent(event)
}
