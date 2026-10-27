import Foundation
import Network

/// Build the WebSocket URL Samsung Tizen expects for the remote-control channel.
///
/// Structure:
///     wss://<host>:8002/api/v2/channels/samsung.remote.control?name=<base64(appName)>
/// then, on wss only, if a paired token is available:
///     &token=<token>
///
/// The `name` query value must be the base64 encoding of the UTF-8 bytes of the
/// caller-facing app name. On first connection this name is what shows up in
/// the monitor's "Allow connection?" prompt; on subsequent connections it
/// identifies the app for token reuse.
///
/// Reference: phase 01 RESEARCH.md → "Code Examples > Build the WebSocket URL".
/// Pitfall #6: base64 must be unpadded-trim-free — use the exact output of
/// `Data(_:).base64EncodedString()` (padding included). The Samsung server
/// accepts the standard `=`-padded form.
func samsungWebSocketURL(host: String, appName: String, token: String?, port: Int = 8002) -> URL? {
    var components = URLComponents()
    components.scheme = port == 8001 ? "ws" : "wss"
    components.host = host
    components.port = port
    components.path = "/api/v2/channels/samsung.remote.control"

    let encodedName = Data(appName.utf8).base64EncodedString()
    var queryItems: [URLQueryItem] = [URLQueryItem(name: "name", value: encodedName)]
    if let token, !token.isEmpty, components.scheme == "wss" {
        queryItems.append(URLQueryItem(name: "token", value: token))
    }
    components.queryItems = queryItems

    return components.url
}

func isIPv4Address(_ text: String) -> Bool {
    IPv4Address(text).map(String.init(describing:)) == text
}

let samsungRemotePorts = [8002, 8001]

func firstSuccessfulPort<Result>(
    _ ports: [Int],
    isolation: isolated (any Actor)? = #isolation,
    attempt: (Int) async throws -> Result
) async throws -> Result {
    var lastError: any Error = SamsungWSError.notConnected
    for port in ports {
        do {
            return try await attempt(port)
        } catch let error as SamsungWSError where error == .unauthorized || error == .certificateMismatch {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            lastError = error
        }
    }
    throw lastError
}
