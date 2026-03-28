import AppKit

enum LogLevel: String {
    case debug, info, warning, error

    var label: String { rawValue.uppercased() }
}

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let category: String
    let level: LogLevel
    let message: String

    var formatted: String {
        "[\(Self.formatter.string(from: timestamp))] [\(category)] [\(level.label)] \(message)"
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
}

@Observable
final class ActivityLog: @unchecked Sendable {
    static let shared = ActivityLog()

    @MainActor private(set) var entries: [LogEntry] = []
    private let capacity = 500

    nonisolated func log(_ level: LogLevel, category: String, message: String) {
        let entry = LogEntry(timestamp: Date(), category: category, level: level, message: message)
        Task { @MainActor in
            self.append(entry)
        }
    }

    @MainActor
    func copyToClipboard() {
        let header = "Parrot Debug Log — \(Self.headerFormatter.string(from: Date()))\n\(entries.count) entries\n---"
        let body = entries.map(\.formatted).joined(separator: "\n")
        let text = "\(header)\n\(body)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @MainActor
    func clear() {
        entries.removeAll()
    }

    @MainActor
    private func append(_ entry: LogEntry) {
        entries.append(entry)
        if entries.count > capacity {
            entries.removeFirst(entries.count - capacity)
        }
    }

    private static let headerFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()
}
