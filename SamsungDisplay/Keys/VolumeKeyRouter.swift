import AppKit

@MainActor
final class VolumeKeyRouter {
    let permission = MediaKeyPermission()
    private let controller: ConnectionController
    private let preferences: AppPreferences
    private let output = DefaultOutputObserver()
    private let osd = VolumeOSD()
    private var muted = false
    private var osdGeneration = 0
    private var shownOSDGeneration = 0
    private static let refreshTimeout: Duration = .seconds(1)
    private lazy var tap = MediaKeyTap(permission: permission) { [weak self] event in
        self?.route(event) ?? false
    }

    init(controller: ConnectionController, preferences: AppPreferences = .shared) {
        self.controller = controller
        self.preferences = preferences
    }

    func start() {
        output.start()
        tap.start()
    }

    private func route(_ event: MediaKeyEvent) -> Bool {
        guard VolumeKeyGate.isOpen(
            output: output.current,
            isConnected: controller.state == .connected,
            displayNames: NSScreen.screens.map(\.localizedName),
            preferredOutputName: preferences.audioOutputName
        ) else { return false }
        guard event.sendsKey else { return true }

        muted = event.key == .mute ? !muted : false
        showOSDWhenSettled(after: event.key)
        return true
    }

    private func showOSDWhenSettled(after key: SamsungCommand.Key) {
        osdGeneration += 1
        let generation = osdGeneration
        Task { [weak self] in
            await self?.controller.sendAndRefresh(key)
            self?.showOSD(generation: generation)
        }
        Task { [weak self] in
            try? await Task.sleep(for: Self.refreshTimeout)
            self?.showOSD(generation: generation)
        }
    }

    private func showOSD(generation: Int) {
        guard shownOSDGeneration != generation else { return }
        shownOSDGeneration = generation
        let content = OSDContent.choose(volume: controller.volume, isMuted: controller.isMuted, localMuted: muted)
        osd.show(level: content.level, muted: content.muted, on: monitorScreen)
    }

    private var monitorScreen: NSScreen? {
        guard let name = output.current?.name else { return nil }
        return NSScreen.screens.first { $0.localizedName.caseInsensitiveCompare(name) == .orderedSame }
    }
}
