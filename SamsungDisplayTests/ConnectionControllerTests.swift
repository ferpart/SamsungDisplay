@testable import SamsungDisplay
import XCTest

@MainActor
final class ConnectionControllerTests: XCTestCase {

    private var spy: SpyWSDriver!
    private var path: FakePathObserver!
    private var defaults: UserDefaults!
    private let suiteName = "ConnectionControllerTests.suite"

    override func setUp() async throws {
        spy = SpyWSDriver()
        path = FakePathObserver()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        spy = nil
        path = nil
        defaults = nil
    }

    // CONN-05: bootstrap with a saved IP enters connecting.
    func test_bootstrap_withSavedIP_movesToConnecting() async throws {
        // TODO(Wave 1): construct ConnectionController(ws:pathObserver:preferences:tokens:) with injected spy/path/defaults.
        // Set defaults monitorIP="192.168.1.10" via injected AppPreferences.
        // Set spy.nextConnectOutcome = .hang so the controller stays in .connecting.
        // Call controller.bootstrap()
        // Assert spy.connectCalls.count == 1 and spy.connectCalls[0].ip == "192.168.1.10"
        // Assert controller.state == .connecting (within 100ms of bootstrap)
        XCTFail("Pending Wave 1 implementation")
    }

    // CONN-06: NWPathMonitor .satisfied transitions cancel the current backoff sleep and retry immediately.
    func test_pathSatisfied_cancelsBackoff() async throws {
        // TODO(Wave 1): bootstrap into a state where spy.nextConnectOutcome = .error(URLError(.timedOut)).
        // Wait one connect attempt (spy.connectCalls.count == 1, state == .connecting).
        // Call path.firePathSatisfied() — controller MUST cancel its current Task.sleep and retry.
        // Within a short window, spy.connectCalls.count should advance to 2 without waiting the full 1s backoff.
        XCTFail("Pending Wave 1 implementation")
    }

    // CONN-06: unauthorized short-circuits the retry loop.
    func test_unauthorized_stopsLoop() async throws {
        // TODO(Wave 1): spy.nextConnectOutcome = .unauthorized.
        // bootstrap → controller transitions to .unauthorized; spy.connectCalls.count stays at 1 even after 5 seconds.
        XCTFail("Pending Wave 1 implementation")
    }

    // CONN-06: wipeTokenAndReconnect clears keychain and re-enters connecting.
    func test_wipeToken_restartsLoop() async throws {
        // TODO(Wave 1): seed a TokenStore(service: "tests.SamsungDisplay.token", account: "test") with a value;
        // confirm load() returns it. Then call controller.wipeTokenAndReconnect() with that injected TokenStore.
        // Assert load() == nil and spy.connectCalls.count incremented.
        XCTFail("Pending Wave 1 implementation")
    }

    // VOL-01 (v1): send(.volUp) forwards KEY_VOLUP to the driver.
    func test_send_volUp_forwardsKeyVolup() async throws {
        // TODO(Wave 1): bootstrap to .connected (spy.nextConnectOutcome = .success(token: "t")).
        // controller.send(.volUp); allow the spawned Task to run.
        // Assert spy.sendKeyCalls.last == .volUp.
        XCTFail("Pending Wave 1 implementation")
    }

    // VOL-02: send(.mute) forwards KEY_MUTE.
    func test_send_mute_forwardsKeyMute() async throws {
        // TODO(Wave 1): same shape; assert .mute appended.
        XCTFail("Pending Wave 1 implementation")
    }

    // VOL-04 (v1): a send failure logs but does NOT change connection state.
    func test_send_failure_doesNotChangeState() async throws {
        // TODO(Wave 1): bootstrap to .connected. spy.nextSendKeyError = URLError(.networkConnectionLost).
        // controller.send(.volUp); assert controller.state == .connected (no state change).
        // Assert controller.logEntries.last contains "send" and the error description.
        XCTFail("Pending Wave 1 implementation")
    }
}
