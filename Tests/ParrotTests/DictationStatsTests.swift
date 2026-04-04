@testable import Parrot
import XCTest

final class DictationStatsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "dictationStats")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "dictationStats")
        super.tearDown()
    }

    func testLoadReturnsZeroedDefaults() {
        let stats = DictationStats.load()
        XCTAssertEqual(stats.totalWords, 0)
        XCTAssertEqual(stats.totalDictations, 0)
        XCTAssertEqual(stats.totalRecordingSeconds, 0.0)
        XCTAssertTrue(stats.toneUsage.isEmpty)
    }

    func testSaveAndLoadRoundTrips() {
        var stats = DictationStatsData()
        stats.totalWords = 42
        stats.totalDictations = 3
        stats.totalRecordingSeconds = 12.5
        stats.toneUsage = ["lowkey": 2, "neutral": 1]
        DictationStats.save(stats)

        let loaded = DictationStats.load()
        XCTAssertEqual(loaded.totalWords, 42)
        XCTAssertEqual(loaded.totalDictations, 3)
        XCTAssertEqual(loaded.totalRecordingSeconds, 12.5)
        XCTAssertEqual(loaded.toneUsage["lowkey"], 2)
        XCTAssertEqual(loaded.toneUsage["neutral"], 1)
    }

    func testRecordIncrementsStats() {
        DictationStats.record(wordCount: 10, durationSeconds: 3.0, tonePreset: "lowkey")

        let stats = DictationStats.load()
        XCTAssertEqual(stats.totalWords, 10)
        XCTAssertEqual(stats.totalDictations, 1)
        XCTAssertEqual(stats.totalRecordingSeconds, 3.0)
        XCTAssertEqual(stats.toneUsage["lowkey"], 1)
    }

    func testRecordAccumulatesAcrossCalls() {
        DictationStats.record(wordCount: 10, durationSeconds: 3.0, tonePreset: "lowkey")
        DictationStats.record(wordCount: 5, durationSeconds: 2.0, tonePreset: "neutral")
        DictationStats.record(wordCount: 8, durationSeconds: 4.0, tonePreset: "lowkey")

        let stats = DictationStats.load()
        XCTAssertEqual(stats.totalWords, 23)
        XCTAssertEqual(stats.totalDictations, 3)
        XCTAssertEqual(stats.totalRecordingSeconds, 9.0)
        XCTAssertEqual(stats.toneUsage["lowkey"], 2)
        XCTAssertEqual(stats.toneUsage["neutral"], 1)
    }

    func testResetClearsEverything() {
        DictationStats.record(wordCount: 10, durationSeconds: 3.0, tonePreset: "lowkey")
        DictationStats.reset()

        let stats = DictationStats.load()
        XCTAssertEqual(stats.totalWords, 0)
        XCTAssertEqual(stats.totalDictations, 0)
        XCTAssertEqual(stats.totalRecordingSeconds, 0.0)
        XCTAssertTrue(stats.toneUsage.isEmpty)
    }
}
