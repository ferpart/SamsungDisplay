import Foundation
import Security

enum TokenStoreError: Error {
    case unhandled(OSStatus)
}

struct TokenStore {
    let service: String

    static let usesDataProtectionKeychain = hasEntitlement("keychain-access-groups")

    static var accessibility: CFString {
        usesDataProtectionKeychain ? kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly : kSecAttrAccessibleAfterFirstUnlock
    }

    static let shared = TokenStore(service: "com.fp.SamsungDisplay.samsungToken")
    static let certificatePins = TokenStore(service: "com.fp.SamsungDisplay.certificatePin")

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

    func deleteLegacyItems() {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]
        if !Self.usesDataProtectionKeychain {
            query[kSecAttrAccount as String] = Self.legacyAccount
        }
        SecItemDelete(query as CFDictionary)
    }

    private func query(account: String?) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        query[kSecAttrAccount as String] = account
        if Self.usesDataProtectionKeychain {
            query[kSecUseDataProtectionKeychain as String] = true
        }
        return query
    }

    private static func hasEntitlement(_ name: String) -> Bool {
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        return SecTaskCopyValueForEntitlement(task, name as CFString, nil) != nil
    }
}
