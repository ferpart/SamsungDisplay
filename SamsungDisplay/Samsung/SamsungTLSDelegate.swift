import CryptoKit
import Foundation
import Synchronization

/// Host-pinned `URLSessionDelegate` that accepts Samsung's self-signed TLS
/// certificate **only** when the challenge's host matches `allowedHost`, and,
/// when `pinnedCertificateSHA256` is set, only when the leaf certificate matches it.
///
/// Any other host — and any non-server-trust authentication method — falls through
/// to `.performDefaultHandling`, so the system's normal ATS validation applies.
///
/// Designed to be attached to a `URLSession` built specifically for Samsung
/// traffic — never share the session with general-purpose HTTP work.
final class SamsungTLSDelegate: NSObject, URLSessionDelegate, Sendable {

    let allowedHost: String
    let pinnedCertificateSHA256: String?

    private struct Outcome {
        var acceptedCertificateSHA256: String?
        var rejectedCertificate = false
    }

    private let outcome = Mutex(Outcome())

    var acceptedCertificateSHA256: String? { outcome.withLock { $0.acceptedCertificateSHA256 } }
    var rejectedCertificate: Bool { outcome.withLock { $0.rejectedCertificate } }

    init(allowedHost: String, pinnedCertificateSHA256: String? = nil) {
        self.allowedHost = allowedHost
        self.pinnedCertificateSHA256 = pinnedCertificateSHA256
    }

    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition,
                                                  URLCredential?) -> Void) {
        guard
            challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            challenge.protectionSpace.host == allowedHost,
            let serverTrust = challenge.protectionSpace.serverTrust,
            let fingerprint = Self.leafCertificateSHA256(of: serverTrust)
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        guard pinnedCertificateSHA256 == nil || pinnedCertificateSHA256 == fingerprint else {
            outcome.withLock { $0.rejectedCertificate = true }
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        outcome.withLock { $0.acceptedCertificateSHA256 = fingerprint }
        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }

    static func leafCertificateSHA256(of trust: SecTrust) -> String? {
        guard let leaf = (SecTrustCopyCertificateChain(trust) as? [SecCertificate])?.first else { return nil }
        return SHA256.hash(data: SecCertificateCopyData(leaf) as Data).map { String(format: "%02x", $0) }.joined()
    }
}
