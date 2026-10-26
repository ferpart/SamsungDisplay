import AppKit

struct MediaKeyEvent: Equatable, Sendable {
    let key: SamsungCommand.Key
    let isDown: Bool
    let isRepeat: Bool

    private static let auxControlButtonsSubtype: Int16 = 8
    private static let keyDownState = 0xA

    var sendsKey: Bool { isDown && !(key == .mute && isRepeat) }

    init(key: SamsungCommand.Key, isDown: Bool, isRepeat: Bool) {
        self.key = key
        self.isDown = isDown
        self.isRepeat = isRepeat
    }

    init?(subtype: Int16, data1: Int) {
        guard subtype == Self.auxControlButtonsSubtype else { return nil }
        let keyType = Int32((data1 & 0xFFFF_0000) >> 16)
        switch keyType {
        case NX_KEYTYPE_SOUND_UP: key = .volUp
        case NX_KEYTYPE_SOUND_DOWN: key = .volDown
        case NX_KEYTYPE_MUTE: key = .mute
        default: return nil
        }
        let flags = data1 & 0xFFFF
        isDown = (flags & 0xFF00) >> 8 == Self.keyDownState
        isRepeat = flags & 0x1 == 1
    }

    init?(_ event: CGEvent) {
        guard let nsEvent = NSEvent(cgEvent: event), nsEvent.type == .systemDefined else { return nil }
        self.init(subtype: nsEvent.subtype.rawValue, data1: nsEvent.data1)
    }
}
