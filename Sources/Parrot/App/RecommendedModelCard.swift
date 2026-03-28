import SwiftUI

struct RecommendedModelCard: View {
    let model: RecommendedModel
    @Binding var selectedPath: String
    let allModels: [URL]
    let onModelsChanged: () -> Void

    @State private var downloader: ModelDownloader

    private let modelManager = ModelManager()

    init(model: RecommendedModel, selectedPath: Binding<String>, allModels: [URL], onModelsChanged: @escaping () -> Void, downloader: ModelDownloader) {
        self.model = model
        self._selectedPath = selectedPath
        self.allModels = allModels
        self.onModelsChanged = onModelsChanged
        self._downloader = State(initialValue: downloader)
    }

    private var downloadState: DownloadState {
        downloader.downloads[model.id] ?? .idle
    }

    private var isDownloaded: Bool {
        downloader.isModelDownloaded(model)
    }

    private var hasSelection: Bool {
        !selectedPath.isEmpty
    }

    /// True if this model is the best recommended choice for the user's system in its category.
    private var isBestForCategory: Bool {
        let candidates: [RecommendedModel]
        switch model.category {
        case .whisper: candidates = ModelCatalog.whisperModels
        case .llm: candidates = ModelCatalog.llmModels
        }
        // The best model is the first one that fits in RAM (catalog is ordered best-first)
        let best = candidates.first { $0.minRAMGB <= ModelCatalog.systemRAMGB }
        return best?.id == model.id
    }

    /// True if this is the first catalog entry for its category — used to show only one slot card when a model is selected.
    private var isFirstInCategory: Bool {
        let candidates: [RecommendedModel]
        switch model.category {
        case .whisper: candidates = ModelCatalog.whisperModels
        case .llm: candidates = ModelCatalog.llmModels
        }
        return candidates.first?.id == model.id
    }

    var body: some View {
        Group {
            if hasSelection {
                if isFirstInCategory {
                    // Model is selected — show populated card with model slot behavior (only once per category)
                    ModelSlotCard(
                        title: model.category == .whisper ? "Whisper Model" : "LLM Model",
                        icon: model.category == .whisper ? "waveform" : "cpu",
                        fileExtensions: model.category == .whisper ? ["bin"] : ["gguf"],
                        selectedPath: $selectedPath,
                        availableModels: allModels,
                        onModelsChanged: onModelsChanged
                    )
                }
                // Other catalog entries are hidden when a model is already selected
            } else {
                emptyStateCard
            }
        }
    }

    // MARK: - Empty State (not selected)

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: model.category == .whisper ? "waveform" : "cpu")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(model.displayName)
                            .font(.system(.body, weight: .medium))
                        if model.minRAMGB <= ModelCatalog.systemRAMGB,
                           isBestForCategory {
                            Text("Best for your Mac")
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(.green))
                        }
                    }
                    Text("\(model.description) \(model.expectedSizeDescription)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if model.minRAMGB > ModelCatalog.systemRAMGB {
                        Text("Your Mac has \(ModelCatalog.systemRAMGB) GB RAM — this model needs \(model.minRAMGB) GB+")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                Spacer()
            }

            // Action area
            switch downloadState {
            case .idle:
                if isDownloaded {
                    // Downloaded but not selected — offer to select
                    HStack {
                        Button("Use This Model") {
                            selectedPath = downloader.modelPath(for: model).path
                        }
                        .font(.caption)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        Spacer()

                        browseButton
                    }
                } else {
                    HStack {
                        Button("Download") {
                            downloader.download(model)
                        }
                        .font(.caption)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        Spacer()

                        browseButton
                    }
                }

            case .downloading(let progress, let bytesWritten, let totalBytes):
                VStack(spacing: 4) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)

                    HStack {
                        Text(downloadProgressText(bytesWritten: bytesWritten, totalBytes: totalBytes))
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button("Cancel") {
                            downloader.cancel(model.id)
                        }
                        .font(.caption2)
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                    }
                }

            case .completed:
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Downloaded")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Use This Model") {
                        selectedPath = downloader.modelPath(for: model).path
                        onModelsChanged()
                    }
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

            case .failed(let message):
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    Button("Retry") {
                        downloader.download(model)
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: MenuBarStyle.rowCornerRadius)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: MenuBarStyle.rowCornerRadius)
                .stroke(Color(nsColor: .separatorColor),
                        style: isDownloaded
                            ? StrokeStyle(lineWidth: 0.5)
                            : StrokeStyle(lineWidth: 1, dash: [6, 4]))
        )
    }

    private var browseButton: some View {
        Button("Browse\u{2026}") {
            browseForFile()
        }
        .font(.caption2)
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }

    private func browseForFile() {
        let extensions = model.category == .whisper ? ["bin"] : ["gguf"]
        Task {
            guard let url = await ModelManager.browseAndImport(extensions: extensions) else { return }
            selectedPath = url.path
            onModelsChanged()
        }
    }

    private func downloadProgressText(bytesWritten: Int64, totalBytes: Int64) -> String {
        let written = ByteCountFormatter.string(fromByteCount: bytesWritten, countStyle: .file)
        let total = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        let percent = totalBytes > 0 ? Int(Double(bytesWritten) / Double(totalBytes) * 100) : 0
        return "\(written) / \(total) (\(percent)%)"
    }
}
