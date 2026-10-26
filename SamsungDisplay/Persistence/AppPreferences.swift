import Foundation

/// UserDefaults-backed storage for non-sensitive app preferences.
///
/// The monitor IP is on the user's LAN and already known to them — Keychain
/// would be overkill (per `01-RESEARCH.md` "Standard Stack > Supporting").
/// Phase 3's Settings view will wrap this in an `@Observable` for SwiftUI
/// binding, but the underlying storage shape stays the same.
///
/// `defaults` is the only stored property; this type is a façade over
/// `UserDefaults`, so `set` is `nonmutating` (matches the `@AppStorage`
/// mental model). Inject a custom suite in tests to avoid polluting
/// `UserDefaults.standard`.
struct AppPreferences: @unchecked Sendable {
    // `@unchecked Sendable`: `defaults` is a thread-safe `UserDefaults` instance
    // (Foundation docs: "thread-safe"), held by-reference through an immutable
    // `let`. The struct exposes no mutable state of its own — all mutation goes
    // through `UserDefaults` directly. The compiler cannot prove this because
    // `UserDefaults` is an `NSObject` subclass without `Sendable` conformance.
    let defaults: UserDefaults

    static let shared = AppPreferences(defaults: .standard)

    private enum Key {
        static let monitorIP = "monitorIP"
        static let audioOutputName = "audioOutputName"
    }

    var monitorIP: String? {
        get { defaults.string(forKey: Key.monitorIP) }
        nonmutating set {
            if let newValue {
                defaults.set(newValue, forKey: Key.monitorIP)
            } else {
                // Use removeObject — `set(nil, forKey:)` writes NSNull which
                // makes `object(forKey:)` return non-nil and is a footgun.
                defaults.removeObject(forKey: Key.monitorIP)
            }
        }
    }

    var audioOutputName: String? {
        get { defaults.string(forKey: Key.audioOutputName) }
        nonmutating set {
            if let newValue {
                defaults.set(newValue, forKey: Key.audioOutputName)
            } else {
                defaults.removeObject(forKey: Key.audioOutputName)
            }
        }
    }
}
