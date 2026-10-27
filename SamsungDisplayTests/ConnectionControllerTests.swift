@testable import SamsungDisplay
import XCTest

@MainActor
final class ConnectionControllerTests: XCTestCase {

    private var spy: SpyWSDriver!
    private var lan: FakeLANDriver!
    private var path: FakePathObserver!
    private var defaults: UserDefaults!
    private var preferences: AppPreferences!
    private var tokens: TokenStore!
    private var pins: TokenStore!
    private var suiteName: String!

    override func setUp() async throws {
        spy = SpyWSDriver()
        lan = FakeLANDriver()
        path = FakePathObserver()
        suiteName = "ConnectionControllerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        preferences = AppPreferences(defaults: defaults)
        // Unique keychain service per test run so we don't pollute the real
        // app keychain item (RESEARCH.md Pitfall #3 — token store hygiene).
        tokens = TokenStore(service: "tests.SamsungDisplay.token.\(UUID().uuidString)")
        pins = TokenStore(service: "tests.SamsungDisplay.pin.\(UUID().uuidString)")
    }

    override func tearDown() async throws {
        tokens.deleteAll()
        pins.deleteAll()
        defaults.removePersistentDomain(forName: suiteName)
        spy = nil
        lan = nil
        path = nil
        defaults = nil
        preferences = nil
        tokens = nil
        pins = nil
    }

    // MARK: - Helpers

    /// Polls `condition` every 20ms up to `timeout`. Fails the test on timeout.
    private func waitFor(
        _ condition: @MainActor () -> Bool,
        timeout: Duration = .seconds(2),
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("Timed out waiting for condition", file: file, line: line)
    }

    private func makeController(policy: ReconnectPolicy = .default) -> ConnectionController {
        ConnectionController(
            ws: spy,
            lan: lan,
            pathObserver: path,
            preferences: preferences,
            tokens: tokens,
            pins: pins,
            policy: policy
        )
    }

    // MARK: - Tests

    // CONN-05: bootstrap with a saved IP enters connecting.
    func test_bootstrap_withSavedIP_movesToConnecting() async throws {
        preferences.monitorIP = "192.168.1.10"
        spy.nextConnectOutcome = .hang

        let controller = makeController()
        controller.bootstrap()

        try await waitFor { self.spy.connectCalls.count == 1 }
        XCTAssertEqual(spy.connectCalls.first?.ip, "192.168.1.10")
        XCTAssertEqual(controller.state, .connecting)

        controller.stop()
    }

    // CONN-06: NWPathMonitor .satisfied transitions cancel the current backoff
    // sleep and retry immediately.
    func test_pathSatisfied_cancelsBackoff() async throws {
        preferences.monitorIP = "192.168.1.10"
        spy.nextConnectOutcome = .error(URLError(.timedOut))

        let controller = makeController()
        controller.bootstrap()

        // Wait for the first connect attempt to land.
        try await waitFor { self.spy.connectCalls.count >= 1 }
        let baseline = spy.connectCalls.count

        // Kick the path observer BEFORE the 1s backoff sleep can elapse.
        let clock = ContinuousClock()
        let startedAt = clock.now
        path.firePathSatisfied()

        // The kick cancels the in-flight Task.sleep and starts a fresh loop,
        // which immediately issues another connect. We allow up to 500ms
        // (generous scheduler jitter); the full backoff would be 1000ms.
        try await waitFor(
            { self.spy.connectCalls.count > baseline },
            timeout: .milliseconds(500)
        )
        let elapsed = clock.now - startedAt
        XCTAssertLessThan(
            elapsed,
            .milliseconds(900),
            "Path-satisfied kick must skip the 1s backoff sleep"
        )

        controller.stop()
    }

    // CONN-06: unauthorized short-circuits the retry loop.
    func test_unauthorized_stopsLoop() async throws {
        preferences.monitorIP = "192.168.1.10"
        spy.nextConnectOutcome = .unauthorized

        let controller = makeController()
        controller.bootstrap()

        try await waitFor { controller.state == .unauthorized }
        XCTAssertEqual(spy.connectCalls.count, 1)

        // Confirm no further retries — wait a sane window and re-check.
        try await Task.sleep(for: .seconds(1))
        XCTAssertEqual(
            spy.connectCalls.count,
            1,
            "unauthorized must short-circuit the loop"
        )
    }

