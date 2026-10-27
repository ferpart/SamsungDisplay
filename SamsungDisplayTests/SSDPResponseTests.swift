import Network
import XCTest
@testable import SamsungDisplay

final class SSDPResponseTests: XCTestCase {

    private let samsungReply = """
    HTTP/1.1 200 OK\r
    CACHE-CONTROL: max-age=1800\r
    DATE: Mon, 26 Oct 2026 22:00:00 GMT\r
    EXT:\r
    LOCATION: http://192.0.2.52:7678/nservice/\r
    SERVER: SHP, UPnP/1.0, Samsung UPnP SDK/1.0\r
    ST: urn:dial-multiscreen-org:service:dial:1\r
    USN: uuid:00000000-0000-4000-8000-000000000001::urn:dial-multiscreen-org:service:dial:1\r
    \r

    """

    func test_parse_samsungReply_readsLocationHostAndTarget() throws {
        let response = try XCTUnwrap(SSDPResponse(samsungReply))
        XCTAssertEqual(response.location, URL(string: "http://192.0.2.52:7678/nservice/"))
        XCTAssertEqual(response.host, "192.0.2.52")
        XCTAssertEqual(response.searchTarget, "urn:dial-multiscreen-org:service:dial:1")
        XCTAssertEqual(response.headers["EXT"], "")
    }

    func test_parse_headerNamesAreCaseInsensitive() throws {
        let response = try XCTUnwrap(SSDPResponse("HTTP/1.1 200 OK\r\nLocation: http://10.0.0.2:9197/dmr\r\nst: x\r\n\r\n"))
        XCTAssertEqual(response.host, "10.0.0.2")
        XCTAssertEqual(response.searchTarget, "x")
    }

    func test_parse_notify_usesNTAsTarget() throws {
        let response = try XCTUnwrap(SSDPResponse("NOTIFY * HTTP/1.1\r\nNT: urn:samsung.com:device:RemoteControlReceiver:1\r\n\r\n"))
        XCTAssertEqual(response.searchTarget, "urn:samsung.com:device:RemoteControlReceiver:1")
    }

    func test_parse_rejectsMSearchAndGarbage() {
        XCTAssertNil(SSDPResponse(SSDPResponse.searchRequest(target: "ssdp:all")))
        XCTAssertNil(SSDPResponse(""))
        XCTAssertNil(SSDPResponse("HTTP/1.1 404 Not Found\r\n\r\n"))
    }

    func test_searchRequest_hasRequiredHeaders() {
        let request = SSDPResponse.searchRequest(target: "urn:samsung.com:device:RemoteControlReceiver:1")
        XCTAssertTrue(request.hasPrefix("M-SEARCH * HTTP/1.1\r\n"))
        XCTAssertTrue(request.contains("HOST: 239.255.255.250:1900\r\n"))
        XCTAssertTrue(request.contains("MAN: \"ssdp:discover\"\r\n"))
        XCTAssertTrue(request.contains("ST: urn:samsung.com:device:RemoteControlReceiver:1\r\n"))
        XCTAssertTrue(request.hasSuffix("\r\n\r\n"))
    }

    private func sender(_ ip: String) -> NWEndpoint {
        .hostPort(host: .ipv4(IPv4Address(ip)!), port: 1900)
    }

    func test_trustedHost_acceptsPrivateSenderThatMatchesLocation() throws {
        let response = try XCTUnwrap(SSDPResponse("HTTP/1.1 200 OK\r\nLOCATION: http://10.0.0.2:9197/dmr\r\n\r\n"))
        XCTAssertEqual(MonitorDiscovery.trustedHost(of: response, sender: sender("10.0.0.2")), "10.0.0.2")
    }

    func test_trustedHost_rejectsLocationThatPointsAtAnotherHost() throws {
        let response = try XCTUnwrap(SSDPResponse("HTTP/1.1 200 OK\r\nLOCATION: http://10.0.0.9:9197/dmr\r\n\r\n"))
        XCTAssertNil(MonitorDiscovery.trustedHost(of: response, sender: sender("10.0.0.2")))
    }

    func test_trustedHost_rejectsPublicAndLoopbackSenders() throws {
        for ip in ["8.8.8.8", "127.0.0.1"] {
            let response = try XCTUnwrap(SSDPResponse("HTTP/1.1 200 OK\r\nLOCATION: http://\(ip):9197/dmr\r\n\r\n"))
            XCTAssertNil(MonitorDiscovery.trustedHost(of: response, sender: sender(ip)), ip)
        }
    }

    func test_deviceInfo_decodesG95SCReply() throws {
        let json = """
        {"device":{"PowerState":"standby","ip":"192.0.2.52","modelName":"LS49CG950SLXZX","name":"OLED G9",
        "wifiMac":"02:00:00:00:00:01","firmwareVersion":"Unknown"},"name":"OLED G9","type":"Samsung SmartTV"}
        """
        let info = try SamsungDeviceInfo.decode(Data(json.utf8))
        XCTAssertEqual(info, SamsungDeviceInfo(ip: "192.0.2.52", name: "OLED G9", modelName: "LS49CG950SLXZX",
                                               wifiMac: "02:00:00:00:00:01", powerState: "standby"))
    }
}
