@testable import Parrot
import XCTest

final class CleanupPromptTests: XCTestCase {

    // MARK: - userMessage

    func testUserMessageWrapsTranscriptInTags() {
        let result = CleanupPrompt.userMessage(rawTranscript: "hello world")
        XCTAssertTrue(result.contains("<transcript>"))
        XCTAssertTrue(result.contains("</transcript>"))
        XCTAssertTrue(result.contains("hello world"))
    }

    // MARK: - systemMessage

    func testSystemMessageContainsBaseRules() {
        let msg = CleanupPrompt.systemMessage(tone: .neutral)
        XCTAssertTrue(msg.contains("Fix punctuation, capitalization, and spacing"))
        XCTAssertTrue(msg.contains("Remove filler words"))
        XCTAssertTrue(msg.contains("Do NOT add, remove, or rephrase content"))
    }

    func testSystemMessageIncludesToneInstruction() {
        let msg = CleanupPrompt.systemMessage(tone: .lowkey)
        XCTAssertTrue(msg.contains("Format like a casual text message"))
    }

    func testSystemMessageExcludesToneInstructionForNeutral() {
        let msg = CleanupPrompt.systemMessage(tone: .neutral)
        XCTAssertTrue(msg.contains("Preserve the speaker's intended meaning, tone, and style exactly"))
        XCTAssertFalse(msg.contains("Format like a casual text message"))
    }

    // MARK: - Tone instruction integration (self-extending)

    func testEveryNonNeutralToneAppearsInSystemMessage() {
        for preset in TonePreset.allCases where preset != .neutral {
            let msg = CleanupPrompt.systemMessage(tone: preset)
            guard let instruction = preset.instruction else {
                XCTFail("\(preset.displayName) has no instruction but is non-neutral")
                continue
            }
            XCTAssertTrue(
                msg.contains(instruction),
                "\(preset.displayName) instruction not found in systemMessage"
            )
        }
    }

    func testEveryAlwaysOnRuleAppearsInSystemMessage() {
        let msg = CleanupPrompt.systemMessage(tone: .neutral)
        for rule in CleanupRule.alwaysOnRules {
            XCTAssertTrue(
                msg.contains(rule.instruction),
                "\(rule.displayName) (always-on) not found in systemMessage"
            )
        }
    }

    // MARK: - buildLlamaPrompt

    func testLlamaPromptContainsChatTemplate() {
        let result = CleanupPrompt.buildLlamaPrompt(rawTranscript: "test", tone: .neutral)
        XCTAssertTrue(result.contains("<|begin_of_text|>"))
        XCTAssertTrue(result.contains("<|start_header_id|>system<|end_header_id|>"))
        XCTAssertTrue(result.contains("<|start_header_id|>user<|end_header_id|>"))
        XCTAssertTrue(result.contains("<|start_header_id|>assistant<|end_header_id|>"))
    }

    func testLlamaPromptContainsTranscript() {
        let result = CleanupPrompt.buildLlamaPrompt(rawTranscript: "hello world", tone: .neutral)
        XCTAssertTrue(result.contains("<transcript>"))
        XCTAssertTrue(result.contains("hello world"))
    }

    // MARK: - Llama3PromptFormatter

    func testLlama3FormatterProducesExactChatTemplate() {
        let formatter = Llama3PromptFormatter()
        let result = formatter.format(systemMessage: "SYS", userMessage: "USR")
        let expected = """
        <|begin_of_text|><|start_header_id|>system<|end_header_id|>

        SYS<|eot_id|><|start_header_id|>user<|end_header_id|>

        USR<|eot_id|><|start_header_id|>assistant<|end_header_id|>

        """
        XCTAssertEqual(result, expected)
    }

    func testBuildLlamaPromptDelegatesToFormatter() {
        // Byte-identical guarantee: buildLlamaPrompt must equal the formatter
        // applied to the same system + user messages it would have built inline.
        let raw = "abc"
        let tone: TonePreset = .neutral
        let viaCleanupPrompt = CleanupPrompt.buildLlamaPrompt(rawTranscript: raw, tone: tone)
        let viaFormatter = Llama3PromptFormatter().format(
            systemMessage: CleanupPrompt.systemMessage(tone: tone),
            userMessage: CleanupPrompt.userMessage(rawTranscript: raw)
        )
        XCTAssertEqual(viaCleanupPrompt, viaFormatter)
    }
}
