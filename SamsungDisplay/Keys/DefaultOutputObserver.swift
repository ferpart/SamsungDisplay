import CoreAudio
import Foundation

@MainActor
final class DefaultOutputObserver {
    private(set) var current: AudioOutputDevice?

    private var defaultOutputAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    func start() {
        current = Self.readDefaultOutput()
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &defaultOutputAddress, .main
        ) { [weak self] _, _ in
            MainActor.assumeIsolated {
                self?.current = Self.readDefaultOutput()
            }
        }
    }

    private static func readDefaultOutput() -> AudioOutputDevice? {
        var deviceID = AudioObjectID(kAudioObjectUnknown)
        guard read(kAudioHardwarePropertyDefaultOutputDevice, of: AudioObjectID(kAudioObjectSystemObject), into: &deviceID),
              deviceID != kAudioObjectUnknown else { return nil }

        var transportType: UInt32 = 0
        var name: Unmanaged<CFString>?
        guard read(kAudioDevicePropertyTransportType, of: deviceID, into: &transportType),
              read(kAudioObjectPropertyName, of: deviceID, into: &name),
              let name else { return nil }
        return AudioOutputDevice(name: name.takeRetainedValue() as String, transportType: transportType)
    }

    private static func read<Value>(_ selector: AudioObjectPropertySelector, of object: AudioObjectID, into value: inout Value) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<Value>.size)
        return withUnsafeMutableBytes(of: &value) { buffer in
            AudioObjectGetPropertyData(object, &address, 0, nil, &size, buffer.baseAddress!) == noErr
        }
    }
}
