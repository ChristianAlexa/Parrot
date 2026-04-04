@testable import Parrot
import XCTest

final class CleanupPromptTests: XCTestCase {

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "tonePreset")
        super.tearDown()
    }

    // MARK: - userMessage

    func testUserMessageWrapsTranscriptInTags() {
        let result = CleanupPrompt.userMessage(rawTranscript: "hello world")
        XCTAssertTrue(result.contains("<transcript>"))
        XCTAssertTrue(result.contains("</transcript>"))
        XCTAssertTrue(result.contains("hello world"))
    }

    // MARK: - systemMessage

    func testSystemMessageContainsBaseRules() {
        UserDefaults.standard.removeObject(forKey: "tonePreset")
        let msg = CleanupPrompt.systemMessage
        XCTAssertTrue(msg.contains("Fix punctuation, capitalization, and spacing"))
        XCTAssertTrue(msg.contains("Remove filler words"))
        XCTAssertTrue(msg.contains("Do NOT add, remove, or rephrase content"))
    }

    func testSystemMessageIncludesToneInstruction() {
        UserDefaults.standard.set("professional", forKey: "tonePreset")
        let msg = CleanupPrompt.systemMessage
        XCTAssertTrue(msg.contains("professional and polished"))
    }

    func testSystemMessageExcludesToneInstructionForNeutral() {
        UserDefaults.standard.set("neutral", forKey: "tonePreset")
        let msg = CleanupPrompt.systemMessage
        XCTAssertTrue(msg.contains("Preserve the speaker's intended meaning, tone, and style exactly"))
        XCTAssertFalse(msg.contains("professional and polished"))
    }

    // MARK: - Tone instruction integration (self-extending)

    func testEveryNonNeutralToneAppearsInSystemMessage() {
        for preset in TonePreset.allCases where preset != .neutral {
            UserDefaults.standard.set(preset.rawValue, forKey: "tonePreset")
            let msg = CleanupPrompt.systemMessage
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
        UserDefaults.standard.removeObject(forKey: "tonePreset")
        let msg = CleanupPrompt.systemMessage
        for rule in CleanupRule.alwaysOnRules {
            XCTAssertTrue(
                msg.contains(rule.instruction),
                "\(rule.displayName) (always-on) not found in systemMessage"
            )
        }
    }

    // MARK: - buildLlamaPrompt

    func testLlamaPromptContainsChatTemplate() {
        let result = CleanupPrompt.buildLlamaPrompt(rawTranscript: "test")
        XCTAssertTrue(result.contains("<|begin_of_text|>"))
        XCTAssertTrue(result.contains("<|start_header_id|>system<|end_header_id|>"))
        XCTAssertTrue(result.contains("<|start_header_id|>user<|end_header_id|>"))
        XCTAssertTrue(result.contains("<|start_header_id|>assistant<|end_header_id|>"))
    }

    func testLlamaPromptContainsTranscript() {
        let result = CleanupPrompt.buildLlamaPrompt(rawTranscript: "hello world")
        XCTAssertTrue(result.contains("<transcript>"))
        XCTAssertTrue(result.contains("hello world"))
    }
}
