@testable import SamsungDisplay
import Foundation
import os

final class FakeLANDriver: SamsungLANDriving, @unchecked Sendable {

    private struct State {
        var info = SamsungDeviceInfo(ip: "192.168.1.10", name: "OLED G9", modelName: "LS49CG950SLXZX",
                                     wifiMac: "02:00:00:00:00:01", powerState: "on")
        var deviceInfoFails = false
        var wakeCalls: [String] = []
    }

    private let state = OSAllocatedUnfairLock<State>(initialState: State())

    var deviceInfoFails: Bool {
        get { state.withLock { $0.deviceInfoFails } }
        set { state.withLock { $0.deviceInfoFails = newValue } }
    }
    var powerState: String? {
        get { state.withLock { $0.info.powerState } }
        set {
            state.withLock {
                let info = $0.info
                $0.info = SamsungDeviceInfo(ip: info.ip, name: info.name, modelName: info.modelName,
                                            wifiMac: info.wifiMac, powerState: newValue)
            }
        }
    }
    var wakeCalls: [String] { state.withLock { $0.wakeCalls } }

    func deviceInfo(host: String) async throws -> SamsungDeviceInfo {
        let (info, fails) = state.withLock { ($0.info, $0.deviceInfoFails) }
        if fails { throw URLError(.timedOut) }
        return info
    }

    func wake(mac: String) async throws {
        state.withLock { $0.wakeCalls.append(mac) }
    }
}
