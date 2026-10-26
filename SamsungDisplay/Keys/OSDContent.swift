struct OSDContent: Equatable {
    let level: Int?
    let muted: Bool

    static func choose(volume: Int?, isMuted: Bool?, localMuted: Bool) -> OSDContent {
        guard let volume else { return OSDContent(level: nil, muted: localMuted) }
        return OSDContent(level: volume, muted: isMuted ?? localMuted)
    }
}
