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

    @MainActor
    func testPanelShownWhenPreferenceEnabled() {
        UserDefaults.standard.set(true, forKey: "showFloatingBar")
        let controller = FloatingBarController()
        controller.setup()

        XCTAssertNotNil(controller.panel)
        XCTAssertTrue(controller.panel!.isVisible)
    }

    // MARK: - Panel properties

    @MainActor
    func testPanelPositionedAtBottomCenter() {
        let controller = FloatingBarController()
        controller.setup()

        guard let panel = controller.panel, let screen = NSScreen.main else {
            XCTFail("Panel or screen not available")
            return
        }

        let visibleFrame = screen.visibleFrame
        let panelFrame = panel.frame

        // Centered horizontally
        let expectedX = visibleFrame.midX - panelFrame.width / 2
        XCTAssertEqual(panelFrame.origin.x, expectedX, accuracy: 1)

        // 12pt above bottom of visible frame
        let expectedY = visibleFrame.origin.y + 12
        XCTAssertEqual(panelFrame.origin.y, expectedY, accuracy: 1)
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
