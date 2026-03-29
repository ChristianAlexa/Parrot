import AppKit
import Foundation
import os

@MainActor
final class TranscriptionPipeline {
    private let logger = Logger(subsystem: "com.parrot", category: "Pipeline")
    private let audioCaptureManager = AudioCaptureManager()
    private let whisperManager = WhisperManager()
    private let llamaManager = LlamaManager()
    private let textInjector = TextInjector()
    private var processingTask: Task<Void, Never>?
    private var recordingTask: Task<Void, Never>?
    private var modelLoadTask: Task<Void, Never>?
    private var stopRequested = false
    private var isTestMode = false

    init() {
        NotificationCenter.default.addObserver(
            forName: .testRecordingStarted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.startTestRecording()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .testRecordingStopped,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.stopTestRecording()
            }
        }
    }

    func loadModels() {
        // Prevent new recordings while reloading
        sharedAppState.isModelsLoaded = false
        sharedAppState.modelLoadingProgress = "Loading models..."

        // Cancel any in-flight inference before reloading models
        llamaManager.cancelInference()
        whisperManager.cancelTranscription()
        processingTask?.cancel()

        let previousLoad = modelLoadTask

        modelLoadTask = Task.detached { [whisperManager, llamaManager, logger] in
            // Wait for previous load to finish so we don't race on free/assign
            await previousLoad?.value

            // If a newer loadModels() call arrived while we waited, bail out
            guard !Task.isCancelled else { return }

            let whisperPath = UserDefaults.standard.string(forKey: "whisperModelPath") ?? ""
            let llamaPath = UserDefaults.standard.string(forKey: "llamaModelPath") ?? ""

            async let whisperResult: Bool = {
                guard !whisperPath.isEmpty else {
                    logger.info("No Whisper model path configured")
                    ActivityLog.shared.log(.info, category: "Pipeline", message: "No Whisper model path configured")
                    return false
                }
                do {
                    try await whisperManager.loadModel(at: whisperPath)
                    return true
                } catch {
                    logger.error("Failed to load Whisper: \(error.localizedDescription)")
                    ActivityLog.shared.log(.error, category: "Pipeline", message: "Failed to load Whisper: \(error.localizedDescription)")
                    return false
                }
            }()

            async let llamaResult: Bool = {
                guard !llamaPath.isEmpty else {
                    logger.info("No LLM model path configured")
                    ActivityLog.shared.log(.info, category: "Pipeline", message: "No LLM model path configured")
                    return false
                }
                do {
                    try await llamaManager.loadModel(at: llamaPath)
                    return true
                } catch {
                    logger.error("Failed to load LLM: \(error.localizedDescription)")
                    ActivityLog.shared.log(.error, category: "Pipeline", message: "Failed to load LLM: \(error.localizedDescription)")
                    return false
                }
            }()

            let (whisperLoaded, llamaLoaded) = await (whisperResult, llamaResult)

            // Another load may have superseded us
            guard !Task.isCancelled else { return }

            let allLoaded = whisperLoaded && llamaLoaded
            let progressMessage: String
            if !whisperLoaded && !llamaLoaded {
                progressMessage = "Whisper and LLM models not configured"
            } else if !whisperLoaded {
                progressMessage = "Whisper model not configured"
            } else {
                progressMessage = "LLM model not configured"
            }

            await MainActor.run {
                sharedAppState.isModelsLoaded = allLoaded
                sharedAppState.modelLoadingProgress = allLoaded ? "" : progressMessage
            }
            logger.info("Model loading complete (whisper: \(whisperLoaded), llm: \(llamaLoaded))")
            ActivityLog.shared.log(.info, category: "Pipeline", message: "Model loading complete (whisper: \(whisperLoaded), llm: \(llamaLoaded))")
        }
    }

    func startRecording() {
        if sharedAppState.isTestModeActive {
            startTestRecording()
            return
        }

        guard sharedAppState.isModelsLoaded else {
            logger.warning("Recording attempted before models are loaded")
            ActivityLog.shared.log(.warning, category: "Pipeline", message: "Recording attempted before models are loaded")
            return
        }

        switch sharedAppState.status {
        case .idle, .error:
            break // OK to start recording
        case .recording, .processing:
            logger.warning("Recording attempted while status is \(String(describing: sharedAppState.status)) — ignoring")
            ActivityLog.shared.log(.warning, category: "Pipeline", message: "Recording attempted while status is \(String(describing: sharedAppState.status)) — ignoring")
            NSSound(named: "Tink")?.play()
            return
        }

        stopRequested = false
        sharedAppState.status = .recording

        recordingTask = Task {
            logger.info("Recording started")
            ActivityLog.shared.log(.info, category: "Pipeline", message: "Recording started")
            do {
                let deviceID = sharedAudioDeviceManager.effectiveDeviceID
                try await audioCaptureManager.startCapture(deviceID: deviceID)
                NSSound(named: "Pop")?.play()

                // If stop was requested while we were starting the engine, process now
                if stopRequested {
                    processRecording()
                }
            } catch {
                logger.error("Failed to start recording: \(error.localizedDescription)")
                ActivityLog.shared.log(.error, category: "Pipeline", message: "Failed to start recording: \(error.localizedDescription)")
                sharedAppState.status = .error(error.localizedDescription)
            }
        }
    }

    func stopRecordingAndProcess() {
        if isTestMode {
            stopTestRecording()
            return
        }

        guard sharedAppState.status == .recording else {
            logger.warning("stopRecordingAndProcess called while not recording — ignoring")
            ActivityLog.shared.log(.warning, category: "Pipeline", message: "stopRecordingAndProcess called while not recording — ignoring")
            return
        }

        // If the engine is still starting, flag it so startRecording handles cleanup
        stopRequested = true
        if recordingTask != nil {
            recordingTask = nil
        }

        processRecording()
    }

    private func processRecording() {
        logger.info("Recording stopped, processing...")
        ActivityLog.shared.log(.info, category: "Pipeline", message: "Recording stopped, processing...")
        sharedAppState.status = .processing

        // Signal any running detached inference thread to stop, then cancel the task
        llamaManager.cancelInference()
        processingTask?.cancel()

        processingTask = Task {
            let samples = await audioCaptureManager.stopCapture()

            // Reject recordings that are too short or too quiet (avoids whisper hallucinations)
            let minSamples = Int(16000 * 0.5) // 0.5s at 16kHz
            let rms = samples.isEmpty ? 0.0 : sqrt(samples.map { Double($0) * Double($0) }.reduce(0, +) / Double(samples.count))
            let minRMS = 0.005 // silence threshold

            guard samples.count >= minSamples, rms >= minRMS else {
                let reason = samples.count < minSamples ? "Too short" : "No audio detected — check microphone"
                logger.warning("Recording rejected (samples: \(samples.count), rms: \(String(format: "%.4f", rms))) — too short or silent")
                ActivityLog.shared.log(.warning, category: "Pipeline", message: "Recording rejected (samples: \(samples.count), rms: \(String(format: "%.4f", rms))) — too short or silent")
                sharedAppState.status = .error(reason)
                NSSound(named: "Basso")?.play()
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    if case .error = sharedAppState.status {
                        sharedAppState.status = .idle
                    }
                }
                return
            }

            do {
                let rawTranscript = try await whisperManager.transcribe(samples: samples, initialPrompt: PersonalDictionary.whisperPrompt())
                logger.info("Raw transcript: \(rawTranscript)")
                ActivityLog.shared.log(.info, category: "Pipeline", message: "Raw transcript: \(rawTranscript)")

                guard !Task.isCancelled else {
                    logger.info("Processing cancelled after transcription")
                    ActivityLog.shared.log(.info, category: "Pipeline", message: "Processing cancelled after transcription")
                    sharedAppState.status = .idle
                    return
                }

                let llmEnabled = UserDefaults.standard.bool(forKey: "llmCleanupEnabled")
                let finalText: String

                if llmEnabled, llamaManager.isModelLoaded {
                    finalText = try await llamaManager.cleanup(rawTranscript: rawTranscript)
                } else {
                    finalText = rawTranscript
                }

                textInjector.inject(finalText)

                let wordCount = finalText.split(separator: " ").count
                let duration = Double(samples.count) / 16000.0
                DictationStats.record(wordCount: wordCount, durationSeconds: duration, tonePreset: TonePreset.current.rawValue)

                let glass = NSSound(named: "Glass")
                glass?.volume = 0.2
                glass?.play()
                sharedAppState.status = .idle
            } catch {
                logger.error("Processing failed: \(error.localizedDescription)")
                ActivityLog.shared.log(.error, category: "Pipeline", message: "Processing failed: \(error.localizedDescription)")
                sharedAppState.status = .error(error.localizedDescription)
            }
        }
    }

    // MARK: - Test Recording

    private func startTestRecording() {
        guard sharedAppState.isModelsLoaded else { return }

        switch sharedAppState.status {
        case .idle, .error:
            break
        case .recording, .processing:
            return
        }

        isTestMode = true
        stopRequested = false
        sharedAppState.status = .recording

        recordingTask = Task {
            logger.info("Test recording started")
            ActivityLog.shared.log(.info, category: "Pipeline", message: "Test recording started")
            do {
                let deviceID = sharedAudioDeviceManager.effectiveDeviceID
                try await audioCaptureManager.startCapture(deviceID: deviceID)

                if stopRequested {
                    processTestRecording()
                }
            } catch {
                logger.error("Test recording failed: \(error.localizedDescription)")
                NotificationCenter.default.post(
                    name: .testTranscriptionError,
                    object: nil,
                    userInfo: ["message": error.localizedDescription]
                )
                sharedAppState.status = .idle
                isTestMode = false
            }
        }
    }

    private func stopTestRecording() {
        guard isTestMode, sharedAppState.status == .recording else { return }
        stopRequested = true
        recordingTask = nil
        processTestRecording()
    }

    private func processTestRecording() {
        sharedAppState.status = .processing

        llamaManager.cancelInference()
        processingTask?.cancel()

        processingTask = Task {
            let samples = await audioCaptureManager.stopCapture()

            let minSamples = Int(16000 * 0.5)
            let rms = samples.isEmpty ? 0.0 : sqrt(samples.map { Double($0) * Double($0) }.reduce(0, +) / Double(samples.count))

            guard samples.count >= minSamples, rms >= 0.005 else {
                let reason = samples.count < minSamples ? "Too short" : "No audio detected — check microphone"
                NotificationCenter.default.post(
                    name: .testTranscriptionError,
                    object: nil,
                    userInfo: ["message": reason]
                )
                sharedAppState.status = .idle
                isTestMode = false
                return
            }

            do {
                let rawTranscript = try await whisperManager.transcribe(samples: samples, initialPrompt: PersonalDictionary.whisperPrompt())

                let llmEnabled = UserDefaults.standard.bool(forKey: "llmCleanupEnabled")
                let finalText: String

                if llmEnabled, llamaManager.isModelLoaded {
                    finalText = try await llamaManager.cleanup(rawTranscript: rawTranscript)
                } else {
                    finalText = rawTranscript
                }

                NotificationCenter.default.post(
                    name: .testTranscriptionResult,
                    object: nil,
                    userInfo: ["text": finalText]
                )
                sharedAppState.status = .idle
            } catch {
                NotificationCenter.default.post(
                    name: .testTranscriptionError,
                    object: nil,
                    userInfo: ["message": error.localizedDescription]
                )
                sharedAppState.status = .idle
            }
            isTestMode = false
        }
    }
}
