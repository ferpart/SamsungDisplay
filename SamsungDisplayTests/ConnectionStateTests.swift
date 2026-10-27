@testable import SamsungDisplay
import XCTest

final class ConnectionStateTests: XCTestCase {

    func test_menuBarImage_showsBarsOnlyWhileConnectedOrConnecting() {
        XCTAssertEqual(ConnectionState.connected.menuBarImage, "MenuBarConnected")
        XCTAssertEqual(ConnectionState.connecting.menuBarImage, "MenuBarConnected")
        XCTAssertEqual(ConnectionState.disconnected.menuBarImage, "MenuBarDisconnected")
        XCTAssertEqual(ConnectionState.noIP.menuBarImage, "MenuBarDisconnected")
        XCTAssertEqual(ConnectionState.unauthorized.menuBarImage, "MenuBarDisconnected")
    }
}
