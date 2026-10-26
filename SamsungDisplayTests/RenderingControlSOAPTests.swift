import XCTest
@testable import SamsungDisplay

final class RenderingControlSOAPTests: XCTestCase {

    private let controlURL = URL(string: "http://192.0.2.52:9197/upnp/control/RenderingControl1")!

    func test_request_setVolume_hasSOAPHeadersAndBody() throws {
        let request = RenderingControlSOAP.request(action: "SetVolume",
                                                   arguments: [("DesiredVolume", "35")],
                                                   controlURL: controlURL)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url, controlURL)
        XCTAssertEqual(request.value(forHTTPHeaderField: "SOAPACTION"),
                       "\"urn:schemas-upnp-org:service:RenderingControl:1#SetVolume\"")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "text/xml; charset=\"utf-8\"")

        let body = String(decoding: try XCTUnwrap(request.httpBody), as: UTF8.self)
        XCTAssertTrue(body.contains(
            "<u:SetVolume xmlns:u=\"urn:schemas-upnp-org:service:RenderingControl:1\">"
            + "<InstanceID>0</InstanceID><Channel>Master</Channel><DesiredVolume>35</DesiredVolume></u:SetVolume>"
        ))
    }

    func test_request_getMute_hasOnlyDefaultArguments() throws {
        let request = RenderingControlSOAP.request(action: "GetMute", controlURL: controlURL)
        let body = String(decoding: try XCTUnwrap(request.httpBody), as: UTF8.self)
        XCTAssertTrue(body.contains("<InstanceID>0</InstanceID><Channel>Master</Channel></u:GetMute>"))
    }

    func test_volume_parsesGetVolumeResponse() {
        let xml = """
        <?xml version="1.0"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body>\
        <u:GetVolumeResponse xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">\
        <CurrentVolume>17</CurrentVolume></u:GetVolumeResponse></s:Body></s:Envelope>
        """
        XCTAssertEqual(RenderingControlSOAP.volume(fromResponse: xml), 17)
    }

    func test_isMuted_parsesGetMuteResponse() {
        XCTAssertEqual(RenderingControlSOAP.isMuted(fromResponse: "<CurrentMute>1</CurrentMute>"), true)
        XCTAssertEqual(RenderingControlSOAP.isMuted(fromResponse: "<CurrentMute>0</CurrentMute>"), false)
        XCTAssertNil(RenderingControlSOAP.isMuted(fromResponse: "<s:Fault/>"))
    }

    func test_volume_faultReturnsNil() {
        let fault = "<s:Fault><faultstring>UPnPError</faultstring><errorCode>402</errorCode></s:Fault>"
        XCTAssertNil(RenderingControlSOAP.volume(fromResponse: fault))
    }

    func test_controlURL_findsRenderingControlInDescription() {
        let description = """
        <root><device><serviceList>
        <service><serviceType>urn:schemas-upnp-org:service:ConnectionManager:1</serviceType>\
        <controlURL>/upnp/control/ConnectionManager1</controlURL></service>
        <service><serviceType>urn:schemas-upnp-org:service:RenderingControl:1</serviceType>\
        <serviceId>urn:upnp-org:serviceId:RenderingControl</serviceId>\
        <controlURL>/upnp/control/RenderingControl1</controlURL></service>
        </serviceList></device></root>
        """
        let url = RenderingControlSOAP.controlURL(inDescription: description,
                                                  relativeTo: RenderingControlSOAP.descriptionURL(host: "192.0.2.52"))
        XCTAssertEqual(url, controlURL)
    }

    func test_controlURL_nilWithoutRenderingControl() {
        XCTAssertNil(RenderingControlSOAP.controlURL(inDescription: "<root/>",
                                                     relativeTo: RenderingControlSOAP.descriptionURL(host: "h")))
    }
}
