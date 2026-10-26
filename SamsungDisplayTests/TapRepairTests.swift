@testable import SamsungDisplay
import CoreGraphics
import XCTest

final class TapRepairTests: XCTestCase {

    func test_reenablesAfterTimeoutAndUserInput() {
        XCTAssertEqual(TapRepair.after(.tapDisabledByTimeout), .reenable)
        XCTAssertEqual(TapRepair.after(.tapDisabledByUserInput), .reenable)
    }

    func test_ignoresOrdinaryEvents() {
        XCTAssertEqual(TapRepair.after(CGEventType(rawValue: 14)!), .none)
        XCTAssertEqual(TapRepair.after(.keyDown), .none)
    }

    func test_healthyTapNeedsNothing() {
        XCTAssertEqual(TapRepair.forHealth(exists: true, isValid: true, isEnabled: true, isPermitted: true), .none)
    }

    func test_disabledTapIsReenabled() {
        XCTAssertEqual(TapRepair.forHealth(exists: true, isValid: true, isEnabled: false, isPermitted: true), .reenable)
    }

    func test_missingOrInvalidTapIsRecreated() {
        XCTAssertEqual(TapRepair.forHealth(exists: false, isValid: false, isEnabled: false, isPermitted: true), .recreate)
        XCTAssertEqual(TapRepair.forHealth(exists: true, isValid: false, isEnabled: true, isPermitted: true), .recreate)
    }

    func test_nothingHappensWithoutPermission() {
        XCTAssertEqual(TapRepair.forHealth(exists: false, isValid: false, isEnabled: false, isPermitted: false), .none)
    }
}
