import Foundation

protocol SamsungLANDriving: Sendable {
    func deviceInfo(host: String) async throws -> SamsungDeviceInfo
    func wake(mac: String) async throws
}

actor SamsungLANClient: SamsungLANDriving {

    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 3
        session = URLSession(configuration: configuration)
    }

    func deviceInfo(host: String) async throws -> SamsungDeviceInfo {
        guard let url = SamsungDeviceInfo.url(host: host) else { throw URLError(.badURL) }
        let (data, _) = try await session.data(from: url)
        return try SamsungDeviceInfo.decode(data)
    }

    func wake(mac: String) async throws {
        try WakeOnLAN.send(mac: mac)
    }
}
