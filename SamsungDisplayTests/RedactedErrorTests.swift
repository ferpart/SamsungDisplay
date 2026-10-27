import XCTest
@testable import SamsungDisplay

final class RedactedErrorTests: XCTestCase {

    func test_urlErrorWithFailingURL_omitsToken() {
        let url = URL(string: "wss://192.0.2.10:8002/api/v2/channels/samsung.remote.control?name=U2Ft&token=SECRET")!
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotConnectToHost, userInfo: [
            NSURLErrorFailingURLErrorKey: url,
            NSURLErrorFailingURLStringErrorKey: url.absoluteString,
        ])
        XCTAssertEqual(error.redactedDescription, "NSURLErrorDomain -1004")
    }

    func test_swiftError_keepsCaseName() {
        XCTAssertEqual(SamsungWSError.connectionTimeout.redactedDescription, "connectionTimeout")
    }
}
