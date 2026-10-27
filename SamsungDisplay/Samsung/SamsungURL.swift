import Foundation
import Network

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
