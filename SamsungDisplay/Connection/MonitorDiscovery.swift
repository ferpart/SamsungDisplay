import Foundation
import Network
import Observation
import OSLog

@MainActor
@Observable
final class MonitorDiscovery {

    private(set) var monitors: [SamsungDeviceInfo] = []
    private(set) var isSearching = false

    private let lan: any SamsungLANDriving
    private var hostsSeen: Set<String> = []
    private let logger = Logger(subsystem: "com.fp.SamsungDisplay", category: "discovery")

    init(lan: any SamsungLANDriving = SamsungLANClient()) {
        self.lan = lan
    }

    func search(for duration: Duration = .seconds(4)) async {
        guard !isSearching else { return }
        isSearching = true
        hostsSeen = []
        defer { isSearching = false }

        let group: NWConnectionGroup
        do {
            let endpoint = NWEndpoint.hostPort(host: .init(SSDPResponse.multicastHost),
                                               port: .init(rawValue: SSDPResponse.multicastPort)!)
            let parameters = NWParameters.udp
            parameters.allowLocalEndpointReuse = true
            group = NWConnectionGroup(with: try NWMulticastGroup(for: [endpoint]), using: parameters)
        } catch {
            logger.error("multicast group failed: \(String(describing: error), privacy: .public)")
            return
        }

        group.setReceiveHandler(maximumMessageSize: 65_535, rejectOversizedMessages: true) { [weak self] _, content, _ in
            guard let content, let response = SSDPResponse(String(decoding: content, as: UTF8.self)) else { return }
            Task { @MainActor [weak self] in await self?.handle(response) }
        }
        group.stateUpdateHandler = { [logger] state in
            guard case .ready = state else {
                logger.info("ssdp group state: \(String(describing: state), privacy: .public)")
                return
            }
            for target in SSDPResponse.samsungSearchTargets {
                group.send(content: Data(SSDPResponse.searchRequest(target: target).utf8)) { error in
                    if let error { logger.error("m-search failed: \(String(describing: error), privacy: .public)") }
                }
            }
        }
        group.start(queue: .global(qos: .utility))

        try? await Task.sleep(for: duration)
        group.cancel()
    }

    private func handle(_ response: SSDPResponse) async {
        guard let target = response.searchTarget,
              SSDPResponse.samsungSearchTargets.contains(target),
              let host = response.host,
              hostsSeen.insert(host).inserted
        else { return }

        do {
            let info = try await lan.deviceInfo(host: host)
            monitors.removeAll { $0.wifiMac == info.wifiMac }
            monitors.append(info)
        } catch {
            hostsSeen.remove(host)
            logger.notice("no Tizen info at \(host, privacy: .public): \(String(describing: error), privacy: .public)")
        }
    }
}
