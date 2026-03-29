import SwiftUI

@MainActor
let sharedModelDownloader = ModelDownloader()

// MARK: - Output Style Tab

struct OutputStyleView: View {
    @AppStorage("llmCleanupEnabled") private var llmCleanupEnabled: Bool = true
    @AppStorage("tonePreset") private var tonePreset: String = TonePreset.neutral.rawValue

    @State private var dictionaryWords: [String] = []
    @State private var newWord: String = ""
    @State private var showClearConfirmation: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("LLM text cleanup (disable for raw transcription)", isOn: $llmCleanupEnabled)

            if llmCleanupEnabled {
                Picker("Tone", selection: $tonePreset) {
                    ForEach(TonePreset.allCases) { preset in
                        Text(preset.displayName).tag(preset.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)

                ForEach(CleanupRule.toggleableRules) { rule in
                    CleanupRuleToggle(rule: rule)
                }
            }

            Divider()

            HStack {
                Text("Personal Dictionary")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(dictionaryWords.count) / \(PersonalDictionary.maxEntries)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                if !dictionaryWords.isEmpty {
                    if showClearConfirmation {
                        HStack(spacing: 6) {
                            Text("Clear all?")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Button("Yes") {
                                dictionaryWords.removeAll()
                                PersonalDictionary.save(dictionaryWords)
                                showClearConfirmation = false
                            }
                            .font(.caption2)
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                            Button("No") {
                                showClearConfirmation = false
                            }
                            .font(.caption2)
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                    } else {
                        Button("Clear All") {
                            showClearConfirmation = true
                        }
                        .font(.caption2)
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                    }
                }
            }

            HStack {
                TextField("Add word or phrase...", text: $newWord)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addDictionaryWord() }
                Button("Add") { addDictionaryWord() }
                    .disabled(newWord.trimmingCharacters(in: .whitespaces).isEmpty
                              || dictionaryWords.count >= PersonalDictionary.maxEntries)
            }

            if !dictionaryWords.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(dictionaryWords, id: \.self) { word in
                        HStack(spacing: 4) {
                            Text(word)
                                .font(.caption)
                            Button {
                                removeDictionaryWord(word)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.08))
                        .cornerRadius(4)
                    }
                }
            }
        }
        .padding()
        .onAppear {
            dictionaryWords = PersonalDictionary.words()
        }
    }

    private func addDictionaryWord() {
        let trimmed = newWord.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              dictionaryWords.count < PersonalDictionary.maxEntries,
              !dictionaryWords.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame })
        else { return }
        dictionaryWords.insert(trimmed, at: 0)
        PersonalDictionary.save(dictionaryWords)
        newWord = ""
    }

    private func removeDictionaryWord(_ word: String) {
        dictionaryWords.removeAll { $0 == word }
        PersonalDictionary.save(dictionaryWords)
    }
}

// MARK: - Record Tab

struct RecordTabView: View {
    @Bindable private var deviceManager = sharedAudioDeviceManager
    @State private var refreshRotation: Double = 0
    @State private var testOutput: String = ""
    @State private var isTestRecording: Bool = false

    private var selectedMicName: String {
        if let uid = deviceManager.selectedDeviceUID,
           let device = deviceManager.availableDevices.first(where: { $0.uid == uid }) {
            return device.name
        }
        let defaultName = deviceManager.availableDevices.first(where: { $0.isDefault })?.name ?? "System Default"
        return "Auto (\(defaultName))"
    }

