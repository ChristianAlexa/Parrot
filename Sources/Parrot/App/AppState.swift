import SwiftUI

enum AppStatus: Equatable {
    case idle
    case recording
    case processing
    case error(String)
}

@Observable
final class AppState {
    var status: AppStatus = .idle
    var isModelsLoaded = false
    var modelLoadingProgress: String = ""
    var isTestModeActive = false

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
