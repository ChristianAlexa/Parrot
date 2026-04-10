@testable import Parrot
import XCTest

final class TonePresetTests: XCTestCase {

    // MARK: - postProcess (lowkey)

    func testLowkeyLowercasesText() {
        XCTAssertEqual(TonePreset.lowkey.postProcess("Hello World"), "hello world")
    }

    func testLowkeyStripsApostrophes() {
        XCTAssertEqual(TonePreset.lowkey.postProcess("don't I'm it's"), "dont im its")
    }

    func testLowkeyStripsCurlyApostrophes() {
        XCTAssertEqual(TonePreset.lowkey.postProcess("don\u{2019}t"), "dont")
    }

    func testLowkeyStripsCommas() {
        XCTAssertEqual(TonePreset.lowkey.postProcess("one, two, three"), "one two three")
    }

    func testLowkeyStripsExclamationMarks() {
        XCTAssertEqual(TonePreset.lowkey.postProcess("wow!"), "wow")
    }

    func testLowkeyCombined() {
        XCTAssertEqual(TonePreset.lowkey.postProcess("Well, it didn't fix it!"), "well it didnt fix it")
    }

    func testLowkeyPreservesPeriods() {
        XCTAssertEqual(
            TonePreset.lowkey.postProcess("This is a sentence. Another one."),
            "this is a sentence. another one."
        )
    }

    func testLowkeyCollapsesDoubleSpaces() {
        XCTAssertEqual(TonePreset.lowkey.postProcess("hello  world"), "hello world")
    }

    // MARK: - postProcess (neutral)

    func testNeutralPassesThrough() {
        let input = "Hello, World! It's fine."
        XCTAssertEqual(TonePreset.neutral.postProcess(input), input)
    }

    // MARK: - displayName

    func testDisplayNames() {
        XCTAssertEqual(TonePreset.neutral.displayName, "Neutral")
        XCTAssertEqual(TonePreset.lowkey.displayName, "Lowkey")
    }

    // MARK: - instruction

    func testNeutralInstructionIsNil() {
        XCTAssertNil(TonePreset.neutral.instruction)
    }

    func testNonNeutralInstructionsExist() {
        for preset in TonePreset.allCases where preset != .neutral {
            XCTAssertNotNil(preset.instruction, "\(preset.displayName) should have an instruction")
        }
    }

    // MARK: - Trailing punctuation (neutral)

    func testNeutralAddsPeriodWhenMissing() {
        XCTAssertEqual(TonePreset.neutral.postProcess("Hello world"), "Hello world.")
    }

    func testNeutralPreservesExistingPeriod() {
        XCTAssertEqual(TonePreset.neutral.postProcess("Hello world."), "Hello world.")
    }

    func testNeutralPreservesExistingQuestionMark() {
        XCTAssertEqual(TonePreset.neutral.postProcess("How are you?"), "How are you?")
    }

    func testNeutralPreservesExistingExclamation() {
        XCTAssertEqual(TonePreset.neutral.postProcess("Wow!"), "Wow!")
    }

    func testTrailingPunctuationOnEmptyString() {
        XCTAssertEqual(TonePreset.neutral.postProcess(""), "")
    }

    // MARK: - Capitalize first letter (neutral)

    func testNeutralCapitalizesFirstLetter() {
        XCTAssertEqual(TonePreset.neutral.postProcess("hello world."), "Hello world.")
    }

    func testNeutralPreservesAlreadyCapitalized() {
        XCTAssertEqual(TonePreset.neutral.postProcess("Hello world."), "Hello world.")
    }

    func testLowkeyRemainsLowercase() {
        XCTAssertEqual(TonePreset.lowkey.postProcess("Hello World"), "hello world")
    }

    // MARK: - Collapse double spaces (neutral)

    func testNeutralCollapsesDoubleSpaces() {
        XCTAssertEqual(TonePreset.neutral.postProcess("Hello  world."), "Hello world.")
    }

    func testNeutralCollapsesMultipleSpaces() {
        XCTAssertEqual(TonePreset.neutral.postProcess("Hello   world   today."), "Hello world today.")
    }
}
