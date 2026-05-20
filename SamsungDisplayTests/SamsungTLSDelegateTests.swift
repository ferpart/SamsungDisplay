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

    /// Self-signed RSA-2048 X.509 DER, CN=test, generated via `openssl req -x509`
    /// for the sole purpose of constructing a non-nil `SecTrust` in these tests.
    /// `SecTrustCreateWithCertificates` rejects an empty CFArray on macOS 14+,
    /// so we must seed it with a real certificate. The cert is never actually
    /// validated — we only need the trust object so the delegate's
    /// `let serverTrust = challenge.protectionSpace.serverTrust` guard passes.
    /// Real trust evaluation is exercised in Plan 06 against the real G95SC.
    private static let selfSignedCertDER = Data(base64Encoded:
        "MIIC/zCCAeegAwIBAgIUBugVWSIb137tH8dk8WI1FvIFFZIwDQYJKoZIhvcNAQEL" +
        "BQAwDzENMAsGA1UEAwwEdGVzdDAeFw0yNjA1MjAwMTI5NTlaFw0yNzA1MjAwMTI5" +
        "NTlaMA8xDTALBgNVBAMMBHRlc3QwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK" +
        "AoIBAQDFiPcYeEjhXEyHNJX7T/OgD1vbLQHo/Cs1sJK4q+DwFB4AK2sW5V8DlhbE" +
        "/zwRSv2IWuix2AvmEdqmAI33fbQ+M9Fm+TAHT/ScB4UstR/T5NqnqiBLwsIz9SZi" +
        "JE6g/JVQzKJPCIk9L0RagD6RrqZ4Q5dCnj98xyGLrFHJBc4fax0q2GL9jt45CxwO" +
        "3LXhzlHfYk6Paz93ScYh2TPwoRA53LZGOKVyNOhnIHhPhYDPCgeta4Fy+UtwPIgw" +
        "LT4IRPHv86FKmclx72ok9TbigyIQw+enq+heq2+c6KkTwNbUvvl3fDqk7i3y9ghI" +
        "JwDZRGiMqlL0BWrt1/ds5wDVxpOTAgMBAAGjUzBRMB0GA1UdDgQWBBQ01lA5vigp" +
        "bwoFnUMEoOJo63iuSjAfBgNVHSMEGDAWgBQ01lA5vigpbwoFnUMEoOJo63iuSjAP" +
        "BgNVHRMBAf8EBTADAQH/MA0GCSqGSIb3DQEBCwUAA4IBAQC7Kr74xmW44/gK8ISm" +
        "fD8j14dxp4QHZRMFRFQHKnwdpA3M41pog3WIDB81crrx+FxpZ7E/ppZKsQzsUw56" +
        "uvuQJoPgzVkreMV/Bfcy/6EHITPcaw7xIgqtrU7+qd+RQIdzs94swwc3XwtgRhjS" +
        "fi6RuYtWnyRY74s/kr97pfD9HMjhC1DIdut768nfqvT2kPEmcW3zy6Mat11l8AGt" +
        "CE5etFgGlZe0v+ClPw810EkoWXX1z+0Ngkf9c71Y9m9NC7icnOP292E5PxvmJ2Wf" +
        "JICAMcnKJdrDDJ3qIC5pOxxyEjmHsKyhgVTzzYNCdgdtdtE++LHfoOqxUXpv6Dpw" +
        "vLVp"
    )!

    private func makeChallenge(host: String,
                               authenticationMethod: String,
                               includeServerTrust: Bool = true) -> URLAuthenticationChallenge {
        var serverTrust: SecTrust?
        if includeServerTrust {
            let cert = SecCertificateCreateWithData(nil, Self.selfSignedCertDER as CFData)!
            let policy = SecPolicyCreateBasicX509()
            SecTrustCreateWithCertificates([cert] as CFArray, policy, &serverTrust)
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
private final class ProtectionSpaceWithTrust: URLProtectionSpace, @unchecked Sendable {
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