    // CONN-06: wipeTokenAndReconnect clears keychain and re-enters connecting.
    func test_wipeToken_restartsLoop() async throws {
        preferences.monitorIP = "192.168.1.10"
        spy.nextConnectOutcome = .hang

        try tokens.save("old-token", for: "192.168.1.10")
        XCTAssertEqual(tokens.load(for: "192.168.1.10"), "old-token")

        let controller = makeController()
        controller.wipeTokenAndReconnect()

        try await waitFor { self.spy.connectCalls.count == 1 }
        XCTAssertNil(tokens.load(for: "192.168.1.10"), "wipeTokenAndReconnect must delete the keychain item")
        XCTAssertEqual(spy.connectCalls.first?.ip, "192.168.1.10")
        XCTAssertNil(
            spy.connectCalls.first?.token,
            "freshly-wiped loop must connect with token = nil"
        )

        controller.stop()
    }

    // VOL-01 (v1): send(.volUp) forwards KEY_VOLUP to the driver.
    func test_send_volUp_forwardsKeyVolup() async throws {
        preferences.monitorIP = "192.168.1.10"
        spy.nextConnectOutcome = .success(token: "t")

        let controller = makeController()
        controller.bootstrap()

        try await waitFor { controller.state == .connected }

        controller.send(.volUp)
        try await waitFor { self.spy.sendKeyCalls.last == .volUp }

        controller.stop()
    }

    // VOL-02: send(.mute) forwards KEY_MUTE.
    func test_send_mute_forwardsKeyMute() async throws {
        preferences.monitorIP = "192.168.1.10"
        spy.nextConnectOutcome = .success(token: "t")

        let controller = makeController()
        controller.bootstrap()

        try await waitFor { controller.state == .connected }

        controller.send(.mute)
        try await waitFor { self.spy.sendKeyCalls.last == .mute }

        controller.stop()
    }

    // CONN-06 (regression): a second bootstrap() while a lifecycle task is
    // already running must be a no-op. Hardware walk #1 observed the WS
    // tearing down on every popover open because `.onAppear` calls bootstrap()
    // on each materialization of the MenuBarExtra content view.
    func test_bootstrap_isIdempotent_whileLifecycleRunning() async throws {
        preferences.monitorIP = "192.168.1.10"
        spy.nextConnectOutcome = .success(token: "t")

        let controller = makeController()
        controller.bootstrap()

        try await waitFor { controller.state == .connected }
        XCTAssertEqual(spy.connectCalls.count, 1)

        // Simulate the popover being opened a second time.
        controller.bootstrap()
        controller.bootstrap()

        // Give any spurious task a chance to misbehave.
        try await Task.sleep(for: .milliseconds(200))

        XCTAssertEqual(
            spy.connectCalls.count,
            1,
            "bootstrap() while connected must not re-enter the connect loop"
        )
        XCTAssertEqual(
            spy.disconnectCalls,
            0,
            "bootstrap() while connected must not tear down the WebSocket"
        )

        controller.stop()
    }

    // CONN-06 (gap closure): path-lost while .connected must trigger reconnect.
    func test_pathLost_whileConnected_movesToConnecting() async throws {
        preferences.monitorIP = "192.168.1.10"
        spy.nextConnectOutcome = .success(token: "t")

        let controller = makeController()
        controller.bootstrap()
        try await waitFor { controller.state == .connected }
        let baseline = spy.connectCalls.count

        path.firePathLost()

        try await waitFor(
            { self.spy.connectCalls.count > baseline },
            timeout: .milliseconds(500)
        )

        controller.stop()
    }

    // CONN-06 (gap closure): post-handshake receive error must trigger reconnect.
    func test_receiveLoopError_whileConnected_triggersReconnect() async throws {
        preferences.monitorIP = "192.168.1.10"
        spy.nextConnectOutcome = .success(token: "t")

        let controller = makeController()
        controller.bootstrap()
        try await waitFor { controller.state == .connected }
        let baseline = spy.connectCalls.count

        spy.simulateClose(error: URLError(.networkConnectionLost))

        try await waitFor(
            { self.spy.connectCalls.count > baseline },
            timeout: .milliseconds(1500)
        )

        controller.stop()
    }

    // CONN-06 (gap closure): heartbeat timeout (any waitForClose throw) must
    // route through the same reconnect path. Covers the half-open socket
    // failure mode (monitor power-off via NAT timeout).
    func test_heartbeatTimeout_whileConnected_triggersReconnect() async throws {
        preferences.monitorIP = "192.168.1.10"
        spy.nextConnectOutcome = .success(token: "t")

        let controller = makeController()
        controller.bootstrap()
        try await waitFor { controller.state == .connected }
        let baseline = spy.connectCalls.count

        spy.simulateClose(error: URLError(.timedOut))

        try await waitFor(
            { self.spy.connectCalls.count > baseline },
            timeout: .milliseconds(1500)
        )

        controller.stop()
    }

