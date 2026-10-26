enum OnboardingStep: Equatable {
    case findMonitor
    case pairing
    case denied
    case keys
    case done

    static func current(
        storedIP: String?,
        state: ConnectionState,
        keysGranted: Bool,
        keysSkipped: Bool
    ) -> OnboardingStep {
        guard let storedIP, !storedIP.isEmpty else { return .findMonitor }
        switch state {
        case .noIP: return .findMonitor
        case .unauthorized: return .denied
        case .connecting, .disconnected: return .pairing
        case .connected: return keysGranted || keysSkipped ? .done : .keys
        }
    }
}
