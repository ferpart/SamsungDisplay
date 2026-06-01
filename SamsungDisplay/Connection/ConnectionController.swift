import Foundation
import Observation
import OSLog

/// Owns the entire Samsung WebSocket lifecycle on behalf of the UI.
///
/// `@MainActor @Observable` (02-RESEARCH.md Pattern 2): every property the
/// `MenuBarExtra` / `PopoverContent` / `SettingsView` reads from is mutated
/// here on the main actor; SwiftUI tracks reads via the Observation framework.
///
/// Single source of truth for:
/// * Connection state (5 cases)
/// * Status message (one-line popover text)
/// * Log entries (capped at 50; surfaced by SettingsView)
///
/// Wave 0 tests drive this class via injected `SpyWSDriver` (SamsungWSDriving),
/// `FakePathObserver` (NetworkPathObserving), and a UserDefaults-backed
/// `AppPreferences` + scoped `TokenStore`. Production code constructs the
/// controller with `SamsungWSActor()`, `NetworkPathObserver()`,
/// `AppPreferences.shared`, `TokenStore.shared` — the default arguments.
@MainActor
@Observable
final class ConnectionController {

    // Observable surface — UI binds to these.
    private(set) var state: ConnectionState = .noIP
    private(set) var statusMessage: String = "Not connected"
    private(set) var logEntries: [String] = []

    // Injected dependencies.
    private let ws: any SamsungWSDriving
    private let pathObserver: any NetworkPathObserving
    private let preferences: AppPreferences
    private let tokens: TokenStore
    private let policy: ReconnectPolicy

    private var lifecycleTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.fp.SamsungDisplay", category: "samsung-conn")
    private let logCap = 50

    init(
        ws: any SamsungWSDriving = SamsungWSActor(),
        pathObserver: any NetworkPathObserving = NetworkPathObserver(),
        preferences: AppPreferences = .shared,
        tokens: TokenStore = .shared,
        policy: ReconnectPolicy = .default
    ) {
        self.ws = ws
        self.pathObserver = pathObserver
        self.preferences = preferences
        self.tokens = tokens
        self.policy = policy
        self.pathObserver.onPathSatisfied = { [weak self] in self?.kickReconnect() }
        self.pathObserver.onPathLost = { [weak self] in self?.handlePathLost() }
        self.pathObserver.start()
    }

    deinit {
        // `deinit` is NOT inherited as @MainActor under Swift 6. Use
        // `assumeIsolated` to bridge — by the time deinit runs, no further
        // observers can touch this instance, so it's safe to assume the
        // last-reference release happened on the main actor (which is true
        // for any normal @MainActor consumer path).
        MainActor.assumeIsolated {
            self.lifecycleTask?.cancel()
        }
    }

    /// Called once on app launch. Reads `monitorIP` and either starts the
    /// connect loop or transitions to `.noIP` for the popover prompt.
    ///
    /// Idempotent: if a `lifecycleTask` is already running, this is a no-op.
    /// The popover's `.onAppear` fires every time the user opens the menu bar
    /// item, but the WebSocket must persist across popover open/close cycles.
    func bootstrap() {
        if lifecycleTask != nil {
            return
        }
        guard let ip = preferences.monitorIP, !ip.isEmpty else {
            state = .noIP
            statusMessage = "Not connected — set monitor IP in Settings"
            append("bootstrap: no IP configured")
            return
        }
        start(ip: ip)
    }

