@testable import SamsungDisplay
import Network
import XCTest

final class NetworkPathObserverTests: XCTestCase {

    // MARK: - First-update rules

    func test_firstUpdate_satisfied_emitsSatisfied() {
        let snap = PathSnapshot(status: .satisfied, interfaceFingerprint: "en0/wifi")
        XCTAssertEqual(networkPathDispatch(previous: nil, current: snap), .satisfied)
    }

    func test_firstUpdate_unsatisfied_emitsLost() {
        let snap = PathSnapshot(status: .unsatisfied, interfaceFingerprint: "")
        XCTAssertEqual(networkPathDispatch(previous: nil, current: snap), .lost)
    }

    func test_firstUpdate_requiresConnection_emitsLost() {
        let snap = PathSnapshot(status: .requiresConnection, interfaceFingerprint: "")
        XCTAssertEqual(networkPathDispatch(previous: nil, current: snap), .lost)
    }

    // MARK: - Transition rules

    func test_satisfied_to_unsatisfied_emitsLost() {
        let prev = PathSnapshot(status: .satisfied, interfaceFingerprint: "en0/wifi")
        let curr = PathSnapshot(status: .unsatisfied, interfaceFingerprint: "")
        XCTAssertEqual(networkPathDispatch(previous: prev, current: curr), .lost)
    }

    func test_unsatisfied_to_satisfied_emitsSatisfied() {
        let prev = PathSnapshot(status: .unsatisfied, interfaceFingerprint: "")
        let curr = PathSnapshot(status: .satisfied, interfaceFingerprint: "en0/wifi")
        XCTAssertEqual(networkPathDispatch(previous: prev, current: curr), .satisfied)
    }

    func test_satisfied_sameInterface_emitsNone() {
        let prev = PathSnapshot(status: .satisfied, interfaceFingerprint: "en0/wifi")
        let curr = PathSnapshot(status: .satisfied, interfaceFingerprint: "en0/wifi")
        XCTAssertEqual(networkPathDispatch(previous: prev, current: curr), .none)
    }

    func test_satisfied_differentInterface_emitsAdapterChanged() {
        let prev = PathSnapshot(status: .satisfied, interfaceFingerprint: "en0/wifi")
        let curr = PathSnapshot(status: .satisfied, interfaceFingerprint: "en1/wiredEthernet")
        XCTAssertEqual(networkPathDispatch(previous: prev, current: curr), .adapterChanged)
    }

    func test_unsatisfiedToRequiresConnection_emitsNone() {
        let prev = PathSnapshot(status: .unsatisfied, interfaceFingerprint: "")
        let curr = PathSnapshot(status: .requiresConnection, interfaceFingerprint: "")
        XCTAssertEqual(networkPathDispatch(previous: prev, current: curr), .none)
    }
}
