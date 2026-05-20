import XCTest
@testable import SamsungDisplay

/// Inert `URLAuthenticationChallengeSender` — the delegate under test invokes the
/// `completionHandler` form, not the sender form, so these stubs are never called.
private final class MockChallengeSender: NSObject, URLAuthenticationChallengeSender {
    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {}
    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {}
    func cancel(_ challenge: URLAuthenticationChallenge) {}
    func performDefaultHandling(for challenge: URLAuthenticationChallenge) {}
    func rejectProtectionSpaceAndContinue(with challenge: URLAuthenticationChallenge) {}
}

final class SamsungTLSDelegateTests: XCTestCase {

    // MARK: - Helpers

    private static let allowedHost = "192.168.1.42"

    private func makeChallenge(host: String,
                               authenticationMethod: String,
                               includeServerTrust: Bool = true) -> URLAuthenticationChallenge {
        // For server-trust challenges we attach a trust object built from an empty
        // certificate array. `SecTrustCreateWithCertificates` accepts an empty CFArray
        // and returns a non-nil SecTrust — sufficient for verifying the delegate's
        // disposition path. Real trust evaluation is exercised in Plan 06 against
        // the actual G95SC.
        var serverTrust: SecTrust?
        if includeServerTrust {
            let policy = SecPolicyCreateBasicX509()
            let emptyCerts = [] as CFArray
            SecTrustCreateWithCertificates(emptyCerts, policy, &serverTrust)
        }

        let space = URLProtectionSpace(
            host: host,
            port: 8002,
            protocol: "https",
            realm: nil,
            authenticationMethod: authenticationMethod
        )

        // `URLProtectionSpace.serverTrust` is read-only — it is populated by the
        // system during a real handshake. To exercise the delegate's serverTrust
        // path we subclass and override.
        let spaceWithTrust: URLProtectionSpace
        if includeServerTrust, let trust = serverTrust,
           authenticationMethod == NSURLAuthenticationMethodServerTrust {
            spaceWithTrust = ProtectionSpaceWithTrust(
                host: host,
                port: 8002,
                protocol: "https",
                realm: nil,
                authenticationMethod: authenticationMethod,
                trust: trust
            )
        } else {
            spaceWithTrust = space
        }

        return URLAuthenticationChallenge(
            protectionSpace: spaceWithTrust,
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: MockChallengeSender()
        )
    }

    // MARK: - Tests

    func test_useCredential_whenChallengeHostMatchesAllowedHost() {
        let sut = SamsungTLSDelegate(allowedHost: Self.allowedHost)
        let challenge = makeChallenge(
            host: Self.allowedHost,
            authenticationMethod: NSURLAuthenticationMethodServerTrust
        )

        var capturedDisposition: URLSession.AuthChallengeDisposition?
        var capturedCredential: URLCredential?
        var callCount = 0

        sut.urlSession(URLSession.shared, didReceive: challenge) { disposition, credential in
            callCount += 1
            capturedDisposition = disposition
            capturedCredential = credential
        }

        XCTAssertEqual(callCount, 1, "completion handler must be called exactly once")
        XCTAssertEqual(capturedDisposition, .useCredential)
        XCTAssertNotNil(capturedCredential, "matching host must produce a credential")
    }

    func test_performDefaultHandling_whenChallengeHostDoesNotMatch() {
        let sut = SamsungTLSDelegate(allowedHost: Self.allowedHost)
        let challenge = makeChallenge(
            host: "10.0.0.99",
            authenticationMethod: NSURLAuthenticationMethodServerTrust
        )

        var capturedDisposition: URLSession.AuthChallengeDisposition?
        var capturedCredential: URLCredential?
        var callCount = 0

        sut.urlSession(URLSession.shared, didReceive: challenge) { disposition, credential in
            callCount += 1
            capturedDisposition = disposition
            capturedCredential = credential
        }

        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(capturedDisposition, .performDefaultHandling,
                       "mismatched host must fall through to default handling — no global bypass")
        XCTAssertNil(capturedCredential)
    }

    func test_performDefaultHandling_whenAuthMethodIsNotServerTrust() {
        let sut = SamsungTLSDelegate(allowedHost: Self.allowedHost)
        let challenge = makeChallenge(
            host: Self.allowedHost, // host matches, but auth method does not
            authenticationMethod: NSURLAuthenticationMethodHTTPBasic
        )

        var capturedDisposition: URLSession.AuthChallengeDisposition?
        var capturedCredential: URLCredential?
        var callCount = 0

        sut.urlSession(URLSession.shared, didReceive: challenge) { disposition, credential in
            callCount += 1
            capturedDisposition = disposition
            capturedCredential = credential
        }

        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(capturedDisposition, .performDefaultHandling,
                       "non-server-trust methods must never receive the bypass credential")
        XCTAssertNil(capturedCredential)
    }

    func test_performDefaultHandling_whenServerTrustIsNil() {
        let sut = SamsungTLSDelegate(allowedHost: Self.allowedHost)
        let challenge = makeChallenge(
            host: Self.allowedHost,
            authenticationMethod: NSURLAuthenticationMethodServerTrust,
            includeServerTrust: false
        )

        var capturedDisposition: URLSession.AuthChallengeDisposition?
        var capturedCredential: URLCredential?
        var callCount = 0

        sut.urlSession(URLSession.shared, didReceive: challenge) { disposition, credential in
            callCount += 1
            capturedDisposition = disposition
            capturedCredential = credential
        }

        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(capturedDisposition, .performDefaultHandling,
                       "missing serverTrust must fall through, never invent a credential")
        XCTAssertNil(capturedCredential)
    }
}

/// `URLProtectionSpace.serverTrust` is read-only and only populated by the system
/// during real handshakes. Subclassing lets us inject a synthetic trust object for
/// unit testing the delegate's serverTrust-path logic.
private final class ProtectionSpaceWithTrust: URLProtectionSpace {
    private let _trust: SecTrust

    init(host: String,
         port: Int,
         protocol proto: String?,
         realm: String?,
         authenticationMethod: String?,
         trust: SecTrust) {
        self._trust = trust
        super.init(
            host: host,
            port: port,
            protocol: proto,
            realm: realm,
            authenticationMethod: authenticationMethod
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var serverTrust: SecTrust? { _trust }
}
