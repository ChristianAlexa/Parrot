@testable import Parrot
import XCTest

final class PersonalDictionaryTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "personalDictionary")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "personalDictionary")
        super.tearDown()
    }

    func testWordsReturnsEmptyWhenNoData() {
        XCTAssertEqual(PersonalDictionary.words(), [])
    }

    func testSaveAndLoadRoundTrips() {
        let words = ["Parrot", "llama.cpp", "Whisper"]
        PersonalDictionary.save(words)
        XCTAssertEqual(PersonalDictionary.words(), words)
    }

    func testWhisperPromptReturnsNilWhenEmpty() {
        XCTAssertNil(PersonalDictionary.whisperPrompt())
    }

    func testWhisperPromptReturnsCommaJoined() {
        PersonalDictionary.save(["Parrot", "Whisper"])
        XCTAssertEqual(PersonalDictionary.whisperPrompt(), "Parrot, Whisper")
    }

    func testCleanupHintReturnsNilWhenEmpty() {
        XCTAssertNil(PersonalDictionary.cleanupHint())
    }

    func testCleanupHintContainsWords() {
        PersonalDictionary.save(["Parrot", "Whisper"])
        let hint = PersonalDictionary.cleanupHint()
        XCTAssertNotNil(hint)
        XCTAssertTrue(hint!.contains("Parrot, Whisper"))
        XCTAssertTrue(hint!.contains("Preferred vocabulary"))
    }

    func testMaxEntries() {
        XCTAssertEqual(PersonalDictionary.maxEntries, 200)
    }
}
