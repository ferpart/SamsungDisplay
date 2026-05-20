import Foundation
import Security

enum TokenStoreError: Error {
    case unhandled(OSStatus)
}

/// Keychain-backed CRUD wrapper for the Samsung auth token.
///
/// Per RESEARCH.md Pitfall #3, the Samsung monitor's pairing acceptance is a
/// one-shot deal: once the user taps "Allow", the returned token MUST be
/// persisted before the app exits. UserDefaults is unacceptable (leaks across
/// apps on the same host); only the macOS Keychain is appropriate.
///
/// `TokenStore.shared` is the singleton used by production callers. Tests
/// construct instances with unique service names per test to avoid polluting
/// the real keychain item.
struct TokenStore {
    let service: String
    let account: String

    static let shared = TokenStore(
        service: "com.fp.SamsungDisplay.samsungToken",
        account: "default"
    )

    /// Stores `token` in the Keychain, replacing any prior value for this
    /// service+account pair. The item is created with
    /// `kSecAttrAccessibleAfterFirstUnlock` so the token survives reboot
    /// before the user's first unlock of the session.
    func save(_ token: String) throws {
        let data = Data(token.utf8)
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        // Upsert semantics: delete then add. Avoids the "errSecDuplicateItem"
        // path entirely and keeps the implementation small.
        SecItemDelete(baseQuery as CFDictionary)

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw TokenStoreError.unhandled(status)
        }
    }

    /// Returns the stored token if present, or `nil` if no item exists for
    /// this service+account. Does NOT throw on a missing item — callers
    /// treat "no token" as the normal "not paired yet" state.
    func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Removes the stored token for this service+account, if any. No-op if
    /// nothing is stored.
    func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
