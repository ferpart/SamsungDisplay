import Foundation

/// Parsed form of a Samsung Tizen channel event frame.
///
/// The two events we actually care about during pairing/connect:
///
/// * `ms.channel.connect` — sent immediately after a successful WebSocket
///   handshake. On FIRST pairing the monitor includes a long-lived `token`
///   inside `data.token`; on subsequent reconnects the token is echoed back.
///   The `data.clients` array lists who else is connected.
///
/// * `ms.channel.unauthorized` — sent when pairing was denied (user rejected
///   the on-screen "Allow connection?" prompt) or when a presented token has
///   been revoked. `data` is effectively empty.
///
/// Other events (`ms.channel.timeOut`, etc.) decode into the same shape but
/// with neither `token` nor `clients`; callers that only want a token should
/// use the static `extractToken(from:)` helper, which is forgiving on parse
/// failure (returns `nil` instead of throwing) so the receive loop can keep
/// reading frames.
///
/// Reference: phase 01 RESEARCH.md → "Code Examples > Parse ms.channel.connect
/// → Extract Token", which mirrors samsung-tv-ws-api's event.py.
struct SamsungAuthResponse: Decodable, Sendable {

    let event: String
    let data: Payload

    struct Payload: Decodable, Sendable {
        let token: String?
        let clients: [Client]?
    }

    struct Client: Decodable, Sendable {
        let id: String
        /// Optional: missing on some frames (e.g. read-only listeners).
        let isHost: Bool?
    }

    /// Parse a raw text frame and return the embedded pairing token, if any.
    ///
    /// Returns `nil` for ANY of:
    /// - malformed / non-JSON input
    /// - JSON that decodes but is missing the `data.token` field (e.g.
    ///   `ms.channel.unauthorized`, or a `connect` frame on a denied pairing)
    /// - empty input
    ///
    /// Never throws — the WebSocket receive loop in Plan 06 calls this on
    /// every incoming frame and must not abort when a non-auth frame arrives.
    static func extractToken(from text: String) -> String? {
        guard !text.isEmpty,
              let data = text.data(using: .utf8),
              let response = try? JSONDecoder().decode(SamsungAuthResponse.self, from: data)
        else {
            return nil
        }
        return response.data.token
    }
}
