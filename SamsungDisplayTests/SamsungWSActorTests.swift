@testable import SamsungDisplay
import XCTest

final class SamsungWSActorTests: XCTestCase {

    // CONN-06 (gap closure): calling waitForClose() before any successful
    // connect throws notConnected.
    func test_waitForClose_beforeConnect_throwsNotConnected() async {
        let actor = SamsungWSActor()
        do {
            try await actor.waitForClose()
            XCTFail("expected notConnected")
        } catch SamsungWSError.notConnected {
            // expected
        } catch {
            XCTFail("expected SamsungWSError.notConnected, got \(error)")
        }
    }

    // CONN-06 (gap closure): calling waitForClose() after disconnect() on
    // a never-connected actor still throws notConnected (idempotent
    // disconnect must not corrupt state).
    func test_waitForClose_afterDisconnect_throwsNotConnected() async {
        let actor = SamsungWSActor()
        await actor.disconnect()
        do {
            try await actor.waitForClose()
            XCTFail("expected notConnected")
        } catch SamsungWSError.notConnected {
            // expected
        } catch {
            XCTFail("expected SamsungWSError.notConnected, got \(error)")
        }
    }

    // CONN-06 (gap closure): disconnect() while waitForClose is parked
    // resumes the parked continuation with notConnected.
    //
    // We can't connect() without a real Samsung server in unit tests, so
    // the broader "parked-then-server-close" lifecycle is exercised via
    // ConnectionControllerTests + SpyWSDriver (Wave 4 RED tests, Wave 6
    // GREEN). This test covers the disconnect-resumes-waiters branch via
    // a separate path that doesn't require connect().
    //
    // NOTE: If the actor's internal `task` is nil before any connect, the
    // parked-waiter path is impossible to test in isolation. This is
    // documented in the SUMMARY; full coverage is in the controller-level
    // integration tests.
}
