import Foundation
import OSLog

/// Errors produced by `SamsungWSActor` connect / sendKey / disconnect flows.
///
/// `Sendable` because the actor surfaces these across isolation domains via
/// `throws`. They carry no associated values that need their own Sendable
/// conformance.
enum SamsungWSError: Error, Sendable {
    /// The WebSocket connected and the receive loop drained without ever
    /// surfacing a `ms.channel.connect` token, AND no input token was provided.
    case noTokenInResponse
    /// The 30-second guard fired before any frame arrived. Guards against the
    /// silent-hang failure mode documented in RESEARCH.md Pitfall #6 (network
    /// reachable but Tizen "Remote access" toggle off).
    case connectionTimeout
    /// The monitor explicitly rejected the credentials (`ms.channel.unauthorized`).
    case unauthorized
    /// `sendKey` / `disconnect` called without a successful `connect` first.
    case notConnected
}

/// Swift actor wrapping `URLSessionWebSocketTask` for the Samsung Tizen remote.
///
/// The actor owns the `URLSession`, the `URLSessionWebSocketTask`, and the
/// `SamsungTLSDelegate` instance. Swift's actor isolation serializes all access,
/// so we never need locks or DispatchQueues. `URLSessionWebSocketTask` is
/// non-Sendable but is only ever touched inside this actor's isolation domain,
/// which is safe under Swift 6 strict concurrency.
///
/// Design contract (from PLAN 01-06):
///
/// * `connect(to:token:)` opens a single persistent WebSocket, runs the receive
///   loop to surface the first `ms.channel.connect` token, and returns that
///   token. On reconnect (token provided up-front) it accepts the first
///   `ms.channel.connect` frame as success and returns the input token unchanged
///   — Samsung does not necessarily re-issue a token on subsequent connects.
/// * `sendKey(_:)` requires `connect` to have completed; sends a single
///   `SamsungCommand` JSON frame over the open connection.
/// * `disconnect()` cleanly tears down the task, session, and delegate.
///
/// Anti-patterns avoided (RESEARCH.md):
/// * NOT open/close per `sendKey` — the connection stays open across many key
///   sends, which is the whole point of the persistent-connection assumption.
/// * NOT log the raw token at info level — credentials gated to `#if DEBUG`.
/// * NOT use Starscream — URLSessionWebSocketTask is the chosen transport.
/// * NOT swallow errors in the receive loop — surfaced via `throws`.
/// * NOT touch the keychain wrapper here — the actor returns the token; the
///   harness owns persistence so the actor stays pure-protocol and easy to
///   unit-test in isolation.
actor SamsungWSActor {

    private let appName: String
    private let logger = Logger(subsystem: "com.fp.SamsungDisplay", category: "samsung-ws")

    private var delegate: SamsungTLSDelegate?
    private var session: URLSession?
    private var task: URLSessionWebSocketTask?

    // MARK: - Liveness state (Wave 5 / Plan 02-06)

    /// Owns the post-handshake receive loop + heartbeat work.
    private var liveTask: Task<Void, Never>?

    /// Parked awaits from `waitForClose()`. Resumed by `liveTask` on any
    /// close/error, or by `disconnect()` with `.notConnected`.
    private var closeWaiters: [CheckedContinuation<Void, any Error>] = []

    init(appName: String = "SamsungDisplay") {
        self.appName = appName
    }

    /// Open a Samsung remote WebSocket and resolve the auth token.
    ///
    /// - Parameters:
    ///   - ip: Monitor IP on the LAN. Used both as the WebSocket host and as
    ///         the pinned `allowedHost` on `SamsungTLSDelegate`.
    ///   - token: Optional saved token from a previous pairing. If `nil`, the
    ///            monitor will show a pairing popup; if non-nil, the monitor
    ///            should silently accept the existing pairing.
    /// - Returns: A non-empty pairing token. If the input `token` was non-nil
    ///   and the monitor did not re-issue one, returns the input unchanged.
    /// - Throws: `SamsungWSError.connectionTimeout` on 30s no-frame guard,
    ///   `SamsungWSError.unauthorized` on explicit reject,
    ///   `SamsungWSError.noTokenInResponse` if the loop ends without resolution.
    func connect(to ip: String, token: String?) async throws -> String {
        // Tear down any previous connection so callers can call connect again
        // after a disconnect without leaking state.
        await disconnect()

        let pinned = SamsungTLSDelegate(allowedHost: ip)
        self.delegate = pinned

        let urlSession = URLSession(configuration: .default,
                                    delegate: pinned,
                                    delegateQueue: nil)
        self.session = urlSession

        let url = samsungWebSocketURL(host: ip, appName: appName, token: token)
        logOutgoingURL(url)

        let wsTask = urlSession.webSocketTask(with: url)
        self.task = wsTask
        wsTask.resume()

        // 30-second guard against the silent-hang failure mode. We race the
        // receive loop against a sleep; whichever finishes first wins, and
        // the loser is cancelled.
        let result = try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask { [weak self] in
                guard let self else { throw SamsungWSError.notConnected }
                return try await self.receiveLoop(task: wsTask, inputToken: token)
            }
            group.addTask {
                try await Task.sleep(for: .seconds(30))
                throw SamsungWSError.connectionTimeout
            }
            // First child to complete wins.
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
        // Start the post-handshake liveness work. From here on, any close,
        // receive error, or heartbeat timeout will surface via waitForClose().
        startLiveTask(task: wsTask)
        return result
    }

    /// Send a single key command over the open WebSocket. Requires `connect`.
    func sendKey(_ key: SamsungCommand.Key) async throws {
        guard let task else { throw SamsungWSError.notConnected }
        let command = SamsungCommand(key: key)
        let data = try JSONEncoder().encode(command)
        guard let text = String(data: data, encoding: .utf8) else {
            throw SamsungWSError.notConnected
        }
        try await task.send(.string(text))
        logger.info("sent \(key.rawValue, privacy: .public)")
    }

    /// Suspends until the open WebSocket disconnects.
    ///
    /// Returns ONLY by throwing — server-side close, receive-loop error,
    /// or application-level heartbeat timeout all surface as a thrown
    /// error here. A clean return is not part of the contract.
    ///
    /// If not connected (never called `connect` or already disconnected):
    /// throws `SamsungWSError.notConnected` immediately.
    ///
    /// Cancellation-safe: if the calling `Task` is cancelled, the parked
    /// continuation is resumed with `CancellationError`.
    func waitForClose() async throws {
        guard task != nil else {
            throw SamsungWSError.notConnected
        }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
                closeWaiters.append(cont)
            }
        } onCancel: {
            // We're outside the actor here. Hop in to pop our continuation
            // (if it's still parked) and resume with CancellationError.
            Task { [weak self] in
                await self?.cancelOneWaiter()
            }
        }
    }

    /// Pop the most-recently-parked waiter (best-effort) and resume it
    /// with `CancellationError`. Called from the cancellation handler.
    private func cancelOneWaiter() {
        if let cont = closeWaiters.popLast() {
            cont.resume(throwing: CancellationError())
        }
    }

    /// Tear down the WebSocket task, URLSession, and TLS delegate cleanly.
    /// Idempotent — safe to call when nothing is open.
    ///
    /// Cancels the post-handshake live task and resumes any parked
    /// `waitForClose()` continuations with `.notConnected`.
    func disconnect() async {
        liveTask?.cancel()
        liveTask = nil
        resumeWaiters(throwing: SamsungWSError.notConnected)
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        session?.invalidateAndCancel()
        session = nil
        delegate = nil
    }

    // MARK: - Internals

    // MARK: Post-handshake liveness (Plan 02-06)

    /// Spawn the post-handshake liveness work. Runs a receive loop + a
    /// heartbeat ping in parallel; whichever surfaces an error first wins
    /// and resumes any parked `waitForClose()` continuations with that
    /// error. Once this method has been called, `disconnect()` must be the
    /// only path that cancels the work.
    private func startLiveTask(task: URLSessionWebSocketTask) {
        // Cancel any prior live task defensively.
        liveTask?.cancel()
        liveTask = Task { [weak self] in
            let closeError: any Error
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask { [weak self] in
                        try await self?.receiveLoopPostHandshake(task: task)
                    }
                    group.addTask { [weak self] in
                        try await self?.heartbeatLoop(task: task)
                    }
                    // First child to throw cancels the rest.
                    try await group.next()
                    group.cancelAll()
                }
                // The group resolved without throwing — shouldn't happen
                // for a well-formed liveness pair (both loops are infinite
                // until an error). Treat as a clean close.
                closeError = SamsungWSError.notConnected
            } catch {
                closeError = error
            }
            await self?.resumeWaiters(throwing: closeError)
        }
    }

    /// Continuous post-handshake receive loop. Drains frames; any thrown
    /// error from `task.receive()` is the close signal.
    private func receiveLoopPostHandshake(task: URLSessionWebSocketTask) async throws {
        while !Task.isCancelled {
            _ = try await task.receive()
            // Frames are ignored post-handshake; we don't model them in Phase 2.
            #if DEBUG
            logger.debug("post-handshake frame received (ignored)")
            #endif
        }
        // Cooperative cancellation — `disconnect()` cancelled us. Re-throw
        // a benign cancellation so the group resolves cleanly.
        throw CancellationError()
    }

    /// Heartbeat loop. Every 15s sends a ping; expects a pong within 5s.
    /// On pong error OR timeout, throws to break the live group.
    ///
    /// Heartbeat interval: 15s. Pong timeout: 5s.
    /// Recorded in SUMMARY for Wave 7 hardware re-walk latency budget.
    private func heartbeatLoop(task: URLSessionWebSocketTask) async throws {
        while !Task.isCancelled {
            try await Task.sleep(for: .seconds(15))
            try await sendPingWithTimeout(task: task, timeout: .seconds(5))
        }
        throw CancellationError()
    }

    /// Sends a ping and races the pong against a timeout. Throws on either
    /// a non-nil pong error OR the timeout firing first.
    private func sendPingWithTimeout(task: URLSessionWebSocketTask,
                                     timeout: Duration) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
                    task.sendPing { error in
                        if let error {
                            cont.resume(throwing: error)
                        } else {
                            cont.resume()
                        }
                    }
                }
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw SamsungWSError.connectionTimeout
            }
            try await group.next()
            group.cancelAll()
        }
    }

    /// Resume every parked waiter with `error` and clear the list.
    private func resumeWaiters(throwing error: any Error) {
        let waiters = closeWaiters
        closeWaiters.removeAll()
        for cont in waiters {
            cont.resume(throwing: error)
        }
    }

    // MARK: Phase 1 handshake receive loop (unchanged)

    /// Pump frames off the WebSocket until we resolve a token (or determine
    /// the input token reconnect succeeded), or the connection closes.
    private func receiveLoop(task: URLSessionWebSocketTask,
                             inputToken: String?) async throws -> String {
        while !Task.isCancelled {
            let message: URLSessionWebSocketTask.Message
            do {
                message = try await task.receive()
            } catch {
                logger.error("receive failed: \(String(describing: error), privacy: .public)")
                throw error
            }

            switch message {
            case .string(let text):
                #if DEBUG
                logger.debug("frame: \(text, privacy: .public)")
                #endif
                if let resolved = try handleTextFrame(text, inputToken: inputToken) {
                    return resolved
                }
            case .data(let data):
                #if DEBUG
                logger.debug("binary frame (\(data.count) bytes), skipping")
                #endif
            @unknown default:
                logger.notice("unknown frame kind, skipping")
            }
        }
        throw SamsungWSError.noTokenInResponse
    }

    /// Interpret a single text frame. Returns the resolved token if this frame
    /// completed the handshake; `nil` to keep reading; throws on explicit
    /// reject.
    private func handleTextFrame(_ text: String, inputToken: String?) throws -> String? {
        // Cheap event-name peek before full decode, for the unauthorized case.
        if text.contains("\"event\"") {
            if text.contains("ms.channel.unauthorized") {
                logger.error("ms.channel.unauthorized received")
                throw SamsungWSError.unauthorized
            }
            if text.contains("ms.channel.connect") {
                logger.info("ms.channel.connect received")
                if let token = SamsungAuthResponse.extractToken(from: text) {
                    logger.info("token received (length=\(token.count, privacy: .public))")
                    return token
                }
                // No token in the connect frame — that's the reconnect path.
                // If the caller supplied a token, treat the connect as success.
                if let inputToken {
                    logger.info("reconnect succeeded; reusing input token")
                    return inputToken
                }
                // Otherwise keep reading; some firmwares emit two connect frames.
            }
        }
        return nil
    }

    private func logOutgoingURL(_ url: URL) {
        // Redact the token query item to keep credentials out of release logs.
        var redacted = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let items = redacted?.queryItems
        redacted?.queryItems = items?.map { item in
            item.name == "token"
                ? URLQueryItem(name: "token", value: "<redacted>")
                : item
        }
        let toLog = redacted?.string ?? url.absoluteString
        logger.info("connecting to \(toLog, privacy: .public)")
    }
}

// MARK: - SamsungWSDriving

/// Test seam for `ConnectionController` — production code uses
/// `SamsungWSActor`; unit tests inject `SpyWSDriver`
/// (`SamsungDisplayTests/Doubles/SpyWSDriver.swift`).
///
/// Declared at module scope so the test target can pick it up via
/// `@testable import SamsungDisplay`.
protocol SamsungWSDriving: Sendable {
    func connect(to ip: String, token: String?) async throws -> String
    func sendKey(_ key: SamsungCommand.Key) async throws
    func disconnect() async
    /// Suspends until the open WebSocket disconnects.
    ///
    /// Returns ONLY by throwing — server-side close, receive-loop error,
    /// or application-level heartbeat timeout all surface as a thrown
    /// error here. A clean return is not part of the contract.
    ///
    /// Must be called after a successful `connect(to:token:)` and at most
    /// once per connect. Safe to call concurrently with `sendKey`.
    func waitForClose() async throws -> Void
}

extension SamsungWSActor: SamsungWSDriving {}
