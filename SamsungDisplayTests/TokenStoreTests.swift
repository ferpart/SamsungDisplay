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

    func test_storedItem_usesAccessibleAfterFirstUnlock() throws {
        try sut.save("checkme")

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: sut.service,
            kSecAttrAccount as String: sut.account,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        XCTAssertEqual(status, errSecSuccess, "expected to retrieve attributes for saved token")

        guard let attrs = item as? [String: Any] else {
            XCTFail("expected attribute dictionary")
            return
        }

        let accessible = attrs[kSecAttrAccessible as String] as? String
        XCTAssertEqual(
            accessible,
            kSecAttrAccessibleAfterFirstUnlock as String,
            "Keychain item must use kSecAttrAccessibleAfterFirstUnlock so the token survives reboot before user unlock"
        )
    }

    func test_sharedSingleton_hasExpectedServiceAndAccount() {
        XCTAssertEqual(TokenStore.shared.service, "com.fp.SamsungDisplay.samsungToken")
        XCTAssertEqual(TokenStore.shared.account, "default")
    }
}
