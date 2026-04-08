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

    // MARK: - postProcess (other presets pass through)

    func testNeutralPassesThrough() {
        let input = "Hello, World! It's fine."
        XCTAssertEqual(TonePreset.neutral.postProcess(input), input)
    }

    func testProfessionalPassesThrough() {
        let input = "Hello, World! It's fine."
        XCTAssertEqual(TonePreset.professional.postProcess(input), input)
    }

    func testCasualPassesThrough() {
        let input = "Hello, World! It's fine."
        XCTAssertEqual(TonePreset.casual.postProcess(input), input)
    }

    func testTechnicalPassesThrough() {
        let input = "Hello, World! It's fine."
        XCTAssertEqual(TonePreset.technical.postProcess(input), input)
    }

    // MARK: - displayName

    func testDisplayNames() {
        XCTAssertEqual(TonePreset.neutral.displayName, "Neutral")
        XCTAssertEqual(TonePreset.professional.displayName, "Professional")
        XCTAssertEqual(TonePreset.casual.displayName, "Casual")
        XCTAssertEqual(TonePreset.technical.displayName, "Technical")
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

    // MARK: - Trailing punctuation (neutral, professional, technical)

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

    func testProfessionalAddsPeriodWhenMissing() {
        XCTAssertEqual(TonePreset.professional.postProcess("Hello world"), "Hello world.")
    }

    func testTechnicalAddsPeriodWhenMissing() {
        XCTAssertEqual(TonePreset.technical.postProcess("Hello world"), "Hello world.")
    }

    func testCasualDoesNotAddPeriod() {
        XCTAssertEqual(TonePreset.casual.postProcess("Hello world"), "Hello world")
    }

    func testTrailingPunctuationOnEmptyString() {
        XCTAssertEqual(TonePreset.neutral.postProcess(""), "")
    }

    // MARK: - Capitalize first letter (neutral, professional, technical)

    func testNeutralCapitalizesFirstLetter() {
        XCTAssertEqual(TonePreset.neutral.postProcess("hello world."), "Hello world.")
    }

    func testNeutralPreservesAlreadyCapitalized() {
        XCTAssertEqual(TonePreset.neutral.postProcess("Hello world."), "Hello world.")
    }

    func testProfessionalCapitalizesFirstLetter() {
        XCTAssertEqual(TonePreset.professional.postProcess("hello world."), "Hello world.")
    }

    func testTechnicalCapitalizesFirstLetter() {
        XCTAssertEqual(TonePreset.technical.postProcess("hello world."), "Hello world.")
    }

    func testCasualDoesNotCapitalize() {
        XCTAssertEqual(TonePreset.casual.postProcess("hello world"), "hello world")
    }

    func testLowkeyRemainsLowercase() {
        XCTAssertEqual(TonePreset.lowkey.postProcess("Hello World"), "hello world")
    }

    // MARK: - Collapse double spaces (neutral, professional, technical)

    func testNeutralCollapsesDoubleSpaces() {
        XCTAssertEqual(TonePreset.neutral.postProcess("Hello  world."), "Hello world.")
    }

    func testNeutralCollapsesMultipleSpaces() {
        XCTAssertEqual(TonePreset.neutral.postProcess("Hello   world   today."), "Hello world today.")
    }

    func testProfessionalCollapsesDoubleSpaces() {
        XCTAssertEqual(TonePreset.professional.postProcess("Hello  world."), "Hello world.")
    }

    func testCasualDoesNotCollapseSpaces() {
        XCTAssertEqual(TonePreset.casual.postProcess("Hello  world"), "Hello  world")
    }
}
