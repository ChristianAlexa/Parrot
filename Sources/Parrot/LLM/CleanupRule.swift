import Foundation

/// Stackable cleanup rules that add transformation instructions to the LLM prompt.
/// Multiple rules can be active simultaneously, unlike TonePreset (one at a time).
enum CleanupRule: String, CaseIterable, Identifiable {
    case slashCommands

    var id: String { rawValue }

    /// Whether this rule is always active (no toggle needed).
    var isAlwaysOn: Bool {
        switch self {
        case .slashCommands: true
        }
    }

    var displayName: String {
        switch self {
        case .slashCommands: "Slash commands (\"slash context\" → \"/context\")"
        }
    }

    var instruction: String {
        switch self {
        case .slashCommands:
            "When the speaker says \"slash\" followed by a word, format it as a forward slash command (e.g., \"slash context\" → \"/context\", \"slash help\" → \"/help\")"
        }
    }

    /// UserDefaults key for this rule's toggle.
    var defaultsKey: String {
        "cleanupRule_\(rawValue)"
    }

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: defaultsKey)
    }

    /// Rules that are always active regardless of settings.
    static var alwaysOnRules: [CleanupRule] {
        allCases.filter(\.isAlwaysOn)
    }

    /// User-toggled rules that are currently enabled.
    static var enabledRules: [CleanupRule] {
        allCases.filter { !$0.isAlwaysOn && $0.isEnabled }
    }

    /// Rules that appear in settings (only toggleable ones).
    static var toggleableRules: [CleanupRule] {
        allCases.filter { !$0.isAlwaysOn }
    }
}
