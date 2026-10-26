struct SliderThrottle {
    let interval: Duration
    private var lastSent: ContinuousClock.Instant?
    private var pending: Int?

    init(interval: Duration = .milliseconds(120)) {
        self.interval = interval
    }

    mutating func submit(_ level: Int, at now: ContinuousClock.Instant) -> Int? {
        if let lastSent, now - lastSent < interval {
            pending = level
            return nil
        }
        lastSent = now
        pending = nil
        return level
    }

    mutating func flush(at now: ContinuousClock.Instant) -> Int? {
        defer { pending = nil }
        if pending != nil { lastSent = now }
        return pending
    }
}
