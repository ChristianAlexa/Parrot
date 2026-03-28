import Foundation

actor AudioSampleBuffer {
    private var samples: [Float] = []
    private var accepting = true

    func append(_ newSamples: [Float]) {
        guard accepting else { return }
        samples.append(contentsOf: newSamples)
    }

    func flush() -> [Float] {
        accepting = false
        let result = samples
        samples.removeAll(keepingCapacity: true)
        return result
    }

    func reset() {
        samples.removeAll(keepingCapacity: true)
        accepting = true
    }

    var sampleCount: Int {
        samples.count
    }
}
