import Foundation
import Network

/// Test-injectable surface over `NWPathMonitor`.
///
/// `ConnectionControllerTests` injects `FakePathObserver` (also conforming
/// to this protocol) so unit tests don't stand up a real path monitor.
///
/// The callback signature is explicitly `@MainActor` because the controller
/// touches `@Observable` state from inside the closure body.
///
/// **Wave 0 carry-forward:** This protocol MUST be declared `@MainActor`
/// (not just the closure). `FakePathObserver` is `@MainActor`-isolated;
/// without `@MainActor` on the protocol, its members cannot satisfy the
/// protocol's nonisolated requirements under Swift 6 strict concurrency.
@MainActor
protocol NetworkPathObserving: AnyObject {
    var onPathSatisfied: (@MainActor () -> Void)? { get set }
    /// Fires when the path transitions to a non-satisfied status
    /// (`.unsatisfied`, `.requiresConnection`, or adapter-change).
    /// Wave 5 Plan 02-05 wires the production pathUpdateHandler.
    var onPathLost: (@MainActor () -> Void)? { get set }
    func start()
    func stop()
}

/// Production `NetworkPathObserving` driven by `NWPathMonitor`.
///
/// `02-RESEARCH.md` Pattern 4 + Pitfall #2: a single owned monitor on a
/// private serial queue, routing `.satisfied` transitions to the main actor.
/// The controller debounces by funneling all reconnect triggers through one
/// owned `lifecycleTask`.
@MainActor
final class NetworkPathObserver: NetworkPathObserving {
    // `NWPathMonitor` is Apple-provided and thread-safe; we hop to MainActor
    // inside the pathUpdateHandler before touching `onPathSatisfied`, which is
    // MainActor-isolated by the protocol.
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.fp.SamsungDisplay.path", qos: .utility)

    var onPathSatisfied: (@MainActor () -> Void)?
    var onPathLost: (@MainActor () -> Void)?

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            // The path-update handler runs on `queue`, not the main actor.
            // Hop to MainActor before reading `onPathSatisfied`.
            Task { @MainActor in
                self?.onPathSatisfied?()
            }
        }
        monitor.start(queue: queue)
    }

    /// Idempotent — `NWPathMonitor.cancel()` may be called repeatedly with
    /// no ill effect (defensive against the test path where the observer is
    /// torn down without ever starting).
    func stop() {
        monitor.cancel()
    }
}
