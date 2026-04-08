@testable import Parrot
import XCTest

final class AudioLevelMonitorTests: XCTestCase {

    @MainActor
    func testInitialLevelsAreZero() {
        let monitor = AudioLevelMonitor()
        XCTAssertEqual(monitor.levels.count, 30)
        XCTAssertTrue(monitor.levels.allSatisfy { $0 == 0 })
        XCTAssertNil(monitor.frozenLevels)
    }

    @MainActor
    func testPushAppendsLevel() {
        let monitor = AudioLevelMonitor()
        monitor.push(0.5)

        XCTAssertEqual(monitor.levels[0], 0.5)
        // Rest should still be zero
        XCTAssertTrue(monitor.levels.dropFirst().allSatisfy { $0 == 0 })
    }

    @MainActor
    func testPushWrapsAroundBuffer() {
        let monitor = AudioLevelMonitor()
        for i in 0..<30 {
            monitor.push(Float(i) / 30.0)
        }

        // Buffer is full; next push should overwrite index 0
        monitor.push(0.99)
        XCTAssertEqual(monitor.levels[0], 0.99, accuracy: 0.001)
    }

    @MainActor
    func testFreezeCapuresCurrentLevels() {
        let monitor = AudioLevelMonitor()
        monitor.push(0.3)
        monitor.push(0.7)
        monitor.freeze()

        XCTAssertNotNil(monitor.frozenLevels)
        XCTAssertEqual(monitor.frozenLevels?[0], 0.3)
        XCTAssertEqual(monitor.frozenLevels?[1], 0.7)
    }

    @MainActor
    func testFrozenLevelsAreSnapshot() {
        let monitor = AudioLevelMonitor()
        monitor.push(0.5)
        monitor.freeze()

        // Pushing after freeze should not change frozen levels
        monitor.push(0.9)
        XCTAssertEqual(monitor.frozenLevels?[0], 0.5)
    }

    @MainActor
    func testResetClearsEverything() {
        let monitor = AudioLevelMonitor()
        monitor.push(0.5)
        monitor.push(0.8)
        monitor.freeze()

        monitor.reset()

        XCTAssertTrue(monitor.levels.allSatisfy { $0 == 0 })
        XCTAssertNil(monitor.frozenLevels)
    }

    @MainActor
    func testResetPreservesBufferSize() {
        let monitor = AudioLevelMonitor()
        monitor.push(0.5)
        monitor.reset()

        XCTAssertEqual(monitor.levels.count, 30)
    }

    @MainActor
    func testPushAfterResetStartsFromBeginning() {
        let monitor = AudioLevelMonitor()
        monitor.push(0.5)
        monitor.push(0.6)
        monitor.reset()

        monitor.push(0.1)
        XCTAssertEqual(monitor.levels[0], 0.1)
        XCTAssertTrue(monitor.levels.dropFirst().allSatisfy { $0 == 0 })
    }
}
