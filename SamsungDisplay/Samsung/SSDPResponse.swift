import Foundation

struct SSDPResponse: Sendable, Equatable {
    static let multicastHost = "239.255.255.250"
    static let multicastPort: UInt16 = 1900

    static let samsungSearchTargets = [
        "urn:samsung.com:device:RemoteControlReceiver:1",
        "urn:dial-multiscreen-org:service:dial:1",
    ]

    let headers: [String: String]

    init?(_ text: String) {
        let lines = text.components(separatedBy: "\r\n")
        guard let statusLine = lines.first,
              statusLine.hasPrefix("HTTP/1.1 200") || statusLine.hasPrefix("NOTIFY")
        else { return nil }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces).uppercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[name] = value
        }
        self.headers = headers
    }

    var location: URL? { headers["LOCATION"].flatMap(URL.init(string:)) }
    var searchTarget: String? { headers["ST"] ?? headers["NT"] }
    var host: String? { location?.host }

    static func searchRequest(target: String, maxWaitSeconds: Int = 2) -> String {
        "M-SEARCH * HTTP/1.1\r\n"
            + "HOST: \(multicastHost):\(multicastPort)\r\n"
            + "MAN: \"ssdp:discover\"\r\n"
            + "MX: \(maxWaitSeconds)\r\n"
            + "ST: \(target)\r\n\r\n"
    }
}