    // VOL-04 (v1): a send failure logs but does NOT change connection state.
    func test_send_failure_doesNotChangeState() async throws {
        preferences.monitorIP = "192.168.1.10"
        spy.nextConnectOutcome = .success(token: "t")

        let controller = makeController()
        controller.bootstrap()
        try await waitFor { controller.state == .connected }

        spy.nextSendKeyError = URLError(.networkConnectionLost)
        controller.send(.volUp)

        // Wait for the failure to be logged.
        try await waitFor {
            controller.logEntries.last?.contains("send KEY_VOLUP failed:") == true
        }
        XCTAssertEqual(
            controller.state,
            .connected,
            "send failures must not flip connection state"
        )

        controller.stop()
    }

    // MARK: - LAN (power, input)

    private func connectedController() async throws -> ConnectionController {
        preferences.monitorIP = "192.168.1.10"
        spy.nextConnectOutcome = .success(token: "t")
        let controller = makeController()
        controller.bootstrap()
        try await waitFor { controller.state == .connected }
        return controller
    }

    func test_connect_storesMonitorName() async throws {
        let controller = try await connectedController()
        try await waitFor { controller.monitorName == "OLED G9" }
        controller.stop()
    }

    func test_connectTo_storesIPAndConnects() async throws {
        spy.nextConnectOutcome = .success(token: "t")
        let controller = makeController()
        controller.connect(to: "192.168.1.77")
        try await waitFor { controller.state == .connected }
        XCTAssertEqual(preferences.monitorIP, "192.168.1.77")
        controller.stop()
    }

    func test_connectTo_newIP_doesNotSendTokenOfAnotherIP() async throws {
        try tokens.save("token-for-old-ip", for: "192.168.1.10")
        spy.nextConnectOutcome = .success(token: "token-for-new-ip")
        let controller = makeController()
        controller.connect(to: "192.168.1.77")
        try await waitFor { controller.state == .connected }
        XCTAssertNil(spy.connectCalls.first?.token)
        XCTAssertEqual(tokens.load(for: "192.168.1.77"), "token-for-new-ip")
        XCTAssertEqual(tokens.load(for: "192.168.1.10"), "token-for-old-ip")
        controller.stop()
    }

    func test_firstConnect_pinsCertificateAndLaterConnectsSendPin() async throws {
        spy.certificateSHA256 = "first-certificate"
        let controller = makeController()
        controller.connect(to: "192.168.1.77")
        try await waitFor { controller.state == .connected }
        XCTAssertNil(spy.connectCalls.first?.pin)
        XCTAssertEqual(pins.load(for: "192.168.1.77"), "first-certificate")

        controller.connect(to: "192.168.1.77")
        try await waitFor { self.spy.connectCalls.count == 2 }
        XCTAssertEqual(spy.connectCalls.last?.pin, "first-certificate")
        controller.stop()
    }

    func test_certificateMismatch_stopsLoop() async throws {
        preferences.monitorIP = "192.168.1.10"
        spy.nextConnectOutcome = .error(SamsungWSError.certificateMismatch)
        let controller = makeController()
        controller.bootstrap()
        try await waitFor { controller.state == .certificateMismatch }
        try await Task.sleep(for: .seconds(1))
        XCTAssertEqual(spy.connectCalls.count, 1)
    }

    func test_wipeToken_clearsCertificatePin() async throws {
        preferences.monitorIP = "192.168.1.10"
        spy.nextConnectOutcome = .hang
        try pins.save("old-certificate", for: "192.168.1.10")
        let controller = makeController()
        controller.wipeTokenAndReconnect()
        try await waitFor { self.spy.connectCalls.count == 1 }
        XCTAssertNil(pins.load(for: "192.168.1.10"))
        XCTAssertNil(spy.connectCalls.first?.pin)
        controller.stop()
    }

    func test_connectTo_rejectsAddressThatIsNotIPv4() {
        let controller = makeController()
        XCTAssertFalse(controller.connect(to: "fe80::1"))
        XCTAssertNil(preferences.monitorIP)
        XCTAssertTrue(spy.connectCalls.isEmpty)
    }

    func test_bootstrap_withInvalidStoredIP_staysInNoIP() {
        preferences.monitorIP = "a b"
        let controller = makeController()
        controller.bootstrap()
        XCTAssertEqual(controller.state, .noIP)
    }

