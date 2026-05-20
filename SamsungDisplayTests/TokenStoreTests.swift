import XCTest
import Security
@testable import SamsungDisplay

final class TokenStoreTests: XCTestCase {
    private var sut: TokenStore!

    override func setUp() {
        super.setUp()
        sut = TokenStore(
            service: "com.fp.SamsungDisplay.tests.\(UUID().uuidString)",
            account: "test"
        )
    }

    override func tearDown() {
        sut.delete()
        sut = nil
        super.tearDown()
    }

    func test_saveThenLoad_returnsSameToken() throws {
        try sut.save("abc123")
        XCTAssertEqual(sut.load(), "abc123")
    }

    func test_saveTwice_replacesPreviousToken() throws {
        try sut.save("first")
        try sut.save("second")
        XCTAssertEqual(sut.load(), "second")
    }

    func test_delete_clearsStoredToken() throws {
        try sut.save("abc")
        sut.delete()
        XCTAssertNil(sut.load())
    }

    func test_loadOnEmptyKeychain_returnsNil() {
        // setUp gives a fresh unique service, so nothing is stored yet.
        XCTAssertNil(sut.load())
    }

    func test_storedItem_usesAccessibleAfterFirstUnlock() {
        // macOS does not return the `pdmn` (kSecAttrAccessible) attribute in
        // `SecItemCopyMatching` results for generic password items, so we cannot
        // observe the persisted policy at runtime. Instead we assert the policy
        // constant TokenStore applies on save() — the source of truth that
        // SecItemAdd actually receives.
        XCTAssertEqual(
            TokenStore.accessibility,
            kSecAttrAccessibleAfterFirstUnlock,
            "TokenStore must save tokens with kSecAttrAccessibleAfterFirstUnlock so the token survives reboot before user unlock"
        )
    }

    func test_sharedSingleton_hasExpectedServiceAndAccount() {
        XCTAssertEqual(TokenStore.shared.service, "com.fp.SamsungDisplay.samsungToken")
        XCTAssertEqual(TokenStore.shared.account, "default")
    }
}
