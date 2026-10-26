import Foundation

struct SamsungDeviceInfo: Decodable, Sendable, Equatable {
    let ip: String
    let name: String
    let modelName: String
    let wifiMac: String
    let powerState: String?

    private enum CodingKeys: String, CodingKey {
        case ip, name, modelName, wifiMac
        case powerState = "PowerState"
    }

    private struct Envelope: Decodable {
        let device: SamsungDeviceInfo
    }

    static func url(host: String) -> URL {
        URL(string: "http://\(host):8001/api/v2/")!
    }

    static func decode(_ data: Data) throws -> SamsungDeviceInfo {
        try JSONDecoder().decode(Envelope.self, from: data).device
    }
}
