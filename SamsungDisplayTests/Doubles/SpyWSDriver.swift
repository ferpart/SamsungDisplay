@testable import SamsungDisplay
import Foundation
import os

// MARK: - Wave 1 placeholder (SamsungWSDriving)
//
// `NetworkPathObserving` now lives in production code
// (`SamsungDisplay/Connection/NetworkPathObserver.swift`), so its Wave 0
// placeholder has been removed.
//
// `SamsungWSDriving` is added to production code in Task 2 of 02-01-PLAN
// (alongside `ConnectionController`). Until that lands, keep this placeholder
// so SpyWSDriver compiles.
//
// TODO(02-01 Task 2): DELETE this `SamsungWSDriving` placeholder once
// production declares it in `SamsungDisplay/Samsung/SamsungWSActor.swift`.

protocol SamsungWSDriving: Sendable {
    func connect(to ip: String, token: String?) async throws -> String
    func sendKey(_ key: SamsungCommand.Key) async throws
    func disconnect() async
}

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
        var connectCalls: [(ip: String, token: String?)] = []
        var sendKeyCalls: [SamsungCommand.Key] = []
        var disconnectCalls: Int = 0
        var nextConnectOutcome: ConnectOutcome = .success(token: "spy-token")
        var nextSendKeyError: (any Error)? = nil
    }

    private let state = OSAllocatedUnfairLock<State>(initialState: State())

    // Recorded calls (read-only views for assertions).
    var connectCalls: [(ip: String, token: String?)] {
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
    var nextSendKeyError: (any Error)? {
        get { state.withLock { $0.nextSendKeyError } }
        set { state.withLock { $0.nextSendKeyError = newValue } }
    }

    func connect(to ip: String, token: String?) async throws -> String {
        let outcome = state.withLock { s -> ConnectOutcome in
            s.connectCalls.append((ip, token))
            return s.nextConnectOutcome
        }
        switch outcome {
        case .success(let token):
            return token
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
}
