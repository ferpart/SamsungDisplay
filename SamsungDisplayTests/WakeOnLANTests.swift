import XCTest
@testable import SamsungDisplay

final class WakeOnLANTests: XCTestCase {

    func test_magicPacket_isSixFFThenMACSixteenTimes() throws {
        let packet = try XCTUnwrap(WakeOnLAN.magicPacket(mac: "02:00:00:AB:CD:EF"))
        let mac: [UInt8] = [0x02, 0x00, 0x00, 0xAB, 0xCD, 0xEF]
        XCTAssertEqual(packet.count, 102)
        XCTAssertEqual(Array(packet.prefix(6)), Array(repeating: 0xFF, count: 6))
        for repetition in 0..<16 {
            let start = 6 + repetition * 6
            XCTAssertEqual(Array(packet[start..<start + 6]), mac)
        }
    }

    func test_magicPacket_acceptsDashesAndLowercase() {
        XCTAssertEqual(WakeOnLAN.magicPacket(mac: "02-00-00-ab-cd-ef"), WakeOnLAN.magicPacket(mac: "02:00:00:AB:CD:EF"))
    }

    func test_magicPacket_rejectsInvalidMAC() {
        XCTAssertNil(WakeOnLAN.magicPacket(mac: "02:00:00:AB:CD"))
        XCTAssertNil(WakeOnLAN.magicPacket(mac: "zz:00:00:AB:CD:EF"))
        XCTAssertNil(WakeOnLAN.magicPacket(mac: ""))
    }
}
