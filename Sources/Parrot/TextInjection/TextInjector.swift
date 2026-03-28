import Cocoa
import os

final class TextInjector {
    private let logger = Logger(subsystem: "com.parrot", category: "TextInjection")

    func inject(_ text: String) {
        guard !text.isEmpty else {
            logger.warning("Attempted to inject empty text")
            ActivityLog.shared.log(.warning, category: "TextInjection", message: "Attempted to inject empty text")
            return
        }

        // Save current clipboard contents
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        // Set our text to clipboard with trailing space so consecutive
        // dictations don't run together (e.g. "word.Next" → "word. Next")
        pasteboard.clearContents()
        pasteboard.setString(text + " ", forType: .string)

        // Simulate Cmd+V
        simulatePaste()

        // Restore previous clipboard after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            pasteboard.clearContents()
            if let previous = previousContents {
                pasteboard.setString(previous, forType: .string)
            }
        }

        logger.info("Injected \(text.count) characters")
        ActivityLog.shared.log(.info, category: "TextInjection", message: "Injected \(text.count) characters")
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
