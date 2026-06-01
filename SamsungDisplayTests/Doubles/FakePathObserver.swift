@testable import SamsungDisplay

// `NetworkPathObserving` lives in production (see
// `SamsungDisplay/Connection/NetworkPathObserver.swift`). FakePathObserver
// conforms to the real protocol via `@testable import SamsungDisplay` and
// exposes `firePathSatisfied()` / `firePathLost()` for controller tests.

@MainActor
final class FakePathObserver: NetworkPathObserving {
    var onPathSatisfied: (@MainActor () -> Void)?
    var onPathLost: (@MainActor () -> Void)?
    private(set) var startCalled = false
    private(set) var stopCalled = false

    func start() { startCalled = true }
    func stop()  { stopCalled = true }

    /// Test helper: fire the satisfied callback as if NWPathMonitor saw a
    /// .satisfied path transition.
    func firePathSatisfied() {
        onPathSatisfied?()
    }

    /// Test helper: fire the path-lost callback as if NWPathMonitor saw a
    /// .unsatisfied / .requiresConnection / adapter-change transition.
    func firePathLost() {
        onPathLost?()
    }
}
