@testable import SamsungDisplay
import XCTest

final class SliderThrottleTests: XCTestCase {

    private let start = ContinuousClock.now
    private var throttle = SliderThrottle(interval: .milliseconds(100))

    func test_firstSubmitSendsImmediately() {
        XCTAssertEqual(throttle.submit(40, at: start), 40)
    }

    func test_submitInsideIntervalIsHeld() {
        _ = throttle.submit(40, at: start)
        XCTAssertNil(throttle.submit(41, at: start + .milliseconds(30)))
        XCTAssertNil(throttle.submit(42, at: start + .milliseconds(60)))
    }

    func test_submitAfterIntervalSends() {
        _ = throttle.submit(40, at: start)
        XCTAssertEqual(throttle.submit(50, at: start + .milliseconds(100)), 50)
    }

    func test_flushReturnsLatestHeldLevelOnce() {
        _ = throttle.submit(40, at: start)
        _ = throttle.submit(41, at: start + .milliseconds(30))
        _ = throttle.submit(42, at: start + .milliseconds(60))
        XCTAssertEqual(throttle.flush(at: start + .milliseconds(70)), 42)
        XCTAssertNil(throttle.flush(at: start + .milliseconds(80)))
    }

    func test_flushWithNothingHeldReturnsNil() {
        _ = throttle.submit(40, at: start)
        XCTAssertNil(throttle.flush(at: start + .milliseconds(10)))
    }

    func test_dragFloodSendsFewerRequestsThanSamples() {
        var sent: [Int] = []
        for sample in 0..<100 {
            if let level = throttle.submit(sample, at: start + .milliseconds(sample * 10)) { sent.append(level) }
        }
        XCTAssertEqual(sent.count, 10)
        XCTAssertEqual(sent.first, 0)
    }
}
