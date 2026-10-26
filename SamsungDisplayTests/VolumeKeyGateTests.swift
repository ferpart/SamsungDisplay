@testable import SamsungDisplay
import CoreAudio
import XCTest

final class VolumeKeyGateTests: XCTestCase {

    private let monitorOverDisplayPort = AudioOutputDevice(name: "Odyssey G95SC", transportType: kAudioDeviceTransportTypeDisplayPort)

    private func isOpen(
        _ output: AudioOutputDevice?,
        connected: Bool = true,
        displays: [String] = ["Built-in Retina Display", "Odyssey G95SC"],
        preferred: String? = nil
    ) -> Bool {
        VolumeKeyGate.isOpen(output: output, isConnected: connected, displayNames: displays, preferredOutputName: preferred)
    }

    func test_opensForMonitorOverDisplayPort() {
        XCTAssertTrue(isOpen(monitorOverDisplayPort))
    }

    func test_opensForMonitorOverHDMI_caseInsensitive() {
        XCTAssertTrue(isOpen(AudioOutputDevice(name: "odyssey g95sc", transportType: kAudioDeviceTransportTypeHDMI)))
    }

    func test_closedWhenNotConnected() {
        XCTAssertFalse(isOpen(monitorOverDisplayPort, connected: false))
    }

    func test_closedWithoutOutput() {
        XCTAssertFalse(isOpen(nil))
    }

    func test_closedForBuiltInSpeakers() {
        XCTAssertFalse(isOpen(AudioOutputDevice(name: "MacBook Pro Speakers", transportType: kAudioDeviceTransportTypeBuiltIn)))
    }

    func test_closedForMatchingNameOverUSB() {
        XCTAssertFalse(isOpen(AudioOutputDevice(name: "Odyssey G95SC", transportType: kAudioDeviceTransportTypeUSB)))
    }

    func test_closedForOtherDisplayAudio() {
        XCTAssertFalse(isOpen(AudioOutputDevice(name: "LG UltraFine", transportType: kAudioDeviceTransportTypeHDMI)))
    }

    func test_opensForPreferredNameWithoutDisplayMatch() {
        let output = AudioOutputDevice(name: "SAMSUNG", transportType: kAudioDeviceTransportTypeHDMI)
        XCTAssertFalse(isOpen(output))
        XCTAssertTrue(isOpen(output, preferred: "SAMSUNG"))
    }
}
