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
}

extension ConnectionState {
    /// SF Symbol name for the menu bar icon (CONN-05).
    /// - `.connected`, `.connecting` -> `"speaker.wave.2.fill"`
    ///   (the `.connecting` state animates via `.symbolEffect(.pulse)` applied
    ///   at the view layer; the symbol itself is the same).
    /// - `.disconnected`, `.noIP`, `.unauthorized` -> `"speaker.slash.fill"`
    var menuBarSymbol: String {
        switch self {
        case .connected, .connecting: return "speaker.wave.2.fill"
        case .disconnected, .noIP, .unauthorized: return "speaker.slash.fill"
        }
    }
}
