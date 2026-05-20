import XCTest
@testable import SamsungDisplay

final class SamsungCommandTests: XCTestCase {

    // MARK: - Key raw values

    func test_keyRawValues_matchSamsungTizenStrings() {
        XCTAssertEqual(SamsungCommand.Key.volUp.rawValue, "KEY_VOLUP")
        XCTAssertEqual(SamsungCommand.Key.volDown.rawValue, "KEY_VOLDOWN")
        XCTAssertEqual(SamsungCommand.Key.mute.rawValue, "KEY_MUTE")
    }

    // MARK: - JSON shape

    /// Decode encoded JSON back into a dictionary so we can assert fields by name
    /// (key ordering in encoded JSON is unspecified, so we never compare raw strings).
    private func encodeAsDictionary(_ command: SamsungCommand) throws -> [String: Any] {
        let data = try JSONEncoder().encode(command)
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = object as? [String: Any] else {
            throw NSError(domain: "test", code: 0, userInfo: [NSLocalizedDescriptionKey: "not a JSON object"])
        }
        return dict
    }

    func test_volUp_serializesToSamsungJSONShape() throws {
        let dict = try encodeAsDictionary(SamsungCommand(key: .volUp))

        XCTAssertEqual(dict["method"] as? String, "ms.remote.control")

        let params = try XCTUnwrap(dict["params"] as? [String: Any], "params object must be present")
        XCTAssertEqual(params["Cmd"] as? String, "Click")
        XCTAssertEqual(params["DataOfCmd"] as? String, "KEY_VOLUP")
        XCTAssertEqual(params["Option"] as? String, "false")
        XCTAssertEqual(params["TypeOfRemote"] as? String, "SendRemoteKey")
        XCTAssertEqual(params.count, 4, "params must have exactly 4 fields, Samsung's parser is strict")
    }

    func test_volDown_carriesCorrectDataOfCmd() throws {
        let dict = try encodeAsDictionary(SamsungCommand(key: .volDown))
        let params = try XCTUnwrap(dict["params"] as? [String: Any])
        XCTAssertEqual(params["DataOfCmd"] as? String, "KEY_VOLDOWN")
    }

    func test_mute_carriesCorrectDataOfCmd() throws {
        let dict = try encodeAsDictionary(SamsungCommand(key: .mute))
        let params = try XCTUnwrap(dict["params"] as? [String: Any])
        XCTAssertEqual(params["DataOfCmd"] as? String, "KEY_MUTE")
    }

    // MARK: - Round-trip

    func test_command_roundTripsThroughJSONCoder() throws {
        let original = SamsungCommand(key: .volUp)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SamsungCommand.self, from: data)

        XCTAssertEqual(decoded.method, original.method)
        XCTAssertEqual(decoded.params.Cmd, original.params.Cmd)
        XCTAssertEqual(decoded.params.DataOfCmd, original.params.DataOfCmd)
        XCTAssertEqual(decoded.params.Option, original.params.Option)
        XCTAssertEqual(decoded.params.TypeOfRemote, original.params.TypeOfRemote)
    }
}
