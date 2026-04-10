import Foundation

/// Single source of truth for all UserDefaults keys used by Parrot.
enum DefaultsKey {
    static let whisperModelPath = "whisperModelPath"
    static let llamaModelPath = "llamaModelPath"
    static let llmCleanupEnabled = "llmCleanupEnabled"
    static let tonePreset = "tonePreset"
    static let showFloatingBar = "showFloatingBar"
    static let selectedMicrophoneUID = "selectedMicrophoneUID"
    static let hotkeyKeyCode = "hotkeyKeyCode"
    static let hotkeyModifiers = "hotkeyModifiers"
    static let personalDictionary = "personalDictionary"
    static let dictationStats = "dictationStats"
    static let audioFeedbackEnabled = "audioFeedbackEnabled"
    static let launchAtLogin = "launchAtLogin"
    static let cleanupRulePrefix = "cleanupRule_"
}
