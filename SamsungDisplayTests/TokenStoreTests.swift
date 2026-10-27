import XCTest
@testable import SamsungDisplay

final class TokenStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var sut: TokenStore!
    private let ip = "192.0.2.10"

    override func setUp() {
        super.setUp()
        suiteName = "TokenStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        sut = TokenStore(defaults: defaults, service: "token")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        sut = nil
        defaults = nil
        super.tearDown()
    }

    func test_saveThenLoad_returnsSameToken() {
        sut.save("abc123", for: ip)
        XCTAssertEqual(sut.load(for: ip), "abc123")
    }

    func test_saveTwice_replacesPreviousToken() {
        sut.save("first", for: ip)
        sut.save("second", for: ip)
        XCTAssertEqual(sut.load(for: ip), "second")
    }

    func test_delete_clearsStoredToken() {
        sut.save("abc", for: ip)
        sut.delete(for: ip)
        XCTAssertNil(sut.load(for: ip))
    }

    func test_loadOnEmptyStore_returnsNil() {
        XCTAssertNil(sut.load(for: ip))
    }

    func test_tokensAreSeparatePerIP() {
        sut.save("a", for: ip)
        sut.save("b", for: "192.0.2.11")
        sut.delete(for: "192.0.2.11")
        XCTAssertEqual(sut.load(for: ip), "a")
        XCTAssertNil(sut.load(for: "192.0.2.11"))
    }

    func test_servicesAreSeparate() {
        let pins = TokenStore(defaults: defaults, service: "pin")
        sut.save("token", for: ip)
        pins.save("pin", for: ip)
        XCTAssertEqual(sut.load(for: ip), "token")
        XCTAssertEqual(pins.load(for: ip), "pin")
    }
}
