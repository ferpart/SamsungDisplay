import XCTest
import Security
@testable import SamsungDisplay

final class TokenStoreTests: XCTestCase {
    private var sut: TokenStore!
    private let ip = "192.0.2.10"

    override func setUp() {
        super.setUp()
        sut = TokenStore(service: "com.fp.SamsungDisplay.tests.\(UUID().uuidString)")
    }

    override func tearDown() {
        sut.deleteAll()
        sut = nil
        super.tearDown()
    }

    func test_saveThenLoad_returnsSameToken() throws {
        try sut.save("abc123", for: ip)
        XCTAssertEqual(sut.load(for: ip), "abc123")
    }

    func test_saveTwice_replacesPreviousToken() throws {
        try sut.save("first", for: ip)
        try sut.save("second", for: ip)
        XCTAssertEqual(sut.load(for: ip), "second")
    }

    func test_delete_clearsStoredToken() throws {
        try sut.save("abc", for: ip)
        sut.delete(for: ip)
        XCTAssertNil(sut.load(for: ip))
    }

    func test_loadOnEmptyKeychain_returnsNil() {
        XCTAssertNil(sut.load(for: ip))
    }

    func test_tokensAreSeparatePerIP() throws {
        try sut.save("a", for: ip)
        try sut.save("b", for: "192.0.2.11")
        sut.delete(for: "192.0.2.11")
        XCTAssertEqual(sut.load(for: ip), "a")
        XCTAssertNil(sut.load(for: "192.0.2.11"))
    }

    func test_deleteAll_removesEveryIP() throws {
        try sut.save("a", for: ip)
        try sut.save("b", for: "192.0.2.11")
        sut.deleteAll()
        XCTAssertNil(sut.load(for: ip))
        XCTAssertNil(sut.load(for: "192.0.2.11"))
    }

    func test_deleteLegacyItem_removesOnlyTheDefaultAccount() throws {
        try sut.save("legacy", for: "default")
        try sut.save("current", for: ip)
        sut.deleteLegacyItem()
        XCTAssertNil(sut.load(for: "default"))
        XCTAssertEqual(sut.load(for: ip), "current")
    }

    func test_storedItem_usesAccessibleAfterFirstUnlock() {
        XCTAssertEqual(TokenStore.accessibility, kSecAttrAccessibleAfterFirstUnlock)
    }

    func test_sharedSingleton_hasExpectedService() {
        XCTAssertEqual(TokenStore.shared.service, "com.fp.SamsungDisplay.samsungToken")
    }
}
