import Foundation

struct DictationStatsData: Codable {
    var totalWords: Int = 0
    var totalDictations: Int = 0
    var totalRecordingSeconds: Double = 0.0
    var toneUsage: [String: Int] = [:]
}

/// Tracks cumulative dictation statistics, persisted as JSON in UserDefaults.
enum DictationStats {
    static func load() -> DictationStatsData {
        guard let json = UserDefaults.standard.string(forKey: DefaultsKey.dictationStats),
              let data = json.data(using: .utf8),
              let stats = try? JSONDecoder().decode(DictationStatsData.self, from: data)
        else { return DictationStatsData() }
        return stats
    }

    static func save(_ stats: DictationStatsData) {
        guard let data = try? JSONEncoder().encode(stats),
              let json = String(data: data, encoding: .utf8)
        else { return }
        UserDefaults.standard.set(json, forKey: DefaultsKey.dictationStats)
    }

    static func record(wordCount: Int, durationSeconds: Double, tonePreset: String) {
        var stats = load()
        stats.totalWords += wordCount
        stats.totalDictations += 1
        stats.totalRecordingSeconds += durationSeconds
        stats.toneUsage[tonePreset, default: 0] += 1
        save(stats)
    }

    static func reset() {
        save(DictationStatsData())
    }
}
