import XCTest
@testable import SamsungDisplay

final class SamsungURLTests: XCTestCase {

    // MARK: - Known-good base64 fixture (RESEARCH.md Pitfall #6)

    func test_appName_base64Encoding_matchesResearchFixture() {
        // echo -n SamsungDisplay | base64  →  U2Ftc3VuZ0Rpc3BsYXk=
        let encoded = Data("SamsungDisplay".utf8).base64EncodedString()
        XCTAssertEqual(encoded, "U2Ftc3VuZ0Rpc3BsYXk=")
    }

    // MARK: - URL structure (without token)

    func test_url_withoutToken_hasCorrectSchemeHostPortPath() throws {
        let url = samsungWebSocketURL(host: "192.168.1.50", appName: "SamsungDisplay", token: nil)

        XCTAssertEqual(url.scheme, "wss")
        XCTAssertEqual(url.host, "192.168.1.50")
        XCTAssertEqual(url.port, 8002)
        XCTAssertEqual(url.path, "/api/v2/channels/samsung.remote.control")
    }

    func test_url_withoutToken_hasBase64EncodedNameQueryItem() throws {
        let url = samsungWebSocketURL(host: "192.168.1.50", appName: "SamsungDisplay", token: nil)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = components.queryItems ?? []

        let nameItem = try XCTUnwrap(queryItems.first(where: { $0.name == "name" }))
        let nameValue = try XCTUnwrap(nameItem.value)

        let decoded = try XCTUnwrap(Data(base64Encoded: nameValue))
        let decodedString = try XCTUnwrap(String(data: decoded, encoding: .utf8))
        XCTAssertEqual(decodedString, "SamsungDisplay")
    }

    func test_url_withoutToken_doesNotIncludeTokenQueryItem() throws {
        let url = samsungWebSocketURL(host: "192.168.1.50", appName: "SamsungDisplay", token: nil)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = components.queryItems ?? []
        XCTAssertNil(queryItems.first(where: { $0.name == "token" }))
    }

    // MARK: - URL structure (with token)

    func test_url_withToken_appendsTokenQueryItem() throws {
        let url = samsungWebSocketURL(host: "192.168.1.50", appName: "SamsungDisplay", token: "abc123")
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = components.queryItems ?? []

        let tokenItem = try XCTUnwrap(queryItems.first(where: { $0.name == "token" }))
        XCTAssertEqual(tokenItem.value, "abc123")
    }

    func test_url_withToken_tokenAppearsAfterName() throws {
        let url = samsungWebSocketURL(host: "192.168.1.50", appName: "SamsungDisplay", token: "abc123")
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = components.queryItems ?? []

        let nameIndex = try XCTUnwrap(queryItems.firstIndex(where: { $0.name == "name" }))
        let tokenIndex = try XCTUnwrap(queryItems.firstIndex(where: { $0.name == "token" }))
        XCTAssertLessThan(nameIndex, tokenIndex, "name must come before token in the query string")
    }

    func test_url_withToken_preservesAllOtherComponents() throws {
        let url = samsungWebSocketURL(host: "192.168.1.50", appName: "SamsungDisplay", token: "abc123")

        XCTAssertEqual(url.scheme, "wss")
        XCTAssertEqual(url.host, "192.168.1.50")
        XCTAssertEqual(url.port, 8002)
        XCTAssertEqual(url.path, "/api/v2/channels/samsung.remote.control")
    }
}
