@testable import SamsungDisplay
import AppKit
import XCTest

final class MediaKeyEventTests: XCTestCase {

    private func data1(keyType: Int32, down: Bool, isRepeat: Bool = false) -> Int {
        Int(keyType) << 16 | (down ? 0xA : 0xB) << 8 | (isRepeat ? 1 : 0)
    }

    func test_decodesVolumeUpDown() {
        let event = MediaKeyEvent(subtype: 8, data1: data1(keyType: NX_KEYTYPE_SOUND_UP, down: true))
        XCTAssertEqual(event, MediaKeyEvent(key: .volUp, isDown: true, isRepeat: false))
    }

    func test_decodesVolumeDownKeyUp() {
        let event = MediaKeyEvent(subtype: 8, data1: data1(keyType: NX_KEYTYPE_SOUND_DOWN, down: false))
        XCTAssertEqual(event, MediaKeyEvent(key: .volDown, isDown: false, isRepeat: false))
    }

    func test_decodesMuteRepeat() {
        let event = MediaKeyEvent(subtype: 8, data1: data1(keyType: NX_KEYTYPE_MUTE, down: true, isRepeat: true))
        XCTAssertEqual(event, MediaKeyEvent(key: .mute, isDown: true, isRepeat: true))
    }

    func test_ignoresBrightnessKeys() {
        XCTAssertNil(MediaKeyEvent(subtype: 8, data1: data1(keyType: NX_KEYTYPE_BRIGHTNESS_UP, down: true)))
        XCTAssertNil(MediaKeyEvent(subtype: 8, data1: data1(keyType: NX_KEYTYPE_BRIGHTNESS_DOWN, down: true)))
    }

    func test_ignoresOtherSubtypes() {
        XCTAssertNil(MediaKeyEvent(subtype: 7, data1: data1(keyType: NX_KEYTYPE_SOUND_UP, down: true)))
    }

    func test_decodesFromCGEvent() throws {
        let nsEvent = try XCTUnwrap(NSEvent.otherEvent(
            with: .systemDefined, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, subtype: 8,
            data1: data1(keyType: NX_KEYTYPE_SOUND_UP, down: true, isRepeat: true), data2: -1
        ))
        let cgEvent = try XCTUnwrap(nsEvent.cgEvent)
        XCTAssertEqual(MediaKeyEvent(cgEvent), MediaKeyEvent(key: .volUp, isDown: true, isRepeat: true))
    }
}
