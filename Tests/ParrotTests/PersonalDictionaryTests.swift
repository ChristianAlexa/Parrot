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

    // MARK: - Export / Import

    func testExportDataReturnsNilWhenEmpty() {
        XCTAssertNil(PersonalDictionary.exportData())
    }

    func testExportImportRoundTrips() throws {
        let words = ["Parrot", "llama.cpp", "Whisper"]
        PersonalDictionary.save(words)

        let data = try XCTUnwrap(PersonalDictionary.exportData())

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("dict-test.json")
        try data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let imported = try PersonalDictionary.importWords(from: tempURL)
        XCTAssertEqual(Set(imported), Set(words))
    }

    func testImportCapsAtMaxEntries() throws {
        let oversize = (0..<300).map { "word\($0)" }
        let data = try JSONEncoder().encode(oversize)

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("dict-oversize.json")
        try data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let imported = try PersonalDictionary.importWords(from: tempURL)
        XCTAssertEqual(imported.count, PersonalDictionary.maxEntries)
    }

    func testImportThrowsOnInvalidJSON() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("dict-bad.json")
        try Data("not json".utf8).write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        XCTAssertThrowsError(try PersonalDictionary.importWords(from: tempURL))
    }
}
