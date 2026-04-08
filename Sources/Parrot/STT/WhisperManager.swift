import Foundation
import os
@preconcurrency import whisper

/// Whisper STT manager — uses whisper.cpp xcframework for local transcription.
final class WhisperManager {
    private let logger = Logger(subsystem: "com.parrot", category: "Whisper")
    private var context: OpaquePointer?
    private let cancelFlag = OSAllocatedUnfairLock(initialState: false)

    var isModelLoaded: Bool { context != nil }

    func cancelTranscription() {
        cancelFlag.withLock { $0 = true }
    }

    func unloadModel() {
        cancelTranscription()
        if let context {
            whisper_free(context)
            self.context = nil
        }
    }

    deinit {
        unloadModel()
    }

    func loadModel(at path: String) async throws {
        logger.info("Loading Whisper model from: \(path)")
        ActivityLog.shared.log(.info, category: "Whisper", message: "Loading Whisper model from: \(path)")

        guard FileManager.default.fileExists(atPath: path) else {
            throw WhisperError.modelNotFound(path)
        }

        // Signal any in-flight transcription to bail out
        cancelTranscription()

        // Free any previously loaded model
        if let context {
            whisper_free(context)
            self.context = nil
        }

        var params = whisper_context_default_params()
        #if !targetEnvironment(simulator)
        params.flash_attn = true
        #endif

        // Run the heavy C model load on a dedicated thread to avoid blocking
        // the Swift cooperative thread pool during the ~1.6GB file read + Metal init.
        let paramsCopy = params
        let ctx: OpaquePointer = try await withCheckedThrowingContinuation { continuation in
            Thread.detachNewThread {
                if let ctx = whisper_init_from_file_with_params(path, paramsCopy) {
                    continuation.resume(returning: ctx)
                } else {
                    continuation.resume(throwing: WhisperError.transcriptionFailed("Failed to initialize Whisper context from: \(path)"))
                }
            }
        }

        context = ctx
        logger.info("Whisper model loaded successfully")
        ActivityLog.shared.log(.info, category: "Whisper", message: "Whisper model loaded successfully")
    }

    func transcribe(samples: [Float], sampleRate: Double = 16000, initialPrompt: String? = nil) async throws -> String {
        cancelFlag.withLock { $0 = false }

        guard let context else {
            throw WhisperError.modelNotLoaded
        }

        if cancelFlag.withLock({ $0 }) { throw CancellationError() }

        let duration = Double(samples.count) / sampleRate
        logger.info("Transcribing \(String(format: "%.1f", duration))s of audio...")
        ActivityLog.shared.log(.info, category: "Whisper", message: "Transcribing \(String(format: "%.1f", duration))s of audio...")

        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.n_threads = Int32(max(1, ProcessInfo.processInfo.processorCount - 2))
        params.print_progress = false
        params.print_timestamps = false

        func runWhisper(_ params: inout whisper_full_params) -> Int32 {
            samples.withUnsafeBufferPointer { buffer in
                whisper_full(context, params, buffer.baseAddress, Int32(samples.count))
            }
        }

        let result: Int32
        if let initialPrompt {
            result = initialPrompt.withCString { cStr in
                params.initial_prompt = cStr
                return runWhisper(&params)
            }
        } else {
            result = runWhisper(&params)
        }

        guard result == 0 else {
            throw WhisperError.transcriptionFailed("whisper_full returned error code \(result)")
        }

        let segmentCount = whisper_full_n_segments(context)
        var text = ""
        for i in 0..<segmentCount {
            if let segmentText = whisper_full_get_segment_text(context, i) {
                text += String(cString: segmentText)
            }
        }

        var cleaned = text.trimmingCharacters(in: .whitespaces)
        while cleaned.hasPrefix("-") {
            cleaned = String(cleaned.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        return cleaned
    }
}

enum WhisperError: Error, LocalizedError {
    case modelNotFound(String)
    case modelNotLoaded
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotFound(let path): return "Whisper model not found at: \(path)"
        case .modelNotLoaded: return "Whisper model not loaded"
        case .transcriptionFailed(let msg): return "Transcription failed: \(msg)"
        }
    }
}
