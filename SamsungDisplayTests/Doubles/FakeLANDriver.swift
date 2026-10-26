@testable import SamsungDisplay
import Foundation
import os

final class FakeLANDriver: SamsungLANDriving, @unchecked Sendable {

    private struct State {
        var info = SamsungDeviceInfo(ip: "192.168.1.10", name: "OLED G9", modelName: "LS49CG950SLXZX",
                                     wifiMac: "02:00:00:00:00:01", powerState: "on")
        var volume: Int? = 20
        var isMuted = false
        var volumeReads = 0
        var setVolumeCalls: [Int] = []
        var wakeCalls: [String] = []
    }

    private let state = OSAllocatedUnfairLock<State>(initialState: State())

    var volumeLevel: Int? {
        get { state.withLock { $0.volume } }
        set { state.withLock { $0.volume = newValue } }
    }
    var volumeReads: Int { state.withLock { $0.volumeReads } }
    var setVolumeCalls: [Int] { state.withLock { $0.setVolumeCalls } }
    var wakeCalls: [String] { state.withLock { $0.wakeCalls } }

    func deviceInfo(host: String) async throws -> SamsungDeviceInfo {
        state.withLock { $0.info }
    }

    func volume(host: String) async throws -> Int {
        let volume = state.withLock { s -> Int? in
            s.volumeReads += 1
            return s.volume
        }
        guard let volume else { throw SamsungLANError.noRenderingControl }
        return volume
    }

    func isMuted(host: String) async throws -> Bool {
        state.withLock { $0.isMuted }
    }

    func setVolume(_ level: Int, host: String) async throws {
        state.withLock {
            $0.setVolumeCalls.append(level)
            $0.volume = level
        }
    }

    func wake(mac: String) async throws {
        state.withLock { $0.wakeCalls.append(mac) }
    }
}