    /// Forward a remote-key send. Runs as a fire-and-forget Task; failure is
    /// appended to `logEntries` and surfaced via the status line (briefly
    /// flashed by the view layer) but does NOT mutate `state` — local key
    /// sends do not redefine our connection truth.
    func send(_ key: SamsungCommand.Key) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.ws.sendKey(key)
            } catch {
                self.append("send \(key.rawValue) failed: \(error)")
            }
        }
    }

    /// Sticky-deny recovery: drop the keychain token, then restart the loop.
    /// Reads token AFTER delete to confirm it's gone (RESEARCH.md Pitfall #4).
    func wipeTokenAndReconnect() {
        tokens.delete()
        append("token wiped")
        guard let ip = preferences.monitorIP, !ip.isEmpty else {
            state = .noIP
            statusMessage = "Not connected — set monitor IP in Settings"
            return
        }
        start(ip: ip)
    }

    /// (Re)start the lifecycle task for `ip`. Cancels any in-flight task first
    /// so we never have two parallel loops (RESEARCH.md Pitfall #2).
    func start(ip: String) {
        lifecycleTask?.cancel()
        lifecycleTask = Task { @MainActor [weak self] in
            await self?.runConnectLoop(ip: ip)
        }
    }

    /// Cancel the loop and return to `.disconnected`. Used by tests; not
    /// currently called from production UI.
    func stop() {
        lifecycleTask?.cancel()
        lifecycleTask = nil
        state = .disconnected
        statusMessage = "Disconnected"
    }

    // MARK: - Internals

    /// Called by `NetworkPathObserver` on `.satisfied` transitions. Restarting
    /// the lifecycle task cancels the current `Task.sleep` so we retry
    /// immediately (RESEARCH.md Pattern 4 + Pitfall #2).
    private func kickReconnect() {
        guard state != .connected, state != .unauthorized else { return }
        guard let ip = preferences.monitorIP, !ip.isEmpty else { return }
        append("path satisfied — kicking reconnect")
        start(ip: ip)
    }

    /// Called by `NetworkPathObserver` on `.unsatisfied` / `.requiresConnection`
    /// / adapter-change transitions. Transition to `.connecting` immediately
    /// (the icon flips to pulse) and restart the lifecycle task so the
    /// parked `ws.waitForClose()` returns via CancellationError. The fresh
    /// loop's first connect attempt will fail until the path is satisfied
    /// again, which is exactly the desired UX: visible "Reconnecting…" in
    /// the popover + backoff schedule visible in Settings → Logs.
    private func handlePathLost() {
        guard state != .unauthorized, state != .noIP else { return }
        append("path lost")
        state = .connecting
        statusMessage = "Reconnecting…"
        guard let ip = preferences.monitorIP, !ip.isEmpty else { return }
        start(ip: ip)
    }

    /// The core exponential-backoff loop (RESEARCH.md Pattern 3). Re-reads the
    /// token from `TokenStore` on every iteration so wipe-token takes effect
    /// (RESEARCH.md Pitfall #4).
    private func runConnectLoop(ip: String) async {
        var lastDelay: Duration? = nil

        while !Task.isCancelled {
            state = .connecting
            statusMessage = "Reconnecting…"
            let token = tokens.load()
            do {
                let newToken = try await ws.connect(to: ip, token: token)
                if newToken != token {
                    do { try tokens.save(newToken) }
                    catch { append("token save failed: \(error)") }
                }
                state = .connected
                statusMessage = "Connected"
                lastDelay = nil   // reset on success
                append("connected")
                // Park here until the driver detects a disconnect (server
                // close, receive-loop error, application-level heartbeat
                // timeout). Any throw surfaces as a connection loss and we
                // fall through to the backoff sleep + retry. A clean return
                // from `waitForClose()` is not part of the contract; if it
                // happens we still retry.
                do {
                    try await ws.waitForClose()
                    append("waitForClose returned cleanly — retrying")
                } catch is CancellationError {
                    return    // user action or path-lost cancelled us
                } catch {
                    append("connection lost: \(error)")
                    // Fall through to the backoff + retry below
                }
            } catch SamsungWSError.unauthorized {
                state = .unauthorized
                statusMessage = "Pairing rejected — see recovery steps"
                append("unauthorized")
                return
            } catch is CancellationError {
                return
            } catch {
                append("connect failed: \(error)")
            }

            let delay = policy.nextDelay(after: lastDelay)
            lastDelay = delay
            do { try await Task.sleep(for: delay) }
            catch { return }   // cancelled while sleeping
        }
    }

    private func append(_ line: String) {
        let stamp = ConnectionController.timestamp()
        let entry = "\(stamp)  \(line)"
        logEntries.append(entry)
        if logEntries.count > logCap {
            logEntries.removeFirst(logEntries.count - logCap)
        }
        logger.info("\(line, privacy: .public)")
    }

    /// HH:mm:ss timestamp. Static helper so tests don't have to mock a clock.
    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
}
