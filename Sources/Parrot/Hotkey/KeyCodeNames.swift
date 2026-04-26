import Carbon.HIToolbox

enum KeyCodeNames {
    /// Key codes that represent modifier-only keys (no character output).
    static let modifierKeyCodes: Set<UInt16> = [
        54, // Right Command
        55, // Left Command
        56, // Left Shift
        57, // Caps Lock
        58, // Left Option
        59, // Left Control
        60, // Right Shift
        61, // Right Option
        62, // Right Control
        63, // Function (fn)
    ]

    /// Maps a modifier-only key code to the CGEventFlags mask it sets when held.
    /// Returns nil for non-modifier keys and for modifiers without a unique flag (Caps Lock).
    static func modifierFlag(for keyCode: UInt16) -> CGEventFlags? {
        switch keyCode {
        case 54, 55: return .maskCommand          // Right/Left Command
        case 56, 60: return .maskShift            // Left/Right Shift
        case 58, 61: return .maskAlternate        // Left/Right Option
        case 59, 62: return .maskControl          // Left/Right Control
        case 63:     return .maskSecondaryFn      // fn
        default:     return nil
        }
    }

    /// All distinct modifier flags considered when matching hotkeys.
    static let allModifierFlags: CGEventFlags =
        [.maskShift, .maskControl, .maskAlternate, .maskCommand, .maskSecondaryFn]

    static func displayName(for keyCode: UInt16) -> String {
        keyCodeMap[keyCode] ?? "Key \(keyCode)"
    }

    static func displayName(for keyCode: UInt16, modifiers: UInt32) -> String {
        var parts: [String] = []
        let flags = CGEventFlags(rawValue: UInt64(modifiers))
        if flags.contains(.maskControl) { parts.append("⌃") }
        if flags.contains(.maskAlternate) { parts.append("⌥") }
        if flags.contains(.maskShift) { parts.append("⇧") }
        if flags.contains(.maskCommand) { parts.append("⌘") }

        if modifierKeyCodes.contains(keyCode) {
            // Modifier-only shortcut — only show the modifier symbol if no parts yet
            if parts.isEmpty {
                return displayName(for: keyCode)
            }
            return parts.joined()
        }

        parts.append(shortKeyName(for: keyCode))
        return parts.joined()
    }

    /// Short key name without symbols (for combo display)
    private static func shortKeyName(for keyCode: UInt16) -> String {
        shortKeyMap[keyCode] ?? keyCodeMap[keyCode] ?? "Key \(keyCode)"
    }

    private static let shortKeyMap: [UInt16: String] = [
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋",
        115: "Home", 116: "PgUp", 117: "⌦", 119: "End", 121: "PgDn",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]

    private static let keyCodeMap: [UInt16: String] = [
        // Letters (QWERTY layout)
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H",
        5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3",
        21: "4", 22: "6", 23: "5", 24: "=", 25: "9",
        26: "7", 27: "-", 28: "8", 29: "0", 30: "]",
        31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";",
        42: "\\", 43: ",", 44: "/", 45: "N", 46: "M",
        47: ".", 50: "`",

        // Special keys
        36: "Return ↩", 48: "Tab ⇥", 49: "Space ␣", 51: "Delete ⌫",
        53: "Escape ⎋", 71: "Clear", 76: "Enter ⌅",
        115: "Home", 116: "Page Up", 117: "Forward Delete ⌦",
        119: "End", 121: "Page Down",

        // Arrow keys
        123: "Left Arrow ←", 124: "Right Arrow →",
        125: "Down Arrow ↓", 126: "Up Arrow ↑",

        // Function keys
        122: "F1", 120: "F2", 99: "F3", 118: "F4",
        96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12",
        105: "F13", 107: "F14", 113: "F15",

        // Modifier keys
        54: "Right Command (⌘)", 55: "Left Command (⌘)",
        56: "Left Shift (⇧)", 57: "Caps Lock ⇪",
        58: "Left Option (⌥)", 59: "Left Control (⌃)",
        60: "Right Shift (⇧)", 61: "Right Option (⌥)",
        62: "Right Control (⌃)", 63: "fn",

        // Numpad
        65: "Numpad .", 67: "Numpad *", 69: "Numpad +",
        75: "Numpad /", 78: "Numpad -", 81: "Numpad =",
        82: "Numpad 0", 83: "Numpad 1", 84: "Numpad 2",
        85: "Numpad 3", 86: "Numpad 4", 87: "Numpad 5",
        88: "Numpad 6", 89: "Numpad 7", 91: "Numpad 8",
        92: "Numpad 9",
    ]
}
