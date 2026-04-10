import Foundation
import os

/// Observable store of model files available in the managed Models directory.
///
/// Owns the lifecycle of scanning the filesystem for Whisper/LLM models so views
/// can render from an in-memory source of truth instead of triggering disk scans
/// on every appear. Refresh on app launch and after imports/downloads.
@MainActor
@Observable
final class ModelsStore {
    private(set) var whisperModels: [URL] = []
    private(set) var llmModels: [URL] = []

    private let logger = Logger(subsystem: "com.parrot", category: "ModelsStore")

    func refresh() {
        whisperModels = Self.listModels(withExtension: "bin")
        llmModels = Self.listModels(withExtension: "gguf")
        logger.debug("Refreshed: \(self.whisperModels.count) whisper, \(self.llmModels.count) llm")
    }

    private static func listModels(withExtension ext: String) -> [URL] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: ModelManager.modelsDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: .skipsHiddenFiles
        ) else { return [] }

        return files
            .filter { $0.pathExtension == ext }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}

@MainActor
let sharedModelsStore = ModelsStore()
