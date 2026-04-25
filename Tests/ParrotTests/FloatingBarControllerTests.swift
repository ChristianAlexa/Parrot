@testable import Parrot
import XCTest

final class FloatingBarControllerTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        UserDefaults.standard.removeObject(forKey: "showFloatingBar")
    }

    // MARK: - Visibility

    @MainActor
    func testPanelVisibleByDefault() {
        UserDefaults.standard.removeObject(forKey: "showFloatingBar")
        let controller = FloatingBarController()
        controller.setup()

        XCTAssertNotNil(controller.panel)
        XCTAssertTrue(controller.panel!.isVisible)
    }

    @MainActor
    func testPanelHiddenWhenPreferenceDisabled() {
        UserDefaults.standard.set(false, forKey: "showFloatingBar")
        let controller = FloatingBarController()
        controller.setup()

        XCTAssertNotNil(controller.panel)
        XCTAssertFalse(controller.panel!.isVisible)
    }

    // MARK: - Panel properties

    @MainActor
    func testPanelPositionedAtBottomCenterOfPrimaryScreen() {
        let controller = FloatingBarController()
        controller.setup()

        guard let panel = controller.panel, let screen = NSScreen.screens.first else {
            XCTFail("Panel or primary screen not available")
            return
        }

        let visibleFrame = screen.visibleFrame
        let panelFrame = panel.frame

        // Centered horizontally on the primary (menu-bar) screen — not whichever
        // screen NSScreen.main happens to resolve to.
        let expectedX = visibleFrame.midX - panelFrame.width / 2
        XCTAssertEqual(panelFrame.origin.x, expectedX, accuracy: 1)

        // 12pt above bottom of visible frame
        let expectedY = visibleFrame.origin.y + 12
        XCTAssertEqual(panelFrame.origin.y, expectedY, accuracy: 1)
    }

    @MainActor
    func testPanelRecentersOnScreenParametersChange() {
        let controller = FloatingBarController()
        controller.setup()

        guard let panel = controller.panel, let screen = NSScreen.screens.first else {
            XCTFail("Panel or primary screen not available")
            return
        }

        // Simulate the panel being stranded off-center (e.g. left over from
        // when a second monitor was attached).
        let stranded = NSRect(origin: NSPoint(x: 0, y: 0), size: panel.frame.size)
        panel.setFrame(stranded, display: true)
        XCTAssertEqual(panel.frame.origin, stranded.origin)

        // Posting the screen-parameters notification should re-center it.
        NotificationCenter.default.post(
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        // Notification is delivered on the main queue; spin the runloop briefly.
        let expectation = expectation(description: "reposition")
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 1.0)

        let visibleFrame = screen.visibleFrame
        let expectedX = visibleFrame.midX - panel.frame.width / 2
        let expectedY = visibleFrame.origin.y + 12
        XCTAssertEqual(panel.frame.origin.x, expectedX, accuracy: 1)
        XCTAssertEqual(panel.frame.origin.y, expectedY, accuracy: 1)
    }

    @MainActor
    func testPanelSize() {
        let controller = FloatingBarController()
        controller.setup()

        guard let panel = controller.panel else {
            XCTFail("Panel not available")
            return
        }

        XCTAssertEqual(panel.frame.width, 260)
        XCTAssertEqual(panel.frame.height, 36)
    }

    @MainActor
    func testSetupIsIdempotent() {
        let controller = FloatingBarController()
        controller.setup()
        let firstPanel = controller.panel

        controller.setup()
        XCTAssertTrue(controller.panel === firstPanel, "setup() should not create a second panel")
    }
}
