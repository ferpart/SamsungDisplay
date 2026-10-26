@testable import SamsungDisplay
import XCTest

final class RemoteKeyMappingTests: XCTestCase {

    func test_arrowKeysMapToDirections() {
        XCTAssertEqual(RemoteKeyMapping.key(forKeyCode: 126), .up)
        XCTAssertEqual(RemoteKeyMapping.key(forKeyCode: 125), .down)
        XCTAssertEqual(RemoteKeyMapping.key(forKeyCode: 123), .left)
        XCTAssertEqual(RemoteKeyMapping.key(forKeyCode: 124), .right)
    }

    func test_returnAndKeypadEnterMapToEnter() {
        XCTAssertEqual(RemoteKeyMapping.key(forKeyCode: 36), .enter)
        XCTAssertEqual(RemoteKeyMapping.key(forKeyCode: 76), .enter)
    }

    func test_escapeAndDeleteMapToBack() {
        XCTAssertEqual(RemoteKeyMapping.key(forKeyCode: 53), .back)
        XCTAssertEqual(RemoteKeyMapping.key(forKeyCode: 51), .back)
    }

    func test_otherKeysMapToNothing() {
        XCTAssertNil(RemoteKeyMapping.key(forKeyCode: 0))
        XCTAssertNil(RemoteKeyMapping.key(forKeyCode: 49))
        XCTAssertNil(RemoteKeyMapping.key(forKeyCode: 117))
    }
}
