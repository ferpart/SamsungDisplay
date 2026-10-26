import CoreAudio

struct AudioOutputDevice: Equatable, Sendable {
    let name: String
    let transportType: UInt32
}

enum VolumeKeyGate {
    static func isOpen(
        output: AudioOutputDevice?,
        isConnected: Bool,
        displayNames: [String],
        preferredOutputName: String?
    ) -> Bool {
        guard isConnected, let output else { return false }
        guard output.transportType == kAudioDeviceTransportTypeHDMI
            || output.transportType == kAudioDeviceTransportTypeDisplayPort else { return false }
        let candidates = displayNames + [preferredOutputName].compactMap { $0 }
        return candidates.contains { $0.caseInsensitiveCompare(output.name) == .orderedSame }
    }
}
