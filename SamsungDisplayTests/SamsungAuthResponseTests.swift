import XCTest
@testable import SamsungDisplay

final class SamsungAuthResponseTests: XCTestCase {

    // MARK: - Fixtures (lifted from samsung-tv-ws-api event.py per RESEARCH.md)

    private let connectPayload = """
    {
      "event": "ms.channel.connect",
      "data": {
        "token": "12345678",
        "clients": [
          {"id": "client-uuid", "isHost": false}
        ]
      }
    }
    """

    private let unauthorizedPayload = """
    {"event": "ms.channel.unauthorized", "data": {}}
    """

    private let connectWithoutTokenPayload = """
    {"event": "ms.channel.connect", "data": {"clients": []}}
    """

    private let malformedPayload = """
    { not valid json at all <<<
    """

    // MARK: - Happy path

    func test_extractToken_returnsTokenFromMsChannelConnect() {
        let token = SamsungAuthResponse.extractToken(from: connectPayload)
        XCTAssertEqual(token, "12345678")
    }

    // MARK: - Failure modes — all return nil, never throw

    func test_extractToken_returnsNilForUnauthorizedEvent() {
        let token = SamsungAuthResponse.extractToken(from: unauthorizedPayload)
        XCTAssertNil(token)
    }

    func test_extractToken_returnsNilWhenConnectHasNoTokenField() {
        let token = SamsungAuthResponse.extractToken(from: connectWithoutTokenPayload)
        XCTAssertNil(token)
    }

    func test_extractToken_returnsNilForMalformedJSON() {
        let token = SamsungAuthResponse.extractToken(from: malformedPayload)
        XCTAssertNil(token)
    }

    func test_extractToken_returnsNilForEmptyString() {
        let token = SamsungAuthResponse.extractToken(from: "")
        XCTAssertNil(token)
    }

    // MARK: - Decodable surface

    func test_decoding_connectPayload_parsesClientList() throws {
        let data = Data(connectPayload.utf8)
        let parsed = try JSONDecoder().decode(SamsungAuthResponse.self, from: data)

        XCTAssertEqual(parsed.event, "ms.channel.connect")
        XCTAssertEqual(parsed.data.token, "12345678")
        XCTAssertEqual(parsed.data.clients?.count, 1)
        XCTAssertEqual(parsed.data.clients?.first?.id, "client-uuid")
        XCTAssertEqual(parsed.data.clients?.first?.isHost, false)
    }

    func test_decoding_clientWithoutIsHost_succeeds() throws {
        // Some frames omit isHost — it must be optional.
        let json = """
        {"event":"ms.channel.connect","data":{"clients":[{"id":"x"}]}}
        """
        let parsed = try JSONDecoder().decode(SamsungAuthResponse.self, from: Data(json.utf8))
        XCTAssertEqual(parsed.data.clients?.first?.id, "x")
        XCTAssertNil(parsed.data.clients?.first?.isHost)
    }
}
