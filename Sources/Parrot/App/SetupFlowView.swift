import SwiftUI
import AVFoundation

@MainActor
struct SetupFlowView: View {
    @Bindable private var appState = sharedAppState
    @AppStorage("whisperModelPath") private var whisperModelPath: String = ""
    @AppStorage("llamaModelPath") private var llamaModelPath: String = ""

    @State private var whisperModels: [URL] = []
    @State private var llmModels: [URL] = []
    @State private var pollTimer: Timer?

    private let modelManager = ModelManager()

    private var stepIndex: Int {
        switch appState.currentSetupStep {
        case .accessibility: return 0
        case .microphone: return 1
        case .models: return 2
        case .complete: return 3
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                HStack {
                    Text("Parrot")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                // Step indicator
                HStack(spacing: 0) {
                    ForEach(0..<3) { index in
                        if index > 0 {
                            Rectangle()
                                .fill(index <= stepIndex ? Color.accentColor : Color.primary.opacity(0.1))
                                .frame(height: 2)
                        }
                        Circle()
                            .fill(index < stepIndex ? Color.accentColor : (index == stepIndex ? Color.accentColor : Color.primary.opacity(0.12)))
                            .frame(width: 10, height: 10)
                            .overlay {
                                if index < stepIndex {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 6, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                }
                .padding(.horizontal, 40)

                // Step labels
                HStack {
                    Text("Access")
                    Spacer()
                    Text("Mic")
                    Spacer()
                    Text("Models")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            }
            .padding(.bottom, 8)

            Divider()
                .padding(.horizontal, 12)

            // Step content
            ScrollView {
                Group {
                    switch appState.currentSetupStep {
                    case .accessibility:
                        accessibilityStep
                    case .microphone:
                        microphoneStep
                    case .models:
                        modelsStep
                    case .complete:
                        EmptyView()
                    }
                }
                .padding()
            }

            Spacer()

            // Quit button
            Divider()
                .padding(.horizontal, 12)
            Button { _exit(0) } label: {
                HStack(spacing: 4) {
                    Image(systemName: "power")
                        .font(.system(size: 10))
                    Text("Quit")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            appState.refreshSetupState()
            startPolling()
        }
        .onDisappear {
            stopPolling()
        }
    }

    // MARK: - Accessibility Step

    private var accessibilityStep: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 20)

            Image(systemName: "accessibility")
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 8) {
                Text("Accessibility Permission")
                    .font(.headline)

                Text("Parrot needs accessibility access to capture your hotkey and type dictated text into any app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            Button {
                PermissionsManager.shared.requestAccessibilityIfNeeded()
            } label: {
                Text("Open System Settings")
                    .font(.system(.body, weight: .medium))
                    .frame(maxWidth: 240)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text("After granting access, this screen will update automatically.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Microphone Step

    private var microphoneStep: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 20)

            Image(systemName: "mic.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 8) {
                Text("Microphone Permission")
                    .font(.headline)

                Text("Parrot needs microphone access to hear your voice for dictation. Audio is processed entirely on your Mac — nothing leaves your device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            if AVCaptureDevice.authorizationStatus(for: .audio) == .denied {
                Button {
                    PermissionsManager.shared.openMicrophoneSettings()
                } label: {
                    Text("Open System Settings")
                        .font(.system(.body, weight: .medium))
                        .frame(maxWidth: 240)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Text("Microphone access was previously denied. Open System Settings to grant it.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            } else {
                Button {
                    Task {
                        _ = await PermissionsManager.shared.requestMicrophoneAccess()
                        appState.refreshSetupState()
                    }
                } label: {
                    Text("Grant Microphone Access")
                        .font(.system(.body, weight: .medium))
                        .frame(maxWidth: 240)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Text("A system dialog will appear asking for permission.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Models Step

    private var modelsStep: some View {
        VStack(spacing: 12) {
            VStack(spacing: 8) {
                Image(systemName: "square.stack.3d.down.right")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.accentColor)

                Text("Download Models")
                    .font(.headline)

                Text("Parrot runs entirely on your Mac. Download one speech model and one text cleanup model to get started.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            Divider()

            // Whisper section
            HStack(spacing: 4) {
                Text("Speech-to-Text (Whisper)")
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

            // LLM section
            HStack(spacing: 4) {
                Text("Text Cleanup (LLM)")
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
        .onAppear { refreshModels() }
        .onChange(of: whisperModelPath) { _, _ in
            NotificationCenter.default.post(name: .inferenceSettingsDidChange, object: nil)
        }
        .onChange(of: llamaModelPath) { _, _ in
            NotificationCenter.default.post(name: .inferenceSettingsDidChange, object: nil)
        }
    }

    // MARK: - Helpers

    private func refreshModels() {
        whisperModels = modelManager.availableWhisperModels()
        llmModels = modelManager.availableLLMModels()
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                appState.refreshSetupState()
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}
