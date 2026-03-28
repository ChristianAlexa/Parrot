import AudioToolbox
import AVFoundation
import os

final class AudioCaptureManager {
    private let logger = Logger(subsystem: "com.parrot", category: "Audio")
    private lazy var engine = AVAudioEngine()
    private let sampleBuffer = AudioSampleBuffer()

    /// Target format for Whisper: 16kHz mono Float32
    private let targetSampleRate: Double = 16000.0

    private var converter: AVAudioConverter?
    private var isCapturing = false

    func startCapture(deviceID: AudioDeviceID? = nil) async throws {
        guard !isCapturing else { return }

        await sampleBuffer.reset()

        // Set specific input device if requested
        if let deviceID {
            engine.reset()
            let inputNode = engine.inputNode
            guard let audioUnit = inputNode.audioUnit else {
                throw AudioCaptureError.deviceNotAvailable
            }
            var mutableID = deviceID
            let status = AudioUnitSetProperty(
                audioUnit,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &mutableID,
                UInt32(MemoryLayout<AudioDeviceID>.size)
            )
            if status != noErr {
                logger.error("Failed to set audio device (status: \(status))")
                ActivityLog.shared.log(.error, category: "Audio", message: "Failed to set audio device (status: \(status))")
                throw AudioCaptureError.deviceNotAvailable
            }
        }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0 else {
            throw AudioCaptureError.noMicrophone
        }

        // Target format: 16kHz mono Float32
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioCaptureError.formatError
        }

        // Create converter from input format to target format
        guard let audioConverter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioCaptureError.converterError
        }
        converter = audioConverter

        let bufferSize: AVAudioFrameCount = 4096

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            self.processAudioBuffer(buffer, converter: audioConverter, targetFormat: targetFormat)
        }

        try engine.start()
        isCapturing = true
        logger.info("Audio capture started (input: \(inputFormat.sampleRate)Hz → 16kHz mono)")
        ActivityLog.shared.log(.info, category: "Audio", message: "Audio capture started (input: \(inputFormat.sampleRate)Hz → 16kHz mono)")
    }

    func stopCapture() async -> [Float] {
        guard isCapturing else { return [] }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isCapturing = false

        let samples = await sampleBuffer.flush()
        logger.info("Audio capture stopped. Captured \(samples.count) samples (\(String(format: "%.1f", Double(samples.count) / self.targetSampleRate))s)")
        ActivityLog.shared.log(.info, category: "Audio", message: "Audio capture stopped. Captured \(samples.count) samples (\(String(format: "%.1f", Double(samples.count) / self.targetSampleRate))s)")
        return samples
    }

    private func processAudioBuffer(
        _ buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        targetFormat: AVAudioFormat
    ) {
        let frameCount = AVAudioFrameCount(
            Double(buffer.frameLength) * targetSampleRate / buffer.format.sampleRate
        )
        guard frameCount > 0 else { return }

        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: frameCount
        ) else {
            logger.error("Failed to allocate audio conversion buffer (frameCount: \(frameCount))")
            ActivityLog.shared.log(.error, category: "Audio", message: "Failed to allocate audio conversion buffer (frameCount: \(frameCount))")
            return
        }

        var error: NSError?
        var hasInput = false

        converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            if hasInput {
                outStatus.pointee = .noDataNow
                return nil
            }
            hasInput = true
            outStatus.pointee = .haveData
            return buffer
        }

        if let error {
            logger.error("Audio conversion error: \(error.localizedDescription)")
            ActivityLog.shared.log(.error, category: "Audio", message: "Audio conversion error: \(error.localizedDescription)")
            return
        }

        guard let channelData = convertedBuffer.floatChannelData?[0] else { return }
        let samples = Array(UnsafeBufferPointer(start: channelData, count: Int(convertedBuffer.frameLength)))

        Task {
            await sampleBuffer.append(samples)
        }
    }
}

enum AudioCaptureError: Error, LocalizedError {
    case noMicrophone
    case formatError
    case converterError
    case deviceNotAvailable

    var errorDescription: String? {
        switch self {
        case .noMicrophone: return "No microphone detected"
        case .formatError: return "Failed to create target audio format"
        case .converterError: return "Failed to create audio converter"
        case .deviceNotAvailable: return "Selected audio device is not available"
        }
    }
}
