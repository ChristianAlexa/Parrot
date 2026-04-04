import Foundation

/// Tone presets that adjust the LLM cleanup output style.
enum TonePreset: String, CaseIterable, Identifiable {
    case neutral
    case professional
    case casual
    case technical
    case lowkey

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .neutral: "Neutral"
        case .professional: "Professional"
        case .casual: "Casual"
        case .technical: "Technical"
        case .lowkey: "Lowkey"
        }
    }

    /// Prompt instruction appended to the cleanup system message. Nil for neutral (no change).
    var instruction: String? {
        switch self {
        case .neutral:
            nil
        case .professional:
            "Adjust the tone to be professional and polished — use complete sentences, avoid slang, and prefer formal phrasing while keeping the original meaning"
        case .casual:
            "Keep the tone casual and conversational — contractions are fine, relaxed punctuation is okay, preserve the natural spoken feel"
        case .technical:
            "Preserve all technical terminology, acronyms, and domain-specific jargon exactly as spoken — do not simplify or rephrase technical content"
        case .lowkey:
            "Format like a casual text message — all lowercase, no apostrophes, minimal punctuation, do not change the actual words or use slang"
        }
    }

    /// Applies deterministic formatting that the LLM can't be trusted to do reliably.
    func postProcess(_ text: String) -> String {
        switch self {
        case .lowkey:
            var result = text.lowercased()
            // Strip apostrophes from contractions (don't → dont, I'm → im)
            result = result.replacingOccurrences(of: "'", with: "")
            result = result.replacingOccurrences(of: "\u{2019}", with: "") // curly apostrophe
            // Strip commas and exclamation marks
            result = result.replacingOccurrences(of: ",", with: "")
            result = result.replacingOccurrences(of: "!", with: "")
            return result
        default:
            return text
        }
    }

    /// Read the current selection from UserDefaults.
    static var current: TonePreset {
        guard let raw = UserDefaults.standard.string(forKey: "tonePreset"),
              let preset = TonePreset(rawValue: raw)
        else { return .neutral }
        return preset
    }
}
