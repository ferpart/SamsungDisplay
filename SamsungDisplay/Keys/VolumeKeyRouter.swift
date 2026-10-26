import AppKit

@MainActor
final class VolumeKeyRouter {
    let permission = MediaKeyPermission()
    private let controller: ConnectionController
    private let preferences: AppPreferences
    private let output = DefaultOutputObserver()
    private let osd = VolumeOSD()
    private var muted = false
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

        controller.send(event.key)
        muted = event.key == .mute ? !muted : false
        osd.show(level: nil, muted: muted, on: monitorScreen)
        return true
    }

    private var monitorScreen: NSScreen? {
        guard let name = output.current?.name else { return nil }
        return NSScreen.screens.first { $0.localizedName.caseInsensitiveCompare(name) == .orderedSame }
    }
}
