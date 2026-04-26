@testable import Parrot
import XCTest

final class KeyCodeNamesTests: XCTestCase {

    func testKnownKeyCodes() {
        XCTAssertEqual(KeyCodeNames.displayName(for: 49), "Space ␣")
        XCTAssertEqual(KeyCodeNames.displayName(for: 36), "Return ↩")
        XCTAssertEqual(KeyCodeNames.displayName(for: 53), "Escape ⎋")
        XCTAssertEqual(KeyCodeNames.displayName(for: 0), "A")
        XCTAssertEqual(KeyCodeNames.displayName(for: 122), "F1")
    }

    func testUnknownKeyCodeFallback() {
        XCTAssertEqual(KeyCodeNames.displayName(for: 255), "Key 255")
    }

    func testModifierKeyCodes() {
        XCTAssertTrue(KeyCodeNames.modifierKeyCodes.contains(55)) // Left Command
        XCTAssertTrue(KeyCodeNames.modifierKeyCodes.contains(56)) // Left Shift
        XCTAssertTrue(KeyCodeNames.modifierKeyCodes.contains(58)) // Left Option
        XCTAssertTrue(KeyCodeNames.modifierKeyCodes.contains(59)) // Left Control
        XCTAssertTrue(KeyCodeNames.modifierKeyCodes.contains(61)) // Right Option
        XCTAssertTrue(KeyCodeNames.modifierKeyCodes.contains(63)) // fn
        XCTAssertFalse(KeyCodeNames.modifierKeyCodes.contains(0)) // A is not a modifier
    }

    func testDisplayNameWithCommandModifier() {
        let flags = CGEventFlags.maskCommand.rawValue
        let result = KeyCodeNames.displayName(for: 0, modifiers: UInt32(flags))
        XCTAssertTrue(result.contains("⌘"))
        XCTAssertTrue(result.contains("A"))
    }

    func testDisplayNameWithMultipleModifiers() {
        let flags = CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue
        let result = KeyCodeNames.displayName(for: 0, modifiers: UInt32(flags))
        XCTAssertTrue(result.contains("⌘"))
        XCTAssertTrue(result.contains("⇧"))
    }

    func testModifierOnlyKeyReturnsModifierSymbol() {
        // Right Option (61) with Option flag
        let flags = CGEventFlags.maskAlternate.rawValue
        let result = KeyCodeNames.displayName(for: 61, modifiers: UInt32(flags))
        XCTAssertEqual(result, "⌥")
    }

    func testModifierFlagMapping() {
        XCTAssertEqual(KeyCodeNames.modifierFlag(for: 61), .maskAlternate) // Right Option
        XCTAssertEqual(KeyCodeNames.modifierFlag(for: 58), .maskAlternate) // Left Option
        XCTAssertEqual(KeyCodeNames.modifierFlag(for: 54), .maskCommand)   // Right Command
        XCTAssertEqual(KeyCodeNames.modifierFlag(for: 55), .maskCommand)   // Left Command
        XCTAssertEqual(KeyCodeNames.modifierFlag(for: 56), .maskShift)     // Left Shift
        XCTAssertEqual(KeyCodeNames.modifierFlag(for: 60), .maskShift)     // Right Shift
        XCTAssertEqual(KeyCodeNames.modifierFlag(for: 59), .maskControl)   // Left Control
        XCTAssertEqual(KeyCodeNames.modifierFlag(for: 62), .maskControl)   // Right Control
        XCTAssertEqual(KeyCodeNames.modifierFlag(for: 63), .maskSecondaryFn) // fn
    }

    func testModifierFlagMappingNonModifiers() {
        XCTAssertNil(KeyCodeNames.modifierFlag(for: 0))   // A
        XCTAssertNil(KeyCodeNames.modifierFlag(for: 49))  // Space
        XCTAssertNil(KeyCodeNames.modifierFlag(for: 57))  // Caps Lock — modifier-key but no unique flag
        XCTAssertNil(KeyCodeNames.modifierFlag(for: 255)) // unknown
    }

    func testExactMatchModifierPredicate() {
        // Simulates the predicate used by HotkeyManager for modifier-only hotkeys:
        // the configured modifier's flag must be set, and no *other* modifier flag may be set.
        func modDown(eventFlags: CGEventFlags, hotkeyKeyCode: UInt16) -> Bool {
            guard let required = KeyCodeNames.modifierFlag(for: hotkeyKeyCode) else { return false }
            return eventFlags.intersection(KeyCodeNames.allModifierFlags) == required
        }

        // Right Option alone — fires.
        XCTAssertTrue(modDown(eventFlags: [.maskAlternate], hotkeyKeyCode: 61))
        // Right Option released — does not fire.
        XCTAssertFalse(modDown(eventFlags: [], hotkeyKeyCode: 61))
        // Cmd held with Right Option — must NOT fire (the original bug).
        XCTAssertFalse(modDown(eventFlags: [.maskCommand, .maskAlternate], hotkeyKeyCode: 61))
        // Shift alone with Right-Option-configured hotkey — must NOT fire.
        XCTAssertFalse(modDown(eventFlags: [.maskShift], hotkeyKeyCode: 61))
        // Cmd hotkey, only Cmd held — fires.
        XCTAssertTrue(modDown(eventFlags: [.maskCommand], hotkeyKeyCode: 54))
    }
}
