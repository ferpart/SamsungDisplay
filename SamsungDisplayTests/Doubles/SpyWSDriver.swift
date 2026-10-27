@testable import SamsungDisplay
import Foundation
import os

// Both `SamsungWSDriving` and `NetworkPathObserving` now live in production
// code (see `SamsungDisplay/Samsung/SamsungWSActor.swift` and
// `SamsungDisplay/Connection/NetworkPathObserver.swift`). The Wave 0
// placeholders have been removed; SpyWSDriver/FakePathObserver conform to
// the real protocols via `@testable import SamsungDisplay` above.

// MARK: - SpyWSDriver

/// Thread-safe spy for SamsungWSDriving used in ConnectionControllerTests.
/// Records every connect/sendKey/disconnect call. Tests inject the outcome
/// of the next connect via `nextConnectOutcome`.
///
/// Uses `OSAllocatedUnfairLock` (async-safe under Swift 6 strict concurrency)
/// instead of `NSLock` — `NSLock.lock()` is `@available(*, unavailable)` from
/// async contexts.
final class SpyWSDriver: SamsungWSDriving, @unchecked Sendable {

    enum ConnectOutcome: Sendable {
        case success(token: String)
        case unauthorized
        case error(any Error)
        /// Suspends until cancelled. Used to test that user actions cancel
        /// the in-flight connect.
        case hang
    }

    private struct State {
        var connectCalls: [(ip: String, token: String?, pin: String?)] = []
        var certificateSHA256: String? = "spy-certificate"
        var sendKeyCalls: [SamsungCommand.Key] = []
        var disconnectCalls: Int = 0
        var nextConnectOutcome: ConnectOutcome = .success(token: "spy-token")
        var nextSendKeyError: (any Error)? = nil
        var pendingClose: CheckedContinuation<Void, any Error>? = nil
    }

    private let state = OSAllocatedUnfairLock<State>(initialState: State())

    // Recorded calls (read-only views for assertions).
    var connectCalls: [(ip: String, token: String?, pin: String?)] {
        state.withLock { $0.connectCalls }
    }
    var sendKeyCalls: [SamsungCommand.Key] {
        state.withLock { $0.sendKeyCalls }
    }
    var disconnectCalls: Int {
        state.withLock { $0.disconnectCalls }
    }

    // Scripted outcomes. Tests mutate before calling controller methods.
    var nextConnectOutcome: ConnectOutcome {
        get { state.withLock { $0.nextConnectOutcome } }
        set { state.withLock { $0.nextConnectOutcome = newValue } }
    }
    var certificateSHA256: String? {
        get { state.withLock { $0.certificateSHA256 } }
        set { state.withLock { $0.certificateSHA256 = newValue } }
    }
    var nextSendKeyError: (any Error)? {
        get { state.withLock { $0.nextSendKeyError } }
        set { state.withLock { $0.nextSendKeyError = newValue } }
    }

    func connect(to ip: String, token: String?, pinnedCertificateSHA256: String?) async throws -> SamsungConnection {
        let (outcome, certificate) = state.withLock { s -> (ConnectOutcome, String?) in
            s.connectCalls.append((ip, token, pinnedCertificateSHA256))
            return (s.nextConnectOutcome, s.certificateSHA256)
        }
        switch outcome {
        case .success(let token):
            return SamsungConnection(token: token, certificateSHA256: certificate)
        case .unauthorized:
            throw SamsungWSError.unauthorized
        case .error(let e):
            throw e
        case .hang:
            // Cooperative-cancellation-friendly indefinite suspension.
            try await Task.sleep(for: .seconds(60))
            throw CancellationError()
        }
    }

    func sendKey(_ key: SamsungCommand.Key) async throws {
        let err = state.withLock { s -> (any Error)? in
            s.sendKeyCalls.append(key)
            return s.nextSendKeyError
        }
        if let err { throw err }
    }

    func disconnect() async {
        state.withLock { $0.disconnectCalls += 1 }
    }

    func waitForClose() async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
                state.withLock { $0.pendingClose = cont }
            }
        } onCancel: {
            let parked = state.withLock { s -> CheckedContinuation<Void, any Error>? in
                let p = s.pendingClose
                s.pendingClose = nil
                return p
            }
            parked?.resume(throwing: CancellationError())
        }
    }

    /// Test helper: complete the parked `waitForClose()` await with `error`.
    /// Mirrors a real server-side close, receive-loop error, or
    /// application-level heartbeat timeout.
    func simulateClose(error: any Error) {
        let parked = state.withLock { s -> CheckedContinuation<Void, any Error>? in
            let p = s.pendingClose
            s.pendingClose = nil
            return p
        }
        parked?.resume(throwing: error)
    }
}
