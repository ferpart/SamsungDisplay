import Foundation

/// Exponential-backoff schedule for the reconnect lifecycle.
///
/// Pure value-type math; no clock, no Task, no side effects — fully
/// unit-testable without async machinery (`02-VALIDATION.md`
/// ReconnectPolicyTests).
///
/// Default policy: `1, 2, 4, 8, 16, 30, 30, 30…` cap at 30s. No jitter —
/// there is exactly one client per Samsung monitor on a LAN; thundering-herd
/// is not a concern here (02-RESEARCH.md Pattern 3 note).
struct ReconnectPolicy: Sendable, Equatable {
    let initial: Duration
    let cap: Duration
    let multiplier: Int

    static let `default` = ReconnectPolicy(
        initial: .seconds(1),
        cap: .seconds(30),
        multiplier: 2
    )

    /// Returns the next backoff duration given the previous one.
    /// - Parameter current: The duration most recently slept. `nil` means
    ///   "first retry" and yields `initial`.
    /// - Returns: A duration ≤ `cap`.
    func nextDelay(after current: Duration?) -> Duration {
        guard let current else { return initial }
        let doubled = current * multiplier
        return doubled > cap ? cap : doubled
    }
}
