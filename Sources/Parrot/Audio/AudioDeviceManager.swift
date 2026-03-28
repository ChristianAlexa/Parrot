import AudioToolbox
import os

struct AudioInputDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let transportType: String
    var isDefault: Bool
}

@Observable
@MainActor
final class AudioDeviceManager {
    private let logger = Logger(subsystem: "com.parrot", category: "AudioDevice")

    var availableDevices: [AudioInputDevice] = []
    var selectedDeviceUID: String? {
        didSet {
            UserDefaults.standard.set(selectedDeviceUID, forKey: "selectedMicrophoneUID")
        }
    }

    /// Resolves the selected UID to an AudioDeviceID, or nil for system default
    var effectiveDeviceID: AudioDeviceID? {
        setupIfNeeded()
        guard let uid = selectedDeviceUID else { return nil }
        guard let device = availableDevices.first(where: { $0.uid == uid }) else {
            // Selected device no longer available — fall back to auto-detect
            logger.warning("Selected device '\(uid)' not found, falling back to auto-detect")
            ActivityLog.shared.log(.warning, category: "AudioDevice", message: "Selected device '\(uid)' not found, falling back to auto-detect")
            return nil
        }
        return device.id
    }

    @ObservationIgnored
    private nonisolated(unsafe) var deviceListListenerBlock: AudioObjectPropertyListenerBlock?
    @ObservationIgnored
    private nonisolated(unsafe) var defaultDeviceListenerBlock: AudioObjectPropertyListenerBlock?
    @ObservationIgnored
    private var needsSetup = true

    init() {
        selectedDeviceUID = UserDefaults.standard.string(forKey: "selectedMicrophoneUID")
        // Defer refreshDevices() + installListeners() until first access
        // to avoid CoreAudio enumeration blocking app startup.
    }

    private func setupIfNeeded() {
        guard needsSetup else { return }
        needsSetup = false
        reloadDevices()
        installListeners()
    }

    deinit {
        removeListeners()
    }

    func refreshDevices() {
        setupIfNeeded()
        reloadDevices()
    }

    private func reloadDevices() {
        let defaultID = getDefaultInputDeviceID()
        let deviceIDs = getAllAudioDeviceIDs()

        var inputDevices: [AudioInputDevice] = []
        for deviceID in deviceIDs {
            guard hasInputStreams(deviceID: deviceID) else { continue }
            guard let uid = getDeviceUID(deviceID: deviceID) else { continue }
            let name = getDeviceName(deviceID: deviceID) ?? "Unknown Device"
            let transport = getTransportType(deviceID: deviceID)

            inputDevices.append(AudioInputDevice(
                id: deviceID,
                uid: uid,
                name: name,
                transportType: transport,
                isDefault: deviceID == defaultID
            ))
        }

        availableDevices = inputDevices
        logger.info("Found \(inputDevices.count) input device(s)")
        ActivityLog.shared.log(.info, category: "AudioDevice", message: "Found \(inputDevices.count) input device(s)")
    }

    // MARK: - CoreAudio Queries

    private func getAllAudioDeviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize
        ) == noErr else { return [] }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &deviceIDs
        ) == noErr else { return [] }

        return deviceIDs
    }

    private func hasInputStreams(deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize) == noErr else {
            return false
        }

        let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
        defer { bufferListPointer.deallocate() }

        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, bufferListPointer) == noErr else {
            return false
        }

        let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPointer)
        return bufferList.reduce(0) { $0 + Int($1.mNumberChannels) } > 0
    }

    private func getDeviceName(deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        return getCFStringProperty(deviceID: deviceID, address: &address)
    }

    private func getDeviceUID(deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        return getCFStringProperty(deviceID: deviceID, address: &address)
    }

    private func getCFStringProperty(deviceID: AudioDeviceID, address: inout AudioObjectPropertyAddress) -> String? {
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>>.size)
        var unmanagedString: Unmanaged<CFString>?
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &unmanagedString) == noErr,
              let cfString = unmanagedString?.takeUnretainedValue() else {
            return nil
        }
        return cfString as String
    }

    private func getTransportType(deviceID: AudioDeviceID) -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var transportType: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &transportType) == noErr else {
            return ""
        }

        switch transportType {
        case kAudioDeviceTransportTypeBuiltIn: return "Built-in"
        case kAudioDeviceTransportTypeUSB: return "USB"
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: return "Bluetooth"
        case kAudioDeviceTransportTypeAggregate: return "Aggregate"
        case kAudioDeviceTransportTypeVirtual: return "Virtual"
        case kAudioDeviceTransportTypeThunderbolt: return "Thunderbolt"
        default: return ""
        }
    }

    private func getDefaultInputDeviceID() -> AudioDeviceID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID: AudioDeviceID = 0
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &deviceID
        )
        return deviceID
    }

    // MARK: - Device Change Listeners

    private func installListeners() {
        var devicesAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let devicesBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in
                self?.refreshDevices()
            }
        }
        deviceListListenerBlock = devicesBlock
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &devicesAddress, .main, devicesBlock
        )

        var defaultAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let defaultBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in
                self?.refreshDevices()
            }
        }
        defaultDeviceListenerBlock = defaultBlock
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &defaultAddress, .main, defaultBlock
        )
    }

    private nonisolated func removeListeners() {
        var devicesAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        if let block = deviceListListenerBlock {
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject), &devicesAddress, .main, block
            )
        }

        var defaultAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        if let block = defaultDeviceListenerBlock {
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject), &defaultAddress, .main, block
            )
        }
    }
}