    var body: some View {
        VStack(spacing: 12) {
            StatusIndicatorView(appState: sharedAppState)

            Grid(horizontalSpacing: 6, verticalSpacing: 12) {
                // Microphone picker
                GridRow {
                    Image(systemName: "mic")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Picker("Microphone", selection: $deviceManager.selectedDeviceUID) {
                        Text("Auto (\(deviceManager.availableDevices.first(where: { $0.isDefault })?.name ?? "System Default"))")
                            .tag(nil as String?)
                        Divider()
                        ForEach(deviceManager.availableDevices) { device in
                            Text(device.name).tag(device.uid as String?)
                        }
                    }
                    .labelsHidden()

                    Button {
                        sharedAudioDeviceManager.refreshDevices()
                        withAnimation(.easeInOut(duration: 0.5)) {
                            refreshRotation += 360
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(refreshRotation))
                    }
                    .buttonStyle(.plain)
                    .help("Refresh microphone list")
                }

                // Shortcut
                GridRow {
                    Image(systemName: "keyboard")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    ShortcutRecorderButton()

                    Color.clear
                        .gridCellUnsizedAxes(.horizontal)
                }
            }

            Divider()

            // Test section
            VStack(alignment: .leading, spacing: 8) {
                Text("Test")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(testOutput.isEmpty ? "Hold the button below to test recording and see output here." : testOutput)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(testOutput.isEmpty ? .tertiary : .primary)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.primary.opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                    )

                Button {
                    if isTestRecording {
                        isTestRecording = false
                        NotificationCenter.default.post(name: .testRecordingStopped, object: nil)
                    } else {
                        testOutput = ""
                        isTestRecording = true
                        NotificationCenter.default.post(name: .testRecordingStarted, object: nil)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isTestRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 12))
                        Text(isTestRecording ? "Stop" : "Test Recording")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(isTestRecording ? .red : .accentColor)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isTestRecording ? Color.red.opacity(0.1) : Color.accentColor.opacity(0.1))
                )
                .disabled(!sharedAppState.isModelsLoaded)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .onAppear {
            deviceManager.refreshDevices()
            sharedAppState.isTestModeActive = true
        }
        .onDisappear {
            sharedAppState.isTestModeActive = false
        }
        .onChange(of: sharedAppState.status) { _, newStatus in
            if sharedAppState.isTestModeActive {
                if newStatus == .recording {
                    testOutput = ""
                    isTestRecording = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .testTranscriptionResult)) { notification in
            if let text = notification.userInfo?["text"] as? String {
                testOutput = text
            }
            isTestRecording = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .testTranscriptionError)) { notification in
            if let message = notification.userInfo?["message"] as? String {
                testOutput = "Error: \(message)"
            }
            isTestRecording = false
        }
    }
}

// MARK: - Settings Tab

struct SettingsTabView: View {
    @AppStorage("audioFeedbackEnabled") private var audioFeedbackEnabled: Bool = true
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("System") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Audio feedback (sounds on record start/stop)", isOn: $audioFeedbackEnabled)
                    Toggle("Launch at login", isOn: $launchAtLogin)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }

            Button(action: { ActivityLog.shared.copyToClipboard() }) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text("Copy debug log to clipboard")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
}

// MARK: - Models Tab

struct ModelsTabView: View {
    @AppStorage("whisperModelPath") private var whisperModelPath: String = ""
    @AppStorage("llamaModelPath") private var llamaModelPath: String = ""

    @State private var whisperModels: [URL] = []
    @State private var llmModels: [URL] = []

    private let modelManager = ModelManager()

