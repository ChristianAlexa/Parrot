@testable import Parrot
import XCTest

@MainActor
final class AudioDeviceManagerTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        UserDefaults.standard.removeObject(forKey: DefaultsKey.selectedMicrophoneUID)
    }

    /// When the persisted UID matches no currently-available device (e.g. the
    /// user unplugged a USB mic), the manager must fall back to system default
    /// — recording should keep working even though the picker preference
    /// points at a missing device.
    func testEffectiveDeviceFallsBackWhenSelectedUIDMissing() {
        UserDefaults.standard.set("uid-that-does-not-exist", forKey: DefaultsKey.selectedMicrophoneUID)

        let manager = AudioDeviceManager()
        // Sanity: the persisted UID was loaded.
        XCTAssertEqual(manager.selectedDeviceUID, "uid-that-does-not-exist")

        // No real device on the host will have this UID, so resolution must
        // fall through to nil (system-default).
        XCTAssertNil(manager.effectiveDeviceID)

        // The persisted preference is intentionally preserved so reconnecting
        // the device later restores the user's choice automatically.
        XCTAssertEqual(manager.selectedDeviceUID, "uid-that-does-not-exist")
    }

    /// `displayedDeviceUID` is what the Record-tab picker binds to. When the
    /// persisted UID is not present in availableDevices, it must surface as
    /// nil ("Auto") rather than leaving the picker blank.
    func testDisplayedUIDIsNilWhenSelectedUIDMissing() {
        let manager = AudioDeviceManager()
        manager.availableDevices = [
            AudioInputDevice(id: 1, uid: "present-uid", name: "Present Mic", transportType: "USB", isDefault: true),
        ]
        manager.selectedDeviceUID = "missing-uid"

        XCTAssertNil(manager.displayedDeviceUID)
        // Persisted preference is preserved so reconnecting restores it.
        XCTAssertEqual(manager.selectedDeviceUID, "missing-uid")
    }

    func testDisplayedUIDMatchesSelectedUIDWhenPresent() {
        let manager = AudioDeviceManager()
        manager.availableDevices = [
            AudioInputDevice(id: 1, uid: "present-uid", name: "Present Mic", transportType: "USB", isDefault: true),
        ]
        manager.selectedDeviceUID = "present-uid"

        XCTAssertEqual(manager.displayedDeviceUID, "present-uid")
    }

    func testDisplayedUIDIsNilWhenSelectedUIDIsNil() {
        let manager = AudioDeviceManager()
        manager.availableDevices = [
            AudioInputDevice(id: 1, uid: "present-uid", name: "Present Mic", transportType: "USB", isDefault: true),
        ]
        manager.selectedDeviceUID = nil

        XCTAssertNil(manager.displayedDeviceUID)
    }

    /// Setting displayedDeviceUID writes through to selectedDeviceUID — this
    /// is what the picker binding does on user selection.
    func testSettingDisplayedUIDWritesThroughToSelectedUID() {
        let manager = AudioDeviceManager()
        manager.availableDevices = [
            AudioInputDevice(id: 1, uid: "device-a", name: "A", transportType: "USB", isDefault: true),
        ]

        manager.displayedDeviceUID = "device-a"
        XCTAssertEqual(manager.selectedDeviceUID, "device-a")

        manager.displayedDeviceUID = nil
        XCTAssertNil(manager.selectedDeviceUID)
    }
}
