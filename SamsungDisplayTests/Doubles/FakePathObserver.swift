@testable import SamsungDisplay

// `NetworkPathObserving` is declared in SpyWSDriver.swift as a Wave 0
// placeholder. Wave 1 will move it to production code (see TODO there).

@MainActor
final class FakePathObserver: NetworkPathObserving {
    var onPathSatisfied: (@MainActor () -> Void)?
    private(set) var startCalled = false
    private(set) var stopCalled = false

    func start() { startCalled = true }
    func stop()  { stopCalled = true }

    /// Test helper: fire the satisfied callback as if NWPathMonitor saw a
    /// .satisfied path transition.
    func firePathSatisfied() {
        onPathSatisfied?()
    }
}
