import Foundation

enum SamsungLANError: Error, Sendable {
    case noRenderingControl
    case badResponse
}

protocol SamsungLANDriving: Sendable {
    func deviceInfo(host: String) async throws -> SamsungDeviceInfo
    func volume(host: String) async throws -> Int
    func isMuted(host: String) async throws -> Bool
    func setVolume(_ level: Int, host: String) async throws
    func wake(mac: String) async throws
}

actor SamsungLANClient: SamsungLANDriving {

    private let session: URLSession
    private var renderingControlURLs: [String: URL] = [:]

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 3
        session = URLSession(configuration: configuration)
    }

    func deviceInfo(host: String) async throws -> SamsungDeviceInfo {
        let (data, _) = try await session.data(from: SamsungDeviceInfo.url(host: host))
        return try SamsungDeviceInfo.decode(data)
    }

    func volume(host: String) async throws -> Int {
        let xml = try await call("GetVolume", host: host)
        guard let volume = RenderingControlSOAP.volume(fromResponse: xml) else { throw SamsungLANError.badResponse }
        return volume
    }

    func isMuted(host: String) async throws -> Bool {
        let xml = try await call("GetMute", host: host)
        guard let muted = RenderingControlSOAP.isMuted(fromResponse: xml) else { throw SamsungLANError.badResponse }
        return muted
    }

    func setVolume(_ level: Int, host: String) async throws {
        _ = try await call("SetVolume", arguments: [("DesiredVolume", String(level))], host: host)
    }

    func wake(mac: String) async throws {
        try WakeOnLAN.send(mac: mac)
    }

    private func call(_ action: String,
                      arguments: [(name: String, value: String)] = [],
                      host: String) async throws -> String {
        let controlURL = try await renderingControlURL(host: host)
        let request = RenderingControlSOAP.request(action: action, arguments: arguments, controlURL: controlURL)
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw SamsungLANError.badResponse }
        return String(decoding: data, as: UTF8.self)
    }

    private func renderingControlURL(host: String) async throws -> URL {
        if let cached = renderingControlURLs[host] { return cached }
        let descriptionURL = RenderingControlSOAP.descriptionURL(host: host)
        let (data, _) = try await session.data(from: descriptionURL)
        guard let url = RenderingControlSOAP.controlURL(inDescription: String(decoding: data, as: UTF8.self),
                                                        relativeTo: descriptionURL)
        else { throw SamsungLANError.noRenderingControl }
        renderingControlURLs[host] = url
        return url
    }
}
