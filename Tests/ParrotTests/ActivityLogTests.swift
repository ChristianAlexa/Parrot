@testable import Parrot
import XCTest

final class ActivityLogTests: XCTestCase {

    func testLogEntryFormattedContainsAllParts() {
        let entry = LogEntry(
            timestamp: Date(timeIntervalSince1970: 0),
            category: "Pipeline",
            level: .info,
            message: "Recording started"
        )
        let formatted = entry.formatted
        XCTAssertTrue(formatted.contains("[Pipeline]"))
        XCTAssertTrue(formatted.contains("[INFO]"))
        XCTAssertTrue(formatted.contains("Recording started"))
    }

    func testLogLevelLabels() {
        XCTAssertEqual(LogLevel.debug.label, "DEBUG")
        XCTAssertEqual(LogLevel.info.label, "INFO")
        XCTAssertEqual(LogLevel.warning.label, "WARNING")
        XCTAssertEqual(LogLevel.error.label, "ERROR")
    }

    @MainActor
    func testLogAppendsEntries() {
        let log = ActivityLog()
        log.log(.info, category: "Test", message: "one")
        log.log(.info, category: "Test", message: "two")

        let expectation = XCTestExpectation(description: "Entries appended")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(log.entries.count, 2)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor
    func testClearRemovesAllEntries() {
        let log = ActivityLog()
        log.log(.info, category: "Test", message: "test")

        let expectation = XCTestExpectation(description: "Entry appended")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(log.entries.count, 1)
            log.clear()
            XCTAssertTrue(log.entries.isEmpty)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor
    func testBufferCapsAt500Entries() {
        let log = ActivityLog()
        for i in 0..<510 {
            log.log(.info, category: "Test", message: "entry \(i)")
        }

        let expectation = XCTestExpectation(description: "All entries appended")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertLessThanOrEqual(log.entries.count, 500)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }
}
