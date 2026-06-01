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

/// Side-effect description from interpreting one NWPath update against
/// the previous snapshot. Pure value type — no main-actor work, no I/O.
/// `internal` so `NetworkPathObserverTests` can drive it directly.
enum PathDispatch: Equatable {
    case none
    case satisfied
    case lost
    case adapterChanged
}

/// Minimal projection of NWPath consumed by the dispatch routine.
/// Allows tests to run without standing up a real NWPathMonitor.
struct PathSnapshot: Equatable {
    let status: NWPath.Status
    /// Stable fingerprint of `availableInterfaces` so adapter-change
    /// transitions (Wi-Fi -> Ethernet, etc.) are detectable while the
    /// overall status remains `.satisfied`.
    let interfaceFingerprint: String

    init(status: NWPath.Status, interfaceFingerprint: String) {
        self.status = status
        self.interfaceFingerprint = interfaceFingerprint
    }

    /// Build from a live NWPath. Fingerprint is name+type per interface,
    /// joined; cheap and stable across identical interface sets.
    init(_ path: NWPath) {
        self.status = path.status
        self.interfaceFingerprint = path.availableInterfaces
            .map { "\($0.name)/\($0.type)" }
            .sorted()
            .joined(separator: ",")
    }
}

/// Pure dispatch table — no main-actor work, no I/O.
func networkPathDispatch(previous: PathSnapshot?, current: PathSnapshot) -> PathDispatch {
    guard let previous else {
        return current.status == .satisfied ? .satisfied : .lost
    }
    let wasSatisfied = previous.status == .satisfied
    let isSatisfied  = current.status  == .satisfied
    switch (wasSatisfied, isSatisfied) {
    case (true, true):
        return previous.interfaceFingerprint == current.interfaceFingerprint
            ? .none
            : .adapterChanged
    case (true, false):  return .lost
    case (false, true):  return .satisfied
    case (false, false): return .none
    }
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

    private var previous: PathSnapshot?

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let snapshot = PathSnapshot(path)
            // pathUpdateHandler runs on `queue` (utility QoS), NOT main.
            // Hop to MainActor before reading/writing `previous` and
            // firing callbacks (both are MainActor-isolated).
            Task { @MainActor [weak self] in
                guard let self else { return }
                let outcome = networkPathDispatch(previous: self.previous, current: snapshot)
                self.previous = snapshot
                switch outcome {
                case .none:
                    break
                case .satisfied:
                    self.onPathSatisfied?()
                case .lost:
                    self.onPathLost?()
                case .adapterChanged:
                    // Treated by the controller as: disconnect signal
                    // immediately followed by a kick-reconnect signal —
                    // forces the WS task to restart on the new interface.
                    self.onPathLost?()
                    self.onPathSatisfied?()
                }
            }
        }
        monitor.start(queue: queue)
    }

    /// Idempotent — `NWPathMonitor.cancel()` may be called repeatedly with
    /// no ill effect (defensive against the test path where the observer is
    /// torn down without ever starting).
    func stop() {
        monitor.cancel()
        previous = nil
    }
}
