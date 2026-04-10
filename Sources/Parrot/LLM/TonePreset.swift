import Foundation

/// Tone presets that adjust the LLM cleanup output style.
enum TonePreset: String, CaseIterable, Identifiable {
    case neutral
    case lowkey

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .neutral: "Neutral"
        case .lowkey: "Lowkey"
        }
    }

    /// Prompt instruction appended to the cleanup system message. Nil for neutral (no change).
    var instruction: String? {
        switch self {
        case .neutral:
            nil
        case .lowkey:
            "Format like a casual text message — all lowercase, no apostrophes, minimal punctuation, do not change the actual words or use slang"
        }
    }

    /// Applies deterministic formatting that the LLM can't be trusted to do reliably.
    func postProcess(_ text: String) -> String {
        switch self {
        case .lowkey:
            var result = Self.collapseWhitespace(text).lowercased()
            // Strip apostrophes from contractions (don't → dont, I'm → im)
            result = result.replacingOccurrences(of: "'", with: "")
            result = result.replacingOccurrences(of: "\u{2019}", with: "") // curly apostrophe
            // Strip commas and exclamation marks
            result = result.replacingOccurrences(of: ",", with: "")
            result = result.replacingOccurrences(of: "!", with: "")
            return result
        case .neutral:
            var result = Self.collapseWhitespace(text)
            result = Self.capitalizeFirst(result)
            result = Self.ensureTrailingPunctuation(result)
            return result
        }
    }

    private static func collapseWhitespace(_ text: String) -> String {
        text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private static func capitalizeFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    private static func ensureTrailingPunctuation(_ text: String) -> String {
        guard let last = text.last else { return text }
        if last.isPunctuation { return text }
        return text + "."
    }

    /// Read the current selection from UserDefaults.
    static var current: TonePreset {
        guard let raw = UserDefaults.standard.string(forKey: DefaultsKey.tonePreset),
              let preset = TonePreset(rawValue: raw)
        else { return .neutral }
        return preset
    }
}
