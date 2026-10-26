@testable import SamsungDisplay
import XCTest

final class OnboardingStepTests: XCTestCase {

    private func step(
        ip: String? = "192.168.1.10",
        state: ConnectionState,
        keysGranted: Bool = false,
        keysSkipped: Bool = false
    ) -> OnboardingStep {
        OnboardingStep.current(storedIP: ip, state: state, keysGranted: keysGranted, keysSkipped: keysSkipped)
    }

    func test_noStoredIPShowsFindMonitor() {
        XCTAssertEqual(step(ip: nil, state: .noIP), .findMonitor)
        XCTAssertEqual(step(ip: "", state: .connecting), .findMonitor)
    }

    func test_storedIPWithNoIPStateShowsFindMonitor() {
        XCTAssertEqual(step(state: .noIP), .findMonitor)
    }

    func test_connectingAndDisconnectedShowPairing() {
        XCTAssertEqual(step(state: .connecting), .pairing)
        XCTAssertEqual(step(state: .disconnected), .pairing)
    }

    func test_unauthorizedShowsDeniedRecovery() {
        XCTAssertEqual(step(state: .unauthorized), .denied)
    }

    func test_connectedWithoutKeyPermissionShowsKeys() {
        XCTAssertEqual(step(state: .connected), .keys)
    }

    func test_connectedWithKeyPermissionIsDone() {
        XCTAssertEqual(step(state: .connected, keysGranted: true), .done)
    }

    func test_skippedKeysIsDone() {
        XCTAssertEqual(step(state: .connected, keysSkipped: true), .done)
    }

    func test_keysStepNeverShowsBeforePairing() {
        XCTAssertEqual(step(state: .unauthorized, keysGranted: true), .denied)
        XCTAssertEqual(step(state: .connecting, keysGranted: true), .pairing)
    }
}
