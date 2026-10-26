@testable import SamsungDisplay
import XCTest

final class OSDContentTests: XCTestCase {

    func test_monitorWithVolumeUsesRealLevelAndMute() {
        XCTAssertEqual(OSDContent.choose(volume: 35, isMuted: true, localMuted: false), OSDContent(level: 35, muted: true))
        XCTAssertEqual(OSDContent.choose(volume: 35, isMuted: false, localMuted: true), OSDContent(level: 35, muted: false))
    }

    func test_monitorWithVolumeButNoMuteStateFallsBackToLocalMute() {
        XCTAssertEqual(OSDContent.choose(volume: 35, isMuted: nil, localMuted: true), OSDContent(level: 35, muted: true))
    }

    func test_monitorWithoutVolumeKeepsNilLevelAndLocalMute() {
        XCTAssertEqual(OSDContent.choose(volume: nil, isMuted: nil, localMuted: true), OSDContent(level: nil, muted: true))
        XCTAssertEqual(OSDContent.choose(volume: nil, isMuted: false, localMuted: false), OSDContent(level: nil, muted: false))
    }
}