    func test_forgetMonitor_clearsIPAndReturnsToNoIP() async throws {
        let controller = try await connectedController()
        controller.forgetMonitor()
        XCTAssertNil(preferences.monitorIP)
        XCTAssertEqual(controller.state, .noIP)
    }

    func test_connect_storesMAC() async throws {
        let controller = try await connectedController()
        try await waitFor { self.preferences.monitorMAC == "02:00:00:00:00:01" }
        controller.stop()
    }

    func test_powerOn_whenAPIAnswersStandby_sendsPowerKeyOverWebSocket() async throws {
        let controller = try await connectedController()
        lan.powerState = "standby"
        await controller.changePower(toOn: true)
        XCTAssertEqual(spy.sendKeyCalls, [.power])
        XCTAssertTrue(lan.wakeCalls.isEmpty)
        XCTAssertEqual(controller.powerState, .standby)
        controller.stop()
    }

    func test_powerOn_whenAPIAnswersOn_doesNothing() async throws {
        let controller = try await connectedController()
        await controller.changePower(toOn: true)
        XCTAssertTrue(spy.sendKeyCalls.isEmpty)
        XCTAssertTrue(lan.wakeCalls.isEmpty)
        controller.stop()
    }

    func test_powerOn_whenAPIDoesNotAnswer_sendsWakeOnLANToStoredMAC() async throws {
        preferences.monitorIP = "192.168.1.10"
        preferences.monitorMAC = "02:00:00:00:00:01"
        lan.deviceInfoFails = true
        let controller = makeController()
        await controller.changePower(toOn: true)
        XCTAssertEqual(lan.wakeCalls, ["02:00:00:00:00:01"])
        XCTAssertTrue(spy.sendKeyCalls.isEmpty)
        XCTAssertEqual(controller.powerState, .off)
    }

    func test_powerOn_whenAPIDoesNotAnswerAndNoMAC_logsAndSkips() async {
        lan.deviceInfoFails = true
        let controller = makeController()
        await controller.changePower(toOn: true)
        XCTAssertTrue(controller.logEntries.last?.contains("no MAC stored") == true)
        XCTAssertTrue(lan.wakeCalls.isEmpty)
    }

    func test_powerOn_inStandbyWhileDisconnected_reconnectsThenSendsPowerKey() async throws {
        preferences.monitorIP = "192.168.1.10"
        spy.nextConnectOutcome = .success(token: "t")
        lan.powerState = "standby"
        let controller = makeController()
        XCTAssertNotEqual(controller.state, .connected)
        await controller.changePower(toOn: true)
        XCTAssertEqual(controller.state, .connected)
        XCTAssertEqual(spy.sendKeyCalls, [.power])
        controller.stop()
    }

    func test_powerOff_onlySendsPowerKeyWhenOn() async throws {
        let controller = try await connectedController()
        lan.powerState = "standby"
        await controller.changePower(toOn: false)
        XCTAssertTrue(spy.sendKeyCalls.isEmpty)

        lan.powerState = "on"
        await controller.changePower(toOn: false)
        XCTAssertEqual(spy.sendKeyCalls, [.power])
        controller.stop()
    }

    func test_refreshPowerState_publishesOnStandbyAndOff() async throws {
        let controller = makeController()
        preferences.monitorIP = "192.168.1.10"
        await controller.refreshPowerState()
        XCTAssertEqual(controller.powerState, .on)
        lan.powerState = "standby"
        await controller.refreshPowerState()
        XCTAssertEqual(controller.powerState, .standby)
        lan.deviceInfoFails = true
        await controller.refreshPowerState()
        XCTAssertEqual(controller.powerState, .off)
    }

    func test_standby_connectionLostThenMonitorAcceptsSocket_reconnects() async throws {
        let controller = try await connectedController()
        lan.powerState = "standby"
        let baseline = spy.connectCalls.count

        spy.simulateClose(error: URLError(.networkConnectionLost))
        try await waitFor({ self.spy.connectCalls.count > baseline && controller.state == .connected },
                          timeout: .milliseconds(2500))
        controller.stop()
    }

    func test_powerOffInputsAndPad_sendExpectedKeys() async throws {
        let controller = try await connectedController()
        controller.powerOff()
        controller.openInputSourceMenu()
        controller.nextHDMIInput()
        try await waitFor { self.spy.sendKeyCalls.count == 3 }
        XCTAssertEqual(Set(spy.sendKeyCalls), [.power, .source, .hdmi])
        controller.stop()
    }
}
