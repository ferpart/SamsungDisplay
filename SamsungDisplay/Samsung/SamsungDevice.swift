import Foundation

/// Value type carrying the minimum identifying information for a paired
/// Samsung monitor: its IP address on the LAN and (optionally) a long-lived
/// pairing token returned by the monitor on first `ms.channel.connect`.
///
/// Plan 06 (validation harness) and later phases construct this from
/// `AppPreferences` + `TokenStore` and feed it into the WebSocket layer.
///
/// The token is mutable so callers can update an in-memory device after the
/// first pairing handshake before persisting it.
struct SamsungDevice: Sendable, Equatable {
    let ip: String
    var token: String?

    init(ip: String, token: String? = nil) {
        self.ip = ip
        self.token = token
    }
}
