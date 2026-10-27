import Foundation
import Security

enum TokenStoreError: Error {
    case unhandled(OSStatus)
}

/// Keychain-backed store for the Samsung auth token, with one item per monitor IP.
///
/// Tests construct instances with unique service names to avoid polluting
/// the real keychain item.
struct TokenStore {
    let service: String

    /// The Keychain accessibility class applied to stored tokens. Exposed so
    /// tests can assert the policy without relying on `SecItemCopyMatching`
    /// returning the `pdmn` attribute (macOS does not include it in attribute
    /// queries for generic password items).
    nonisolated(unsafe) static let accessibility: CFString = kSecAttrAccessibleAfterFirstUnlock

    static let shared = TokenStore(service: "com.fp.SamsungDisplay.samsungToken")

    private static let legacyAccount = "default"

    func save(_ token: String, for ip: String) throws {
        let baseQuery = query(account: ip)
        SecItemDelete(baseQuery as CFDictionary)

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = Data(token.utf8)
        addQuery[kSecAttrAccessible as String] = TokenStore.accessibility

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw TokenStoreError.unhandled(status)
        }
    }

    func load(for ip: String) -> String? {
        var query = query(account: ip)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func delete(for ip: String) {
        SecItemDelete(query(account: ip) as CFDictionary)
    }

    func deleteAll() {
        var query = query(account: nil)
        query[kSecMatchLimit as String] = kSecMatchLimitAll
        SecItemDelete(query as CFDictionary)
    }

    func deleteLegacyItem() {
        delete(for: Self.legacyAccount)
    }

    private func query(account: String?) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        query[kSecAttrAccount as String] = account
        return query
    }
}
