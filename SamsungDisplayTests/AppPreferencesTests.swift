import XCTest
@testable import SamsungDisplay

final class AppPreferencesTests: XCTestCase {
    var suiteName: String!
    var suite: UserDefaults!
    var prefs: AppPreferences!

    override func setUp() {
        super.setUp()
        suiteName = "com.fp.SamsungDisplay.tests.\(UUID().uuidString)"
        suite = UserDefaults(suiteName: suiteName)!
        prefs = AppPreferences(defaults: suite)
    }

    override func tearDown() {
        suite.removePersistentDomain(forName: suiteName)
        suite = nil
        prefs = nil
        suiteName = nil
        super.tearDown()
    }

    func test_monitorIP_roundTripsThroughCustomSuite() {
        prefs.monitorIP = "192.168.1.50"
        XCTAssertEqual(prefs.monitorIP, "192.168.1.50")

        // Verify it actually went through the suite, not some in-memory cache.
        XCTAssertEqual(suite.string(forKey: "monitorIP"), "192.168.1.50")
    }

    func test_monitorIP_returnsNilWhenUnset() {
        XCTAssertNil(prefs.monitorIP)
        XCTAssertNil(suite.object(forKey: "monitorIP"))
    }

    func test_settingMonitorIPToNil_clearsStoredValue() {
        prefs.monitorIP = "10.0.0.1"
        XCTAssertEqual(prefs.monitorIP, "10.0.0.1")

        prefs.monitorIP = nil
        XCTAssertNil(prefs.monitorIP)

        // Critical: object(forKey:) must be nil, not NSNull. A naive
        // defaults.set(nil, forKey:) writes NSNull which would fail this.
        XCTAssertNil(suite.object(forKey: "monitorIP"))
    }

    func test_sharedInstance_usesStandardDefaults() {
        XCTAssertTrue(AppPreferences.shared.defaults === UserDefaults.standard)
    }

    func test_appearance_defaultsToAutomaticAndRoundTrips() {
        XCTAssertEqual(prefs.appearance, .automatic)
        prefs.appearance = .dark
        XCTAssertEqual(prefs.appearance, .dark)
        XCTAssertEqual(suite.string(forKey: "appearance"), "dark")
    }

    func test_appearance_unknownStoredValueFallsBackToAutomatic() {
        suite.set("sepia", forKey: "appearance")
        XCTAssertEqual(prefs.appearance, .automatic)
    }

    func test_appearanceMode_mapsToNSAppearance() {
        XCTAssertNil(AppearanceMode.automatic.nsAppearance)
        XCTAssertEqual(AppearanceMode.light.nsAppearance?.name, .aqua)
        XCTAssertEqual(AppearanceMode.dark.nsAppearance?.name, .darkAqua)
    }
}
