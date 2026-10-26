import XCTest
@testable import SamsungDisplay

final class WakeOnLANTests: XCTestCase {

    func test_magicPacket_isSixFFThenMACSixteenTimes() throws {
        let packet = try XCTUnwrap(WakeOnLAN.magicPacket(mac: "02:00:00:00:00:01"))
        let mac: [UInt8] = [0x04, 0xE4, 0xB6, 0x15, 0x4C, 0xD6]
        XCTAssertEqual(packet.count, 102)
        XCTAssertEqual(Array(packet.prefix(6)), Array(repeating: 0xFF, count: 6))
        for repetition in 0..<16 {
            let start = 6 + repetition * 6
            XCTAssertEqual(Array(packet[start..<start + 6]), mac)
        }
    }

    func test_magicPacket_acceptsDashesAndLowercase() {
        XCTAssertEqual(WakeOnLAN.magicPacket(mac: "04-e4-b6-15-4c-d6"), WakeOnLAN.magicPacket(mac: "02:00:00:00:00:01"))
    }

    func test_magicPacket_rejectsInvalidMAC() {
        XCTAssertNil(WakeOnLAN.magicPacket(mac: "04:E4:B6:15:4C"))
        XCTAssertNil(WakeOnLAN.magicPacket(mac: "zz:E4:B6:15:4C:D6"))
        XCTAssertNil(WakeOnLAN.magicPacket(mac: ""))
    }
}
