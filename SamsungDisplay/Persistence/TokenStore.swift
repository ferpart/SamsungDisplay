import Foundation

struct TokenStore: @unchecked Sendable {
    let defaults: UserDefaults
    let service: String

    static let shared = TokenStore(defaults: .standard, service: "com.fp.SamsungDisplay.samsungToken")
    static let certificatePins = TokenStore(defaults: .standard, service: "com.fp.SamsungDisplay.certificatePin")

    func save(_ token: String, for ip: String) {
        defaults.set(token, forKey: key(for: ip))
    }

    func load(for ip: String) -> String? {
        defaults.string(forKey: key(for: ip))
    }

    func delete(for ip: String) {
        defaults.removeObject(forKey: key(for: ip))
    }

    private func key(for ip: String) -> String {
        "\(service).\(ip)"
    }
}
