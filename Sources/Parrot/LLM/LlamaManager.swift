import Foundation
import os
@preconcurrency import llama

final class LlamaManager {
    private let logger = Logger(subsystem: "com.parrot", category: "Llama")
    private var model: OpaquePointer?
    private var context: OpaquePointer?
    private var sampler: UnsafeMutablePointer<llama_sampler>?

    private static var backendInitialized = false
    private let maxTokens: Int32 = 512
    private let cancelFlag = OSAllocatedUnfairLock(initialState: false)
    /// Guards model/context/sampler pointers so unloadModel waits for inference to finish.
    private let inferenceLock = NSLock()

    func cancelInference() {
        cancelFlag.withLock { $0 = true }
    }

    func unloadModel() {
        cancelInference()
        inferenceLock.lock()
        defer { inferenceLock.unlock() }
        if let sampler { llama_sampler_free(sampler); self.sampler = nil }
        if let context { llama_free(context); self.context = nil }
        if let model { llama_model_free(model); self.model = nil }
    }

    deinit {
        unloadModel()
    }

    func loadModel(at path: String) async throws {
        logger.info("Loading LLM model from: \(path)")
        ActivityLog.shared.log(.info, category: "Llama", message: "Loading LLM model from: \(path)")

        guard FileManager.default.fileExists(atPath: path) else {
            throw LlamaError.modelNotFound(path)
        }

        // Signal any in-flight inference thread to stop, then wait for it to finish
        cancelInference()
        inferenceLock.lock()
        defer { inferenceLock.unlock() }

        // Free any previously loaded model
        if let sampler { llama_sampler_free(sampler); self.sampler = nil }
        if let context { llama_free(context); self.context = nil }
        if let model { llama_model_free(model); self.model = nil }

        let (loadedModel, loadedContext, loadedSampler): (OpaquePointer, OpaquePointer, UnsafeMutablePointer<llama_sampler>) =
            try await withCheckedThrowingContinuation { continuation in
                Thread.detachNewThread { [logger] in
                    if !LlamaManager.backendInitialized {
                        llama_backend_init()
                        LlamaManager.backendInitialized = true
                    }

                    var modelParams = llama_model_default_params()
                    modelParams.n_gpu_layers = 999 // Full Metal offload

                    guard let mdl = llama_model_load_from_file(path, modelParams) else {
                        continuation.resume(throwing: LlamaError.inferenceFailed("Failed to load model from: \(path)"))
                        return
                    }

                    var ctxParams = llama_context_default_params()
                    ctxParams.n_ctx = 2048
                    ctxParams.n_batch = 512

                    guard let ctx = llama_init_from_model(mdl, ctxParams) else {
                        llama_model_free(mdl)
                        continuation.resume(throwing: LlamaError.inferenceFailed("Failed to create context"))
                        return
                    }

                    let sparams = llama_sampler_chain_default_params()
                    let smpl = llama_sampler_chain_init(sparams)!
                    llama_sampler_chain_add(smpl, llama_sampler_init_greedy())

                    logger.info("LLM model loaded successfully")
                    ActivityLog.shared.log(.info, category: "Llama", message: "LLM model loaded successfully")
                    continuation.resume(returning: (mdl, ctx, smpl))
                }
            }

        model = loadedModel
        context = loadedContext
        sampler = loadedSampler
    }

    func cleanup(rawTranscript: String) async throws -> String {
        guard let model, let context, let sampler else {
            throw LlamaError.modelNotLoaded
        }

        let prompt = CleanupPrompt.buildLlamaPrompt(rawTranscript: rawTranscript)
        logger.info("Cleaning up transcript (\(rawTranscript.count) chars)...")
        ActivityLog.shared.log(.info, category: "Llama", message: "Cleaning up transcript (\(rawTranscript.count) chars)...")

        cancelFlag.withLock { $0 = false }

        // Clear KV cache and sampler state from any previous inference
        llama_memory_clear(llama_get_memory(context), true)
        llama_sampler_reset(sampler)

        let cancelFlag = self.cancelFlag
        let inferenceLock = self.inferenceLock
        let result: String = try await withCheckedThrowingContinuation { continuation in
            nonisolated(unsafe) let model = model
            nonisolated(unsafe) let context = context
            nonisolated(unsafe) let sampler = sampler
            Thread.detachNewThread { [logger, maxTokens] in
                inferenceLock.lock()
                defer { inferenceLock.unlock() }
                let vocab = llama_model_get_vocab(model)

                // Tokenize the prompt
                let promptCStr = prompt.cString(using: .utf8)!
                let nPromptTokensEstimate = Int32(promptCStr.count) + 32
                var tokens = [llama_token](repeating: 0, count: Int(nPromptTokensEstimate))
                let nTokens = llama_tokenize(vocab, promptCStr, Int32(promptCStr.count - 1), &tokens, nPromptTokensEstimate, false, true)

                guard nTokens > 0 else {
                    continuation.resume(throwing: LlamaError.inferenceFailed("Tokenization failed"))
                    return
                }
                tokens.removeSubrange(Int(nTokens)...)

                // Process prompt
                let batch = llama_batch_get_one(&tokens, nTokens)
                let decodeResult = llama_decode(context, batch)
                guard decodeResult == 0 else {
                    continuation.resume(throwing: LlamaError.inferenceFailed("Prompt decode failed with code \(decodeResult)"))
                    return
                }

                if cancelFlag.withLock({ $0 }) {
                    continuation.resume(throwing: CancellationError())
                    return
                }

                // Autoregressive generation
                let eosToken = llama_vocab_eos(vocab)
                let eotToken = llama_vocab_eot(vocab)
                var outputText = ""
                var pieceBuf = [CChar](repeating: 0, count: 256)

                for _ in 0..<maxTokens {
                    if cancelFlag.withLock({ $0 }) {
                        continuation.resume(throwing: CancellationError())
                        return
                    }

                    let newToken = llama_sampler_sample(sampler, context, -1)

                    if newToken == eosToken || newToken == eotToken {
                        break
                    }

                    let nChars = llama_token_to_piece(vocab, newToken, &pieceBuf, Int32(pieceBuf.count), 0, false)
                    if nChars > 0 {
                        pieceBuf[Int(nChars)] = 0
                        outputText += String(cString: pieceBuf)
                    }

                    // Decode the new token
                    var nextTokens = [newToken]
                    let nextBatch = llama_batch_get_one(&nextTokens, 1)
                    let nextResult = llama_decode(context, nextBatch)
                    if nextResult != 0 {
                        logger.error("Token decode failed with code \(nextResult)")
                        ActivityLog.shared.log(.error, category: "Llama", message: "Token decode failed with code \(nextResult)")
                        break
                    }
                }

                continuation.resume(returning: outputText.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        let cleaned = result
            .replacingOccurrences(of: "<transcript>", with: "")
            .replacingOccurrences(of: "</transcript>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        logger.info("Cleanup complete (\(cleaned.count) chars)")
        ActivityLog.shared.log(.info, category: "Llama", message: "Cleanup complete (\(cleaned.count) chars)")
        return cleaned
    }

    var isModelLoaded: Bool { model != nil && context != nil }
}

enum LlamaError: Error, LocalizedError {
    case modelNotFound(String)
    case modelNotLoaded
    case inferenceFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotFound(let path): return "LLM model not found at: \(path)"
        case .modelNotLoaded: return "LLM model not loaded"
        case .inferenceFailed(let msg): return "LLM inference failed: \(msg)"
        }
    }
}
