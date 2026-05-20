@testable import SamsungDisplay
import XCTest

final class ReconnectPolicyTests: XCTestCase {

    // CONN-06: 1, 2, 4, 8, 16, 30, 30… cap at 30s.
    func test_schedule_doublesUntilCap() {
        // TODO(Wave 1): un-stub once ReconnectPolicy ships.
        // let p = ReconnectPolicy.default
        // var d: Duration? = nil
        // var actual: [Duration] = []
        // for _ in 0..<7 {
        //     d = p.nextDelay(after: d)
        //     actual.append(d!)
        // }
        // XCTAssertEqual(actual, [
        //     .seconds(1), .seconds(2), .seconds(4),
        //     .seconds(8), .seconds(16), .seconds(30),
        //     .seconds(30),
        // ])
        XCTFail("Pending Wave 1 implementation: ReconnectPolicy.default + nextDelay")
    }

    func test_schedule_resetsOnNilInput() {
        // TODO(Wave 1): un-stub once ReconnectPolicy ships.
        // XCTAssertEqual(ReconnectPolicy.default.nextDelay(after: nil), .seconds(1))
        XCTFail("Pending Wave 1 implementation: nextDelay(after: nil)")
    }
}
