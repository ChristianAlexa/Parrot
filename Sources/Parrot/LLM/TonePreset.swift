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
            "Format like a casual text message — all lowercase, no apostrophes (use dont instead of don't, im instead of I'm), minimal punctuation (periods only, no commas or exclamation marks), do not change the actual words or use slang"
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
