import Foundation

/// 5-state lifecycle for the Samsung WebSocket connection.
///
/// Single source of truth for the menu bar icon (CONN-05) and popover status.
/// Owned by `ConnectionController` (`@MainActor @Observable`).
enum ConnectionState: Sendable, Equatable {
    /// No monitor IP configured. Popover prompts user to open Settings.
    case noIP
    /// Idle — not actively trying to connect.
    case disconnected
    /// Actively opening a WebSocket OR in a backoff sleep. UI shows pulse.
    case connecting
    /// `ms.channel.connect` received; keypresses are live.
    case connected
    /// `ms.channel.unauthorized` received. Loop is stopped; user must wipe token.
    case unauthorized
    case certificateMismatch
}

extension ConnectionState {
    func menuBarImage(animationStep: Int) -> String {
        switch self {
        case .connected: "MenuBarBars3"
        case .connecting: "MenuBarBars\(animationStep % 4)"
        case .disconnected, .noIP, .unauthorized, .certificateMismatch: "MenuBarBars0"
        }
    }
}
