@testable import Parrot
import XCTest

final class TranscriptionPipelineTests: XCTestCase {

    // MARK: - validateAudio

    func testValidAudioPasses() {
        // 1 second of audio at 16kHz, amplitude 0.5
        let samples = [Float](repeating: 0.5, count: 16000)
        XCTAssertEqual(TranscriptionPipeline.validateAudio(samples), .valid)
    }

    func testTooFewSamplesReturnsTooShort() {
        // Less than 0.5s at 16kHz
        let samples = [Float](repeating: 0.5, count: 100)
        XCTAssertEqual(TranscriptionPipeline.validateAudio(samples), .tooShort)
    }

    func testEmptySamplesReturnsTooShort() {
        XCTAssertEqual(TranscriptionPipeline.validateAudio([]), .tooShort)
    }

    func testSilentAudioReturnsTooQuiet() {
        // Enough samples but all zeros (RMS = 0)
        let samples = [Float](repeating: 0.0, count: 16000)
        XCTAssertEqual(TranscriptionPipeline.validateAudio(samples), .tooQuiet)
    }

    func testBarelyBelowThresholdReturnsTooQuiet() {
        // RMS just below 0.005
        let amplitude: Float = 0.004
        let samples = [Float](repeating: amplitude, count: 16000)
        XCTAssertEqual(TranscriptionPipeline.validateAudio(samples), .tooQuiet)
    }

    func testAboveThresholdPasses() {
        // RMS above 0.005
        let amplitude: Float = 0.006
        let samples = [Float](repeating: amplitude, count: 16000)
        XCTAssertEqual(TranscriptionPipeline.validateAudio(samples), .valid)
    }

    func testExactMinSampleCountPasses() {
        let count = TranscriptionPipeline.minSampleCount
        let samples = [Float](repeating: 0.5, count: count)
        XCTAssertEqual(TranscriptionPipeline.validateAudio(samples), .valid)
    }

    func testOneBelowMinSampleCountFails() {
        let count = TranscriptionPipeline.minSampleCount - 1
        let samples = [Float](repeating: 0.5, count: count)
        XCTAssertEqual(TranscriptionPipeline.validateAudio(samples), .tooShort)
    }

    // MARK: - applyCleanup

    func testApplyCleanupWithNoLLM() {
        let result = TranscriptionPipeline.applyCleanup(
            rawTranscript: "Hello world",
            llmResult: nil,
            tone: .neutral
        )
        XCTAssertEqual(result, "Hello world.")
    }

    func testApplyCleanupWithLLMResult() {
        let result = TranscriptionPipeline.applyCleanup(
            rawTranscript: "um hello world",
            llmResult: "Hello world.",
            tone: .neutral
        )
        XCTAssertEqual(result, "Hello world.")
    }

    func testApplyCleanupWithLowkeyNoLLM() {
        let result = TranscriptionPipeline.applyCleanup(
            rawTranscript: "Hello, World!",
            llmResult: nil,
            tone: .lowkey
        )
        XCTAssertEqual(result, "hello world")
    }

    func testApplyCleanupWithLowkeyAndLLM() {
        let result = TranscriptionPipeline.applyCleanup(
            rawTranscript: "um hello world",
            llmResult: "Hello, World!",
            tone: .lowkey
        )
        XCTAssertEqual(result, "hello world")
    }

    func testApplyCleanupLowkeyAlwaysAppliesRegardlessOfLLM() {
        // This is the exact regression that prompted all of this
        let withLLM = TranscriptionPipeline.applyCleanup(
            rawTranscript: "it didn't work",
            llmResult: "It didn't work.",
            tone: .lowkey
        )
        let withoutLLM = TranscriptionPipeline.applyCleanup(
            rawTranscript: "It didn't work.",
            llmResult: nil,
            tone: .lowkey
        )
        // Both paths must produce lowercase, no apostrophes
        XCTAssertEqual(withLLM, "it didnt work.")
        XCTAssertEqual(withoutLLM, "it didnt work.")
    }

    // MARK: - Tone selection wiring (end-to-end deterministic chain)

    func testToneSelectionFlowsThroughEntireChain() {
        let sampleInput = "Well, I don't think it's working!"

        for preset in TonePreset.allCases {
            // 1. Tone instruction → LLM prompt
            let prompt = CleanupPrompt.buildLlamaPrompt(rawTranscript: sampleInput, tone: preset)
            if let instruction = preset.instruction {
                XCTAssertTrue(
                    prompt.contains(instruction),
                    "\(preset.displayName): instruction missing from LLM prompt"
                )
            }

            // 2. applyCleanup honors tone with LLM result
            let withLLM = TranscriptionPipeline.applyCleanup(
                rawTranscript: sampleInput,
                llmResult: sampleInput,
                tone: preset
            )
            XCTAssertEqual(
                withLLM, preset.postProcess(sampleInput),
                "\(preset.displayName): applyCleanup with LLM should match postProcess"
            )

            // 3. applyCleanup honors tone WITHOUT LLM (the exact regression path)
            let withoutLLM = TranscriptionPipeline.applyCleanup(
                rawTranscript: sampleInput,
                llmResult: nil,
                tone: preset
            )
            XCTAssertEqual(
                withoutLLM, preset.postProcess(sampleInput),
                "\(preset.displayName): applyCleanup WITHOUT LLM should match postProcess"
            )
        }
    }

    func testEveryToneProducesDistinctExpectedOutput() {
        let input = "Hello, I don't think it's right!"

        // Lowkey should differ from input; others should match input exactly
        for preset in TonePreset.allCases {
            let result = TranscriptionPipeline.applyCleanup(
                rawTranscript: input, llmResult: nil, tone: preset
            )
            if preset == .lowkey {
                XCTAssertNotEqual(result, input, "Lowkey must transform the text")
                XCTAssertEqual(result, result.lowercased(), "Lowkey output must be lowercase")
                XCTAssertFalse(result.contains("'"), "Lowkey output must not contain apostrophes")
                XCTAssertFalse(result.contains("\u{2019}"), "Lowkey output must not contain curly apostrophes")
                XCTAssertFalse(result.contains(","), "Lowkey output must not contain commas")
                XCTAssertFalse(result.contains("!"), "Lowkey output must not contain exclamation marks")
            } else {
                XCTAssertEqual(
                    result, input,
                    "\(preset.displayName) should pass text through unchanged"
                )
            }
        }
    }
}
