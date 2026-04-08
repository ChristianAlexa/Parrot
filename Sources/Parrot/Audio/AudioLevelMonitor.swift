import SwiftUI

@MainActor
let sharedAudioLevelMonitor = AudioLevelMonitor()

@Observable
@MainActor
final class AudioLevelMonitor {
    private(set) var levels: [Float] = Array(repeating: 0, count: 30)
    private(set) var frozenLevels: [Float]?
    private var writeIndex = 0

    func push(_ rmsLevel: Float) {
        levels[writeIndex] = rmsLevel
        writeIndex = (writeIndex + 1) % levels.count
    }

    func freeze() {
        frozenLevels = levels
    }

    func reset() {
        levels = Array(repeating: 0, count: levels.count)
        frozenLevels = nil
        writeIndex = 0
    }
}
