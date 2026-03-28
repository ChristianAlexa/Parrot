import Foundation

/// Manages a user's personal dictionary of words/phrases that bias transcription accuracy.
/// Stored as a JSON-encoded `[String]` in UserDefaults.
enum PersonalDictionary {
    static let maxEntries = 200
    private static let key = "personalDictionary"

    static func words() -> [String] {
        guard let json = UserDefaults.standard.string(forKey: key),
              let data = json.data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return array
    }

    static func save(_ words: [String]) {
        guard let data = try? JSONEncoder().encode(words),
              let json = String(data: data, encoding: .utf8)
        else { return }
        UserDefaults.standard.set(json, forKey: key)
    }

    /// Comma-separated string for Whisper's `initial_prompt` parameter.
    static func whisperPrompt() -> String? {
        let w = words()
        guard !w.isEmpty else { return nil }
        return w.joined(separator: ", ")
    }

    /// Vocabulary hint appended to the LLM cleanup system message.
    static func cleanupHint() -> String? {
        let w = words()
        guard !w.isEmpty else { return nil }
        return "Preferred vocabulary: \(w.joined(separator: ", ")). Always use these words exactly as written (including capitalization) when the transcript contains similar-sounding words"
    }
}
