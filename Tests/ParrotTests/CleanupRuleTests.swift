@testable import Parrot
import XCTest

final class CleanupRuleTests: XCTestCase {

    override func tearDown() {
        for rule in CleanupRule.allCases {
            UserDefaults.standard.removeObject(forKey: rule.defaultsKey)
        }
        super.tearDown()
    }

    func testSlashCommandsIsAlwaysOn() {
        XCTAssertTrue(CleanupRule.slashCommands.isAlwaysOn)
    }

    func testDisplayNameIsNotEmpty() {
        for rule in CleanupRule.allCases {
            XCTAssertFalse(rule.displayName.isEmpty, "\(rule) should have a display name")
        }
    }

    func testInstructionIsNotEmpty() {
        for rule in CleanupRule.allCases {
            XCTAssertFalse(rule.instruction.isEmpty, "\(rule) should have an instruction")
        }
    }

    func testDefaultsKeyFormat() {
        XCTAssertEqual(CleanupRule.slashCommands.defaultsKey, "cleanupRule_slashCommands")
    }

    func testAlwaysOnRulesContainsOnlyAlwaysOnRules() {
        for rule in CleanupRule.alwaysOnRules {
            XCTAssertTrue(rule.isAlwaysOn)
        }
    }

    func testToggleableRulesExcludesAlwaysOnRules() {
        for rule in CleanupRule.toggleableRules {
            XCTAssertFalse(rule.isAlwaysOn)
        }
    }

    func testEnabledRulesRespectsUserDefaults() {
        // All toggleable rules disabled by default
        XCTAssertTrue(CleanupRule.enabledRules.isEmpty)

        // Enable a toggleable rule if any exist
        let toggleable = CleanupRule.toggleableRules
        guard let rule = toggleable.first else { return }

        UserDefaults.standard.set(true, forKey: rule.defaultsKey)
        XCTAssertTrue(CleanupRule.enabledRules.contains(rule))
    }
}
