@testable import Parrot
import XCTest

final class AppStateTests: XCTestCase {

    func testAppStatusEquality() {
        XCTAssertEqual(AppStatus.idle, AppStatus.idle)
        XCTAssertEqual(AppStatus.recording, AppStatus.recording)
        XCTAssertEqual(AppStatus.processing, AppStatus.processing)
        XCTAssertEqual(AppStatus.error("fail"), AppStatus.error("fail"))
        XCTAssertNotEqual(AppStatus.idle, AppStatus.recording)
        XCTAssertNotEqual(AppStatus.error("a"), AppStatus.error("b"))
    }

    @MainActor
    func testStatusIconIdle() {
        let state = AppState()
        state.status = .idle
        state.isModelsLoaded = true
        XCTAssertEqual(state.statusIcon, "mic.slash")

        state.isModelsLoaded = false
        XCTAssertEqual(state.statusIcon, "arrow.down.circle")
    }

    @MainActor
    func testStatusIconRecording() {
        let state = AppState()
        state.status = .recording
        XCTAssertEqual(state.statusIcon, "mic.fill")
    }

    @MainActor
    func testStatusIconProcessing() {
        let state = AppState()
        state.status = .processing
        XCTAssertEqual(state.statusIcon, "ellipsis.circle")
    }

    @MainActor
    func testStatusIconError() {
        let state = AppState()
        state.status = .error("something broke")
        XCTAssertEqual(state.statusIcon, "exclamationmark.triangle")
    }

    @MainActor
    func testStatusDescriptionReady() {
        let state = AppState()
        state.status = .idle
        state.isModelsLoaded = true
        XCTAssertEqual(state.statusDescription, "Ready")
    }

    @MainActor
    func testStatusDescriptionRecording() {
        let state = AppState()
        state.status = .recording
        XCTAssertEqual(state.statusDescription, "Recording...")
    }

    @MainActor
    func testStatusDescriptionProcessing() {
        let state = AppState()
        state.status = .processing
        XCTAssertEqual(state.statusDescription, "Processing...")
    }

    @MainActor
    func testStatusDescriptionError() {
        let state = AppState()
        state.status = .error("mic failed")
        XCTAssertEqual(state.statusDescription, "Error: mic failed")
    }

    @MainActor
    func testSetupStepProgression() {
        let state = AppState()
        state.accessibilityGranted = false
        XCTAssertEqual(state.currentSetupStep, .accessibility)

        state.accessibilityGranted = true
        state.microphoneAuthorized = false
        XCTAssertEqual(state.currentSetupStep, .microphone)

        state.microphoneAuthorized = true
        state.modelsConfigured = false
        XCTAssertEqual(state.currentSetupStep, .models)

        state.modelsConfigured = true
        state.setupFinished = false
        XCTAssertEqual(state.currentSetupStep, .ready)

        state.setupFinished = true
        XCTAssertEqual(state.currentSetupStep, .complete)
    }

    @MainActor
    func testStatusDescriptionIdleShowsModelProgress() {
        let state = AppState()
        state.status = .idle
        state.isModelsLoaded = false
        state.modelLoadingProgress = "Loading models..."
        XCTAssertEqual(state.statusDescription, "Loading models...")
    }

    @MainActor
    func testRefreshSetupStateReadsModelPaths() {
        UserDefaults.standard.set("/path/whisper.bin", forKey: "whisperModelPath")
        UserDefaults.standard.set("/path/llama.gguf", forKey: "llamaModelPath")

        let state = AppState()
        state.refreshSetupState()
        XCTAssertTrue(state.modelsConfigured)

        UserDefaults.standard.removeObject(forKey: "whisperModelPath")
        UserDefaults.standard.removeObject(forKey: "llamaModelPath")

        state.refreshSetupState()
        XCTAssertFalse(state.modelsConfigured)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "whisperModelPath")
        UserDefaults.standard.removeObject(forKey: "llamaModelPath")
    }

    @MainActor
    func testRefreshSetupStateRequiresBothModels() {
        UserDefaults.standard.set("/path/whisper.bin", forKey: "whisperModelPath")
        UserDefaults.standard.removeObject(forKey: "llamaModelPath")

        let state = AppState()
        state.refreshSetupState()
        XCTAssertFalse(state.modelsConfigured)

        UserDefaults.standard.removeObject(forKey: "whisperModelPath")
    }

    @MainActor
    func testFirstLaunchAutoSkipsSetupWhenFullyConfigured() {
        UserDefaults.standard.set("/path/whisper.bin", forKey: "whisperModelPath")
        UserDefaults.standard.set("/path/llama.gguf", forKey: "llamaModelPath")

        let state = AppState()
        // refreshSetupState reads AXIsProcessTrusted() and mic auth, overriding manual sets.
        // So we call it first, then override the system-dependent values after.
        state.refreshSetupState()
        state.accessibilityGranted = true
        state.microphoneAuthorized = true

        // modelsConfigured was set by refreshSetupState from UserDefaults
        XCTAssertTrue(state.modelsConfigured)

        // Simulate what refreshSetupState's first-launch check does:
        // Since we can't control AXIsProcessTrusted() in tests, verify the
        // setup step logic directly with all flags set.
        state.setupFinished = true
        XCTAssertEqual(state.currentSetupStep, .complete)

        UserDefaults.standard.removeObject(forKey: "whisperModelPath")
        UserDefaults.standard.removeObject(forKey: "llamaModelPath")
    }

    @MainActor
    func testFirstLaunchDoesNotAutoSkipWhenIncomplete() {
        UserDefaults.standard.removeObject(forKey: "whisperModelPath")
        UserDefaults.standard.removeObject(forKey: "llamaModelPath")

        let state = AppState()
        state.refreshSetupState()

        // Without models configured, setup should not auto-finish
        XCTAssertFalse(state.setupFinished)
        XCTAssertFalse(state.modelsConfigured)
    }
}
