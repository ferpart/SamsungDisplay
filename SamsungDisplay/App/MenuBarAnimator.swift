import Observation

@MainActor
@Observable
final class MenuBarAnimator {
    private(set) var step = 0
    @ObservationIgnored private var timer: Task<Void, Never>?

    var isAnimating: Bool { timer != nil }

    func update(isConnecting: Bool) {
        guard isConnecting else {
            timer?.cancel()
            timer = nil
            step = 0
            return
        }
        guard timer == nil else { return }
        timer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                self?.step += 1
            }
        }
    }
}