    var body: some View {
        VStack(spacing: 10) {
            if whisperModelPath.isEmpty || llamaModelPath.isEmpty {
                Text("One model from each section below is required for local transcription.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 4) {
                Text("Speech-to-Text (Whisper) — required")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !whisperModelPath.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(ModelCatalog.whisperModels) { model in
                RecommendedModelCard(
                    model: model,
                    selectedPath: $whisperModelPath,
                    allModels: whisperModels,
                    onModelsChanged: refreshModels,
                    downloader: sharedModelDownloader
                )
            }

            Divider()

            HStack(spacing: 4) {
                Text("Text Cleanup (LLM) — required")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !llamaModelPath.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(ModelCatalog.llmModels) { model in
                RecommendedModelCard(
                    model: model,
                    selectedPath: $llamaModelPath,
                    allModels: llmModels,
                    onModelsChanged: refreshModels,
                    downloader: sharedModelDownloader
                )
            }
        }
        .padding()
        .onAppear { refreshModels() }
        .onChange(of: whisperModelPath) { _, _ in
            NotificationCenter.default.post(name: .inferenceSettingsDidChange, object: nil)
        }
        .onChange(of: llamaModelPath) { _, _ in
            NotificationCenter.default.post(name: .inferenceSettingsDidChange, object: nil)
        }
    }

    private func refreshModels() {
        whisperModels = modelManager.availableWhisperModels()
        llmModels = modelManager.availableLLMModels()
    }
}

// MARK: - About Tab

struct AboutTabView: View {
    private var versionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            if let image = Self.loadParrotImage() {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            }

            Text("Parrot")
                .font(.title2)
                .fontWeight(.semibold)

            Text("v\(versionString)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Local voice dictation for macOS. Press a shortcut, speak, and cleaned-up text is typed into whatever app you're using. Runs entirely on-device — no cloud, no network, full privacy.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private static func loadParrotImage() -> NSImage? {
        // .app bundle (make release)
        if let path = Bundle.main.path(forResource: "parrot", ofType: "jpeg") {
            return NSImage(contentsOfFile: path)
        }
        // SPM debug build — look relative to working directory
        let cwd = FileManager.default.currentDirectoryPath
        let path = (cwd as NSString).appendingPathComponent("Resources/images/parrot.jpeg")
        return NSImage(contentsOfFile: path)
    }
}

// MARK: - Stats Tab

struct StatsTabView: View {
    @State private var stats = DictationStats.load()
    @State private var showResetConfirmation: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("Usage") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Spacer()
                        Button(action: { copyStats() }) {
                            Image(systemName: "doc.on.clipboard")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    statRow("Total dictations", value: "\(stats.totalDictations)")
                    statRow("Total words dictated", value: "\(stats.totalWords)")
                    statRow("Total recording time", value: formattedDuration)
                    statRow("Average WPM", value: formattedWPM)
                    statRow("Most-used tone", value: mostUsedTone)
                    statRow("Estimated time saved", value: formattedTimeSaved)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }

            if stats.totalDictations > 0 {
                HStack {
                    Spacer()
                    if showResetConfirmation {
                        HStack(spacing: 6) {
                            Text("Reset all stats?")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Button("Yes") {
                                DictationStats.reset()
                                stats = DictationStats.load()
                                showResetConfirmation = false
                            }
                            .font(.caption2)
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                            Button("No") {
                                showResetConfirmation = false
                            }
                            .font(.caption2)
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                    } else {
                        Button("Reset All") {
                            showResetConfirmation = true
                        }
                        .font(.caption2)
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                    }
                }
            }
        }
        .padding()
        .onAppear { stats = DictationStats.load() }
    }

    private func statRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }

    private func copyStats() {
        let text = """
        Parrot Stats
        Dictations: \(stats.totalDictations)
        Words: \(stats.totalWords)
        Recording time: \(formattedDuration)
        Avg WPM: \(formattedWPM)
        Most-used tone: \(mostUsedTone)
        Time saved: \(formattedTimeSaved)
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private var formattedDuration: String {
        let total = Int(stats.totalRecordingSeconds)
        if total < 60 { return "\(total)s" }
        if total < 3600 { return "\(total / 60)m \(total % 60)s" }
        return "\(total / 3600)h \(total % 3600 / 60)m"
    }

    private var formattedWPM: String {
        guard stats.totalRecordingSeconds > 0 else { return "—" }
        let wpm = Double(stats.totalWords) / (stats.totalRecordingSeconds / 60.0)
        return String(format: "%.0f", wpm)
    }

    private var mostUsedTone: String {
        guard let top = stats.toneUsage.max(by: { $0.value < $1.value }) else { return "—" }
        return TonePreset(rawValue: top.key)?.displayName ?? top.key.capitalized
    }

    private var formattedTimeSaved: String {
        guard stats.totalWords > 0 else { return "—" }
        let typingMinutes = Double(stats.totalWords) / 40.0
        let dictationMinutes = stats.totalRecordingSeconds / 60.0
        let savedMinutes = max(0, typingMinutes - dictationMinutes)
        if savedMinutes < 1 { return "< 1 min" }
        if savedMinutes < 60 { return "\(Int(savedMinutes)) min" }
        return String(format: "%.1f hrs", savedMinutes / 60.0)
    }
}

// MARK: - Shared Components

struct CleanupRuleToggle: View {
    let rule: CleanupRule
    @AppStorage private var isEnabled: Bool

    init(rule: CleanupRule) {
        self.rule = rule
        _isEnabled = AppStorage(wrappedValue: false, rule.defaultsKey)
    }

    var body: some View {
        Toggle(rule.displayName, isOn: $isEnabled)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
