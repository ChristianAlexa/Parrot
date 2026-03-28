import AppKit
import Foundation
import UniformTypeIdentifiers
import os

final class ModelManager {
    private let logger = Logger(subsystem: "com.parrot", category: "Models")

    static let modelsDirectory: URL = {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Application Support directory unavailable")
        }
        return appSupport.appendingPathComponent("Parrot/Models")
    }()

    func ensureModelsDirectoryExists() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: Self.modelsDirectory.path) {
            do {
                try fm.createDirectory(at: Self.modelsDirectory, withIntermediateDirectories: true)
                logger.info("Created models directory: \(Self.modelsDirectory.path)")
                ActivityLog.shared.log(.info, category: "Models", message: "Created models directory: \(Self.modelsDirectory.path)")
            } catch {
                logger.error("Failed to create models directory: \(error.localizedDescription)")
                ActivityLog.shared.log(.error, category: "Models", message: "Failed to create models directory: \(error.localizedDescription)")
            }
        }
    }

    func availableWhisperModels() -> [URL] {
        listModels(withExtension: "bin")
    }

    func availableLLMModels() -> [URL] {
        listModels(withExtension: "gguf")
    }

    private func listModels(withExtension ext: String) -> [URL] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: Self.modelsDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: .skipsHiddenFiles
        ) else { return [] }

        return files
            .filter { $0.pathExtension == ext }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    func modelSizeDescription(_ url: URL) -> String {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
              let size = values.fileSize else { return "unknown size" }
        let gb = Double(size) / 1_073_741_824
        if gb < 0.1 {
            let mb = Double(size) / 1_048_576
            return String(format: "%.0f MB", mb)
        }
        return String(format: "%.1f GB", gb)
    }

    /// Copies a model file into the managed Models directory, returning the destination URL.
    func importModel(from sourceURL: URL) throws -> URL {
        ensureModelsDirectoryExists()
        let dest = Self.modelsDirectory.appendingPathComponent(sourceURL.lastPathComponent)
        let fm = FileManager.default
        if fm.fileExists(atPath: dest.path) {
            try fm.removeItem(at: dest)
        }
        try fm.copyItem(at: sourceURL, to: dest)
        logger.info("Imported model: \(dest.lastPathComponent)")
        ActivityLog.shared.log(.info, category: "Models", message: "Imported model: \(dest.lastPathComponent)")
        return dest
    }

    /// Human-readable model name: strips extension, replaces hyphens/underscores with spaces.
    func modelDisplayName(_ url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
    }

    /// Shows an open panel for model files, imports if needed, returns the final URL.
    @MainActor
    static func browseAndImport(extensions: [String]) async -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = extensions.compactMap { UTType(filenameExtension: $0) }
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.level = .floating
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        if url.deletingLastPathComponent().path == modelsDirectory.path {
            return url
        }
        return try? await Task.detached {
            try ModelManager().importModel(from: url)
        }.value
    }
}
