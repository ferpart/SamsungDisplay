import ApplicationServices
import Observation

@MainActor
@Observable
final class MediaKeyPermission {
    private(set) var isInputMonitoringGranted = false
    private(set) var isAccessibilityGranted = false

    var isGranted: Bool { isInputMonitoringGranted || isAccessibilityGranted }

    init() {
        refresh()
    }

    func refresh() {
        let inputMonitoring = CGPreflightListenEventAccess()
        if inputMonitoring != isInputMonitoringGranted { isInputMonitoringGranted = inputMonitoring }
        let accessibility = AXIsProcessTrusted()
        if accessibility != isAccessibilityGranted { isAccessibilityGranted = accessibility }
    }

    func request() {
        CGRequestListenEventAccess()
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        refresh()
    }
}
