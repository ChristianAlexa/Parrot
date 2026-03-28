import SwiftUI

struct ModelSlotCard: View {
    let title: String
    let icon: String
    let fileExtensions: [String]
    @Binding var selectedPath: String
    let availableModels: [URL]
    let onModelsChanged: () -> Void

    @State private var isDropTargeted = false
    @State private var isImporting = false

    private let modelManager = ModelManager()

    private var selectedURL: URL? {
        guard !selectedPath.isEmpty else { return nil }
        return URL(fileURLWithPath: selectedPath)
    }

    var body: some View {
        Group {
            if let url = selectedURL {
                populatedCard(url: url)
            } else {
                emptyCard
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
    }

    // MARK: - Populated

    private func populatedCard(url: URL) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                HStack(spacing: 6) {
                    Text(modelManager.modelDisplayName(url))
                        .font(.system(.body, weight: .medium))
                        .lineLimit(1)

                    Text("·")
                        .foregroundStyle(.tertiary)

                    Text(modelManager.modelSizeDescription(url))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            modelMenu
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: MenuBarStyle.rowCornerRadius)
                .fill(Color.primary.opacity(isDropTargeted ? 0.06 : 0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: MenuBarStyle.rowCornerRadius)
                .stroke(isDropTargeted ? Color.accentColor : Color(nsColor: .separatorColor),
                        lineWidth: isDropTargeted ? 1.5 : 0.5)
        )
    }

    private var modelMenu: some View {
        Menu {
            if availableModels.count > 1 {
                ForEach(availableModels, id: \.path) { model in
                    Button {
                        selectedPath = model.path
                    } label: {
                        let name = modelManager.modelDisplayName(model)
                        let size = modelManager.modelSizeDescription(model)
                        Text("\(name) · \(size)")
                    }
                    .disabled(model.path == selectedPath)
                }
                Divider()
            }

            Button("Browse\u{2026}") { browseForFile() }

            Divider()

            Button("Remove", role: .destructive) { selectedPath = "" }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    // MARK: - Empty

    private var emptyCard: some View {
        VStack(spacing: 6) {
            if isImporting {
                ProgressView()
                    .controlSize(.small)
                Text("Importing\u{2026}")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Drop a .\(fileExtensions.first ?? "") file here")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Browse\u{2026}") { browseForFile() }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .background(
            RoundedRectangle(cornerRadius: MenuBarStyle.rowCornerRadius)
                .fill(Color.primary.opacity(isDropTargeted ? 0.06 : 0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: MenuBarStyle.rowCornerRadius)
                .stroke(isDropTargeted ? Color.accentColor : Color(nsColor: .separatorColor),
                        style: isDropTargeted
                            ? StrokeStyle(lineWidth: 1.5)
                            : StrokeStyle(lineWidth: 1, dash: [6, 4]))
        )
    }

    // MARK: - Actions

    private func browseForFile() {
        Task {
            guard let url = await ModelManager.browseAndImport(extensions: fileExtensions) else { return }
            selectedPath = url.path
            onModelsChanged()
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url,
                  fileExtensions.contains(url.pathExtension.lowercased()) else { return }
            DispatchQueue.main.async {
                importAndSelect(url)
            }
        }

        return true
    }

    private func importAndSelect(_ sourceURL: URL) {
        // If already in the models directory, just select it
        if sourceURL.deletingLastPathComponent().path == ModelManager.modelsDirectory.path {
            selectedPath = sourceURL.path
            return
        }

        isImporting = true
        Task.detached {
            do {
                let dest = try ModelManager().importModel(from: sourceURL)
                await MainActor.run {
                    selectedPath = dest.path
                    isImporting = false
                    onModelsChanged()
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                }
            }
        }
    }
}
