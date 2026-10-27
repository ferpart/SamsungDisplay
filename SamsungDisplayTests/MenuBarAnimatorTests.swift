@testable import SamsungDisplay
import XCTest

@MainActor
final class MenuBarAnimatorTests: XCTestCase {

    func test_connecting_advancesTheStep() async throws {
        let animator = MenuBarAnimator()
        animator.update(isConnecting: true)
        try await Task.sleep(for: .milliseconds(900))
        XCTAssertGreaterThanOrEqual(animator.step, 1)
        animator.update(isConnecting: false)
    }

    func test_leavingConnecting_stopsTheTimerAndResetsTheStep() async throws {
        let animator = MenuBarAnimator()
        animator.update(isConnecting: true)
        try await Task.sleep(for: .milliseconds(500))
        animator.update(isConnecting: false)
        XCTAssertFalse(animator.isAnimating)
        XCTAssertEqual(animator.step, 0)
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(animator.step, 0)
    }
}
