import Cocoa
import os

@MainActor
final class TextInjector {
    private let logger = Logger(subsystem: "com.parrot", category: "TextInjection")
    private var pendingRestore: DispatchWorkItem?
    private var pendingRestoreAction: (() -> Void)?

    func inject(_ text: String) {
        guard !text.isEmpty else {
            logger.warning("Attempted to inject empty text")
            ActivityLog.shared.log(.warning, category: "TextInjection", message: "Attempted to inject empty text")
            return
        }

        // Cancel any pending restore from a previous inject — otherwise stacking
        // timers would fight, and an old restore could clobber the new write.
        pendingRestore?.cancel()
        pendingRestore = nil
        pendingRestoreAction = nil

        // Save current clipboard contents
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        // Set our text to clipboard with trailing space so consecutive
        // dictations don't run together (e.g. "word.Next" → "word. Next")
        let injectedString = text + " "
        pasteboard.clearContents()
        pasteboard.setString(injectedString, forType: .string)

        // Simulate Cmd+V
        simulatePaste()

        // Restore previous clipboard after a brief delay. Check the pasteboard
        // still holds exactly what we wrote before restoring — if anything else
        // (user Cmd+C, clipboard manager, Universal Clipboard) has replaced it
        // in the window, leave that content alone. String equality is stronger
        // than changeCount comparison, which can false-positive on benign
        // re-writes by paste-capturing apps.
        let restoreAction: () -> Void = { [weak self] in
            guard pasteboard.string(forType: .string) == injectedString else {
                self?.pendingRestore = nil
                self?.pendingRestoreAction = nil
                return
            }
            pasteboard.clearContents()
            if let previous = previousContents {
                pasteboard.setString(previous, forType: .string)
            }
            self?.pendingRestore = nil
            self?.pendingRestoreAction = nil
        }
        let restore = DispatchWorkItem {
            MainActor.assumeIsolated {
                restoreAction()
            }
        }
        pendingRestore = restore
        pendingRestoreAction = restoreAction
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: restore)

        logger.info("Injected \(text.count) characters")
        ActivityLog.shared.log(.info, category: "TextInjection", message: "Injected \(text.count) characters")
    }

    func flushPendingRestore() {
        guard let action = pendingRestoreAction else { return }
        pendingRestore?.cancel()
        pendingRestore = nil
        action()
    }

    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        // Key code 9 = 'V'
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) else {
            logger.error("Failed to create CGEvent for paste simulation")
            ActivityLog.shared.log(.error, category: "TextInjection", message: "Failed to create CGEvent for paste simulation")
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
    }
}
