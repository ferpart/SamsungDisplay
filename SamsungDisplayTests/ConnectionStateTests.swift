@testable import SamsungDisplay
import XCTest

final class ConnectionStateTests: XCTestCase {

    // CONN-05: menu bar symbol per state.
    func test_menuBarSymbol_perCase() {
        XCTAssertEqual(ConnectionState.connected.menuBarSymbol, "speaker.wave.2.fill")
        XCTAssertEqual(ConnectionState.connecting.menuBarSymbol, "speaker.wave.2.fill")
        XCTAssertEqual(ConnectionState.disconnected.menuBarSymbol, "speaker.slash.fill")
        XCTAssertEqual(ConnectionState.noIP.menuBarSymbol, "speaker.slash.fill")
        XCTAssertEqual(ConnectionState.unauthorized.menuBarSymbol, "speaker.slash.fill")
    }
}
