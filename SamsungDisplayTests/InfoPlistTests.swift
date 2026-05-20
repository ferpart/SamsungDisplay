@testable import SamsungDisplay
import XCTest

final class InfoPlistTests: XCTestCase {

    func test_LSUIElement_isTrue() throws {
        // The host app bundle is the TEST_HOST configured in project.yml.
        // Load by main bundle ID; under bundle.unit-test with BUNDLE_LOADER set,
        // Bundle.main is the SamsungDisplay.app, so we load it directly.
        let info = Bundle.main.infoDictionary
        XCTAssertNotNil(info, "Expected host bundle Info.plist to be loadable")
        let lsuielement = info?["LSUIElement"] as? Bool ?? (info?["LSUIElement"] as? NSNumber)?.boolValue
        XCTAssertEqual(lsuielement, true, "UI-01: LSUIElement must be true (menu-bar-only, no dock icon)")
    }
}
