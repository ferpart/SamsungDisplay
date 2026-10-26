import Foundation

enum RenderingControlSOAP {
    static let serviceType = "urn:schemas-upnp-org:service:RenderingControl:1"

    static func descriptionURL(host: String) -> URL {
        URL(string: "http://\(host):9197/dmr")!
    }

    static func request(action: String,
                        arguments: [(name: String, value: String)] = [],
                        controlURL: URL) -> URLRequest {
        let allArguments = [("InstanceID", "0"), ("Channel", "Master")] + arguments.map { ($0.name, $0.value) }
        let argumentXML = allArguments.map { "<\($0.0)>\($0.1)</\($0.0)>" }.joined()
        let body = """
        <?xml version="1.0" encoding="utf-8"?>\
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" \
        s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">\
        <s:Body><u:\(action) xmlns:u="\(serviceType)">\(argumentXML)</u:\(action)></s:Body>\
        </s:Envelope>
        """

        var request = URLRequest(url: controlURL)
        request.httpMethod = "POST"
        request.setValue("text/xml; charset=\"utf-8\"", forHTTPHeaderField: "Content-Type")
        request.setValue("\"\(serviceType)#\(action)\"", forHTTPHeaderField: "SOAPACTION")
        request.httpBody = Data(body.utf8)
        return request
    }

    static func elementValue(_ name: String, in xml: String) -> String? {
        guard let regex = try? Regex("<(?:[A-Za-z0-9_]+:)?\(name)>([^<]*)</"),
              let match = xml.firstMatch(of: regex),
              let value = match.output[1].substring
        else { return nil }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func controlURL(inDescription xml: String, relativeTo base: URL) -> URL? {
        guard let service = xml.range(of: serviceType),
              let path = elementValue("controlURL", in: String(xml[service.upperBound...]))
        else { return nil }
        return URL(string: path, relativeTo: base)?.absoluteURL
    }

    static func volume(fromResponse xml: String) -> Int? {
        elementValue("CurrentVolume", in: xml).flatMap(Int.init)
    }

    static func isMuted(fromResponse xml: String) -> Bool? {
        switch elementValue("CurrentMute", in: xml) {
        case "1", "true": true
        case "0", "false": false
        default: nil
        }
    }
}
