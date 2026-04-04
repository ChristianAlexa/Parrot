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
}
