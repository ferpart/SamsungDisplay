@testable import SamsungDisplay
import XCTest

final class ConnectionStateTests: XCTestCase {

    func test_menuBarImage_connectedShowsAllBars() {
        XCTAssertEqual(ConnectionState.connected.menuBarImage(animationStep: 0), "MenuBarBars3")
        XCTAssertEqual(ConnectionState.connected.menuBarImage(animationStep: 5), "MenuBarBars3")
    }

    func test_menuBarImage_connectingFillsTheBarsOneByOneThenRepeats() {
        let frames = (0..<6).map { ConnectionState.connecting.menuBarImage(animationStep: $0) }
        XCTAssertEqual(frames, ["MenuBarBars0", "MenuBarBars1", "MenuBarBars2", "MenuBarBars3", "MenuBarBars0", "MenuBarBars1"])
    }

    func test_menuBarImage_otherStatesShowTheEmptyMonitor() {
        for state in [ConnectionState.disconnected, .noIP, .unauthorized] {
            XCTAssertEqual(state.menuBarImage(animationStep: 2), "MenuBarBars0")
        }
    }
}
