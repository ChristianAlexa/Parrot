import SwiftUI
import AVFoundation

enum AppStatus: Equatable {
    case idle
    case recording
    case processing
    case error(String)
}

enum SetupStep {
    case accessibility
    case microphone
    case models
    case complete
}

@Observable
final class AppState {
    var status: AppStatus = .idle
    var isModelsLoaded = false
    var modelLoadingProgress: String = ""
    var isTestModeActive = false

    var accessibilityGranted: Bool = AXIsProcessTrusted()
    var microphoneAuthorized: Bool = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    var modelsConfigured: Bool = false

    var currentSetupStep: SetupStep {
        if !accessibilityGranted { return .accessibility }
        if !microphoneAuthorized { return .microphone }
        if !modelsConfigured { return .models }
        return .complete
    }

    func refreshSetupState() {
        accessibilityGranted = AXIsProcessTrusted()
        microphoneAuthorized = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        let whisper = UserDefaults.standard.string(forKey: "whisperModelPath") ?? ""
        let llm = UserDefaults.standard.string(forKey: "llamaModelPath") ?? ""
        modelsConfigured = !whisper.isEmpty && !llm.isEmpty
    }

    var statusIcon: String {
        switch status {
        case .idle:
            return isModelsLoaded ? "mic.slash" : "arrow.down.circle"
        case .recording:
            return "mic.fill"
        case .processing:
            return "ellipsis.circle"
        case .error:
            return "exclamationmark.triangle"
        }
    }

    var statusDescription: String {
        switch status {
        case .idle:
            return isModelsLoaded ? "Ready" : modelLoadingProgress
        case .recording:
            return "Recording..."
        case .processing:
            return "Processing..."
        case .error(let message):
            return "Error: \(message)"
        }
    }
}
