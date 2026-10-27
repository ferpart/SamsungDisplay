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
        let url = try XCTUnwrap(samsungWebSocketURL(host: "192.168.1.50", appName: "SamsungDisplay", token: nil))

        XCTAssertEqual(url.scheme, "wss")
        XCTAssertEqual(url.host, "192.168.1.50")
        XCTAssertEqual(url.port, 8002)
        XCTAssertEqual(url.path, "/api/v2/channels/samsung.remote.control")
    }

    func test_url_withoutToken_hasBase64EncodedNameQueryItem() throws {
        let url = try XCTUnwrap(samsungWebSocketURL(host: "192.168.1.50", appName: "SamsungDisplay", token: nil))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = components.queryItems ?? []

        let nameItem = try XCTUnwrap(queryItems.first(where: { $0.name == "name" }))
        let nameValue = try XCTUnwrap(nameItem.value)

        let decoded = try XCTUnwrap(Data(base64Encoded: nameValue))
        let decodedString = try XCTUnwrap(String(data: decoded, encoding: .utf8))
        XCTAssertEqual(decodedString, "SamsungDisplay")
    }

    func test_url_withoutToken_doesNotIncludeTokenQueryItem() throws {
        let url = try XCTUnwrap(samsungWebSocketURL(host: "192.168.1.50", appName: "SamsungDisplay", token: nil))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = components.queryItems ?? []
        XCTAssertNil(queryItems.first(where: { $0.name == "token" }))
    }

    // MARK: - URL structure (with token)

    func test_url_withToken_appendsTokenQueryItem() throws {
        let url = try XCTUnwrap(samsungWebSocketURL(host: "192.168.1.50", appName: "SamsungDisplay", token: "abc123"))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = components.queryItems ?? []

        let tokenItem = try XCTUnwrap(queryItems.first(where: { $0.name == "token" }))
        XCTAssertEqual(tokenItem.value, "abc123")
    }

    func test_url_withToken_tokenAppearsAfterName() throws {
        let url = try XCTUnwrap(samsungWebSocketURL(host: "192.168.1.50", appName: "SamsungDisplay", token: "abc123"))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = components.queryItems ?? []

        let nameIndex = try XCTUnwrap(queryItems.firstIndex(where: { $0.name == "name" }))
        let tokenIndex = try XCTUnwrap(queryItems.firstIndex(where: { $0.name == "token" }))
        XCTAssertLessThan(nameIndex, tokenIndex, "name must come before token in the query string")
    }

    func test_url_withToken_preservesAllOtherComponents() throws {
        let url = try XCTUnwrap(samsungWebSocketURL(host: "192.168.1.50", appName: "SamsungDisplay", token: "abc123"))

        XCTAssertEqual(url.scheme, "wss")
        XCTAssertEqual(url.host, "192.168.1.50")
        XCTAssertEqual(url.port, 8002)
        XCTAssertEqual(url.path, "/api/v2/channels/samsung.remote.control")
    }

    // MARK: - Port fallback

    func test_port8001_usesPlainWebSocket() throws {
        let url = try XCTUnwrap(samsungWebSocketURL(host: "192.168.1.50", appName: "SamsungDisplay", token: nil, port: 8001))
        XCTAssertEqual(url.scheme, "ws")
        XCTAssertEqual(url.port, 8001)
    }

    func test_port8001_neverSendsToken() throws {
        let url = try XCTUnwrap(samsungWebSocketURL(host: "192.168.1.50", appName: "SamsungDisplay", token: "abc123", port: 8001))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertNil(components.queryItems?.first(where: { $0.name == "token" }))
    }

    func test_invalidHost_returnsNil() {
        for host in ["fe80::1", "a b", "%zz"] {
            XCTAssertNil(samsungWebSocketURL(host: host, appName: "SamsungDisplay", token: nil), host)
            XCTAssertNil(SamsungDeviceInfo.url(host: host), host)
        }
    }

    func test_isIPv4Address_acceptsOnlyDottedQuads() {
        XCTAssertTrue(isIPv4Address("192.168.1.50"))
        for text in ["1.2.3", "01.2.3.4", "127.1", " 1.2.3.4", "fe80::1", "a b", "256.1.1.1", ""] {
            XCTAssertFalse(isIPv4Address(text), text)
        }
    }

    func test_fallback_tries8002Then8001() async throws {
        var tried: [Int] = []
        let port = try await firstSuccessfulPort(samsungRemotePorts) { port in
            tried.append(port)
            if port == 8002 { throw URLError(.cannotConnectToHost) }
            return port
        }
        XCTAssertEqual(tried, [8002, 8001])
        XCTAssertEqual(port, 8001)
    }

    func test_fallback_stopsAtFirstSuccess() async throws {
        var tried: [Int] = []
        _ = try await firstSuccessfulPort(samsungRemotePorts) { port in tried.append(port) }
        XCTAssertEqual(tried, [8002])
    }

    func test_fallback_doesNotRetryAfterUnauthorized() async {
        var tried: [Int] = []
        do {
            _ = try await firstSuccessfulPort(samsungRemotePorts) { port in
                tried.append(port)
                throw SamsungWSError.unauthorized
            }
            XCTFail("expected unauthorized")
        } catch {
            XCTAssertEqual(error as? SamsungWSError, .unauthorized)
        }
        XCTAssertEqual(tried, [8002])
    }

    func test_fallback_throwsLastErrorWhenAllPortsFail() async {
        do {
            _ = try await firstSuccessfulPort(samsungRemotePorts) { port -> Int in
                throw URLError(port == 8002 ? .timedOut : .cannotConnectToHost)
            }
            XCTFail("expected failure")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .cannotConnectToHost)
        }
    }
}
