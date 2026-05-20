import Foundation

/// Host-pinned `URLSessionDelegate` that accepts Samsung's self-signed TLS
/// certificate **only** when the challenge's host matches `allowedHost`.
///
/// Any other host — and any non-server-trust authentication method — falls through
/// to `.performDefaultHandling`, so the system's normal ATS validation applies.
///
/// This is the scoped equivalent of `NSAllowsArbitraryLoads` and is the **only**
/// acceptable way to talk to the G95SC's `wss://<IP>:8002` endpoint. A global
/// ATS bypass would turn every future HTTP call in the app into a MITM surface
/// (see Phase 1 RESEARCH.md, Pitfall #2 and Anti-Pattern #1).
///
/// Designed to be attached to a `URLSession` built specifically for Samsung
/// traffic — never share the session with general-purpose HTTP work.
final class SamsungTLSDelegate: NSObject, URLSessionDelegate {

    /// The single host (typically the user-entered monitor IP) for which the
    /// self-signed Samsung certificate is accepted. Matched against
    /// `URLAuthenticationChallenge.protectionSpace.host` by exact string equality.
    let allowedHost: String

    init(allowedHost: String) {
        self.allowedHost = allowedHost
    }

    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition,
                                                  URLCredential?) -> Void) {
        guard
            challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            challenge.protectionSpace.host == allowedHost,
            let serverTrust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }
}
