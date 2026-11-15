import XCTest

final class OAuthPKCETests: XCTestCase {
    /// RFC 7636 附录 B 的标准测试向量。
    func testRFC7636Vector() {
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        XCTAssertEqual(OAuthPKCE.challenge(for: verifier), "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    func testPairShapeAndUniqueness() {
        let first = OAuthPKCE.makePair()
        let second = OAuthPKCE.makePair()

        XCTAssertEqual(first.verifier.count, 43)
        XCTAssertEqual(first.challenge.count, 43)
        XCTAssertNotEqual(first.verifier, second.verifier)
        XCTAssertEqual(first.challenge, OAuthPKCE.challenge(for: first.verifier))

        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        XCTAssertNil(first.verifier.rangeOfCharacter(from: allowed.inverted))
        XCTAssertNil(first.challenge.rangeOfCharacter(from: allowed.inverted))
    }
}

final class OAuthCallbackTests: XCTestCase {
    private let redirect = "https://api.dandanplay.net/api/v2/oauth/callback/app/ddplaywin32v3"

    private func makeTransaction(createdAt: Date = Date()) -> OAuthTransaction {
        OAuthTransaction(
            state: "expected-state",
            verifier: "verifier",
            redirectURI: redirect,
            createdAt: createdAt
        )
    }

    private func callbackURL(_ query: String) -> URL {
        URL(string: redirect + "?" + query)!
    }

    func testMatchesExactRedirect() {
        XCTAssertTrue(OAuthCallback.matches(callbackURL("code=abc&state=x"), redirectURI: redirect))
    }

    func testRejectsNearMisses() {
        XCTAssertFalse(OAuthCallback.matches(URL(string: redirect + "/extra")!, redirectURI: redirect))
        XCTAssertFalse(OAuthCallback.matches(URL(string: redirect.replacingOccurrences(of: "https://", with: "http://"))!, redirectURI: redirect))
        XCTAssertFalse(OAuthCallback.matches(URL(string: redirect.replacingOccurrences(of: "api.dandanplay.net", with: "evil.example"))!, redirectURI: redirect))
        XCTAssertFalse(OAuthCallback.matches(URL(string: redirect.replacingOccurrences(of: "/app/ddplaywin32v3", with: "/app/other"))!, redirectURI: redirect))
        XCTAssertFalse(OAuthCallback.matches(URL(string: "https://api.dandanplay.net/api/v2/oauth/callback/app/ddplaywin32v3x")!, redirectURI: redirect))
    }

    func testParsesCode() throws {
        let code = try OAuthCallback.parse(
            callbackURL("code=the-code&state=expected-state"),
            expected: makeTransaction()
        )
        XCTAssertEqual(code, "the-code")
    }

    func testRejectsStateMismatch() {
        XCTAssertThrowsError(
            try OAuthCallback.parse(
                callbackURL("code=the-code&state=other-state"),
                expected: makeTransaction()
            )
        ) { error in
            guard case OAuthCallbackError.stateMismatch = error else {
                return XCTFail("unexpected error: \(error)")
            }
        }
    }

    func testRejectsExpiredTransaction() {
        let expired = makeTransaction(createdAt: Date().addingTimeInterval(-11 * 60))
        XCTAssertThrowsError(
            try OAuthCallback.parse(callbackURL("code=the-code&state=expected-state"), expected: expired)
        ) { error in
            guard case OAuthCallbackError.expired = error else {
                return XCTFail("unexpected error: \(error)")
            }
        }
    }

    func testProviderErrorBecomesReadableError() {
        XCTAssertThrowsError(
            try OAuthCallback.parse(
                callbackURL("error=access_denied&error_description=user%20denied&state=expected-state"),
                expected: makeTransaction()
            )
        ) { error in
            guard case OAuthCallbackError.authorizationDenied(let message) = error else {
                return XCTFail("unexpected error: \(error)")
            }
            XCTAssertEqual(message, "user denied")
        }
    }

    func testMissingCode() {
        XCTAssertThrowsError(
            try OAuthCallback.parse(callbackURL("state=expected-state"), expected: makeTransaction())
        ) { error in
            guard case OAuthCallbackError.missingCode = error else {
                return XCTFail("unexpected error: \(error)")
            }
        }
    }
}

final class OAuthTokenTests: XCTestCase {
    func testValidResponseBecomesToken() throws {
        let now = Date()
        let response = OAuthTokenResponse(
            accessToken: "a",
            tokenType: "Bearer",
            expiresIn: 3600,
            refreshToken: "r",
            scope: "user_login"
        )
        let token = try OAuthToken.make(from: response, now: now)

        XCTAssertEqual(token.accessToken, "a")
        XCTAssertEqual(token.refreshToken, "r")
        XCTAssertEqual(token.expiresAt.timeIntervalSince(now), 3600, accuracy: 0.001)
        XCTAssertFalse(token.isExpiring(now: now))
        XCTAssertTrue(token.isExpiring(now: now.addingTimeInterval(3301)))
    }

    func testInvalidResponsesAreRejected() {
        XCTAssertThrowsError(try OAuthToken.make(from: OAuthTokenResponse(accessToken: "", tokenType: nil, expiresIn: 3600, refreshToken: "r", scope: nil)))
        XCTAssertThrowsError(try OAuthToken.make(from: OAuthTokenResponse(accessToken: "a", tokenType: nil, expiresIn: 0, refreshToken: "r", scope: nil)))
        XCTAssertThrowsError(try OAuthToken.make(from: OAuthTokenResponse(accessToken: "a", tokenType: nil, expiresIn: 3600, refreshToken: "", scope: nil)))
    }
}

final class OAuthProfileTests: XCTestCase {
    func testDecodesProfileAndPrivileges() throws {
        let json = """
        {
          "userId": 42,
          "userName": "kaede",
          "screenName": "Kaede",
          "email": "a@b.com",
          "emailVerified": true,
          "profileImage": "https://example.com/a.png",
          "accountTier": "member",
          "appScope": "user_login",
          "privileges": {
            "member": "2099-01-01T00:00:00+08:00",
            "resmonitor": "2026-12-01T00:00:00+08:00"
          }
        }
        """

        let profile = try JSONDecoder().decode(OAuthUserProfile.self, from: Data(json.utf8))
        XCTAssertEqual(profile.userId, 42)
        XCTAssertEqual(profile.displayName, "Kaede")
        XCTAssertEqual(profile.email, "a@b.com")
        XCTAssertTrue(profile.emailVerified)
        XCTAssertTrue(profile.isMember)
        XCTAssertNotNil(profile.privileges?.resmonitor)
    }

    func testMissingFieldsUseDefaults() throws {
        let profile = try JSONDecoder().decode(OAuthUserProfile.self, from: Data("{}".utf8))
        XCTAssertEqual(profile.userId, 0)
        XCTAssertFalse(profile.isMember)
        XCTAssertEqual(profile.displayName, "已登录用户")
    }
}

final class OAuthServiceTests: XCTestCase {
    func testAuthorizeRequestCarriesPKCEAndExactRedirect() {
        let service = OAuthService(
            environment: APIEnvironment(host: "https://api.dandanplay.net", clientId: "test-client"),
            client: APIClient()
        )
        let result = service.makeAuthorizeRequest(now: Date())
        let components = URLComponents(url: result.url, resolvingAgainstBaseURL: false)!
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "api.dandanplay.net")
        XCTAssertEqual(components.path, "/api/v2/oauth/authorize")
        XCTAssertEqual(items["client_id"], "test-client")
        XCTAssertEqual(items["response_type"], "code")
        XCTAssertEqual(items["code_challenge_method"], "S256")
        XCTAssertEqual(items["state"], result.transaction.state)
        XCTAssertEqual(items["code_challenge"], OAuthPKCE.challenge(for: result.transaction.verifier))
        XCTAssertEqual(items["redirect_uri"], "https://api.dandanplay.net/api/v2/oauth/callback/app/test-client")
        XCTAssertNil(items["scope"])
    }
}

final class APIClientTests: XCTestCase {
    private var client: APIClient!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        client = APIClient(session: URLSession(configuration: configuration))
    }

    override func tearDown() {
        StubURLProtocol.handler = nil
        client = nil
        super.tearDown()
    }

    func testDecodesSuccessResponse() async throws {
        StubURLProtocol.handler = { _ in
            (200, ["Content-Type": "application/json"], Data("""
            {"access_token":"a","token_type":"Bearer","expires_in":3600,"refresh_token":"r"}
            """.utf8))
        }

        let request = URLRequest(url: URL(string: "https://example.com/token")!)
        let response: OAuthTokenResponse = try await client.send(request)
        XCTAssertEqual(response.accessToken, "a")
        XCTAssertEqual(response.refreshToken, "r")
        XCTAssertEqual(response.expiresIn, 3600)
    }

    func testMaps401ToUnauthorized() async {
        StubURLProtocol.handler = { _ in (401, [:], Data()) }
        let request = URLRequest(url: URL(string: "https://example.com/user/me")!)

        do {
            let _: Data = try await client.send(request)
            XCTFail("expected error")
        } catch let error as APIError {
            guard case .unauthorized = error else {
                return XCTFail("unexpected error: \(error)")
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testMapsInvalidGrant() async {
        StubURLProtocol.handler = { _ in
            (400, ["Content-Type": "application/json"], Data("""
            {"error":"invalid_grant","error_description":"bad refresh token"}
            """.utf8))
        }
        let request = URLRequest(url: URL(string: "https://example.com/token")!)

        do {
            let _: Data = try await client.send(request)
            XCTFail("expected error")
        } catch let error as APIError {
            XCTAssertTrue(error.isInvalidGrant)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testMaps403HeaderMessage() async {
        StubURLProtocol.handler = { _ in
            (403, ["X-Error-Message": "Missing Authentication Headers"], Data())
        }
        let request = URLRequest(url: URL(string: "https://example.com/bangumi/1")!)

        do {
            let _: Data = try await client.send(request)
            XCTFail("expected error")
        } catch let error as APIError {
            guard case .forbidden(let message) = error else {
                return XCTFail("unexpected error: \(error)")
            }
            XCTAssertEqual(message, "Missing Authentication Headers")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testFormBodyIsSortedAndPercentEncoded() {
        let body = APIClient.formBody([
            "grant_type": "authorization_code",
            "client_id": "ddplaywin32v3",
            "code": "a b+c",
            "redirect_uri": "https://api.dandanplay.net/cb"
        ])
        XCTAssertEqual(
            String(data: body, encoding: .utf8),
            "client_id=ddplaywin32v3&code=a%20b%2Bc&grant_type=authorization_code&redirect_uri=https%3A%2F%2Fapi.dandanplay.net%2Fcb"
        )
    }
}

final class SessionStoreTests: XCTestCase {
    private func makeStore(
        service: FakeOAuthService,
        tokenStore: FakeRefreshTokenStore,
        holder: AccessTokenHolder = AccessTokenHolder()
    ) -> SessionStore {
        SessionStore(service: service, tokenStore: tokenStore, accessTokenHolder: holder)
    }

    private func transaction(for service: FakeOAuthService) -> OAuthTransaction {
        service.makeAuthorizeRequest(now: Date()).transaction
    }

    func testSignInPersistsRefreshTokenAndProfile() async throws {
        let service = FakeOAuthService()
        let tokenStore = FakeRefreshTokenStore()
        let holder = AccessTokenHolder()
        let session = makeStore(service: service, tokenStore: tokenStore, holder: holder)

        service.exchangeResult = .success(makeOAuthToken(access: "a1", refresh: "r1"))
        service.profileResult = .success(OAuthUserProfile(userId: 7, userName: "u", screenName: "S"))

        try await session.signIn(code: "code", transaction: transaction(for: service))

        let state = await session.currentState()
        let profile = await session.currentProfile()
        XCTAssertEqual(state, .loggedIn)
        XCTAssertEqual(profile?.userId, 7)
        XCTAssertEqual(holder.current(), "a1")
        XCTAssertEqual(try tokenStore.readRefreshToken(), "r1")
    }

    func testSignInKeychainFailureDoesNotLogIn() async {
        let service = FakeOAuthService()
        let tokenStore = FakeRefreshTokenStore()
        tokenStore.saveError = NSError(domain: "test", code: 1)
        let holder = AccessTokenHolder()
        let session = makeStore(service: service, tokenStore: tokenStore, holder: holder)

        service.exchangeResult = .success(makeOAuthToken())

        do {
            try await session.signIn(code: "code", transaction: transaction(for: service))
            XCTFail("expected error")
        } catch {
            guard case SessionStore.SessionError.tokenStorage = error else {
                return XCTFail("unexpected error: \(error)")
            }
        }

        let state = await session.currentState()
        XCTAssertEqual(state, .loggedOut)
        XCTAssertNil(holder.current())
    }

    func testCachedAccessTokenDoesNotRefresh() async throws {
        let service = FakeOAuthService()
        let tokenStore = FakeRefreshTokenStore()
        let session = makeStore(service: service, tokenStore: tokenStore)

        service.exchangeResult = .success(makeOAuthToken(access: "a1", refresh: "r1", expiresIn: 3600))
        try await session.signIn(code: "code", transaction: transaction(for: service))

        let token = try await session.validAccessToken()
        XCTAssertEqual(token, "a1")
        XCTAssertEqual(service.refreshCallCount, 0)
    }

    func testForceRefreshIsSingleFlight() async throws {
        let service = FakeOAuthService()
        let tokenStore = FakeRefreshTokenStore()
        let session = makeStore(service: service, tokenStore: tokenStore)

        service.exchangeResult = .success(makeOAuthToken(access: "a1", refresh: "r1"))
        try await session.signIn(code: "code", transaction: transaction(for: service))

        service.refreshResult = .success(makeOAuthToken(access: "a2", refresh: "r2"))
        service.refreshDelayNanoseconds = 80_000_000

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<8 {
                group.addTask {
                    _ = try? await session.forceRefresh()
                }
            }
        }

        XCTAssertEqual(service.refreshCallCount, 1)
        XCTAssertEqual(try tokenStore.readRefreshToken(), "r2")
    }

    func testInvalidGrantClearsSession() async throws {
        let service = FakeOAuthService()
        let tokenStore = FakeRefreshTokenStore()
        let holder = AccessTokenHolder()
        let session = makeStore(service: service, tokenStore: tokenStore, holder: holder)

        service.exchangeResult = .success(makeOAuthToken(access: "a1", refresh: "r1"))
        try await session.signIn(code: "code", transaction: transaction(for: service))

        service.refreshResult = .failure(APIError.oauth(code: "invalid_grant", description: nil, status: 400))
        _ = try? await session.forceRefresh()

        let state = await session.currentState()
        XCTAssertEqual(state, .loggedOut)
        XCTAssertNil(holder.current())
        XCTAssertNil(try tokenStore.readRefreshToken())
        XCTAssertGreaterThanOrEqual(tokenStore.deleteCount, 1)
    }

    func testNetworkRefreshErrorKeepsSession() async throws {
        let service = FakeOAuthService()
        let tokenStore = FakeRefreshTokenStore()
        let holder = AccessTokenHolder()
        let session = makeStore(service: service, tokenStore: tokenStore, holder: holder)

        service.exchangeResult = .success(makeOAuthToken(access: "a1", refresh: "r1"))
        try await session.signIn(code: "code", transaction: transaction(for: service))

        service.refreshResult = .failure(APIError.transport(URLError(.notConnectedToInternet)))
        _ = try? await session.forceRefresh()

        let state = await session.currentState()
        XCTAssertEqual(state, .loggedIn)
        XCTAssertEqual(holder.current(), "a1")
        XCTAssertEqual(try tokenStore.readRefreshToken(), "r1")
        XCTAssertEqual(tokenStore.deleteCount, 0)
    }

    func testRefreshKeychainFailureClearsSession() async throws {
        let service = FakeOAuthService()
        let tokenStore = FakeRefreshTokenStore()
        let session = makeStore(service: service, tokenStore: tokenStore)

        service.exchangeResult = .success(makeOAuthToken(access: "a1", refresh: "r1"))
        try await session.signIn(code: "code", transaction: transaction(for: service))

        service.refreshResult = .success(makeOAuthToken(access: "a2", refresh: "r2"))
        tokenStore.saveError = NSError(domain: "keychain", code: -25300)
        _ = try? await session.forceRefresh()

        let state = await session.currentState()
        XCTAssertEqual(state, .loggedOut)
        XCTAssertNil(try tokenStore.readRefreshToken())
    }

    func testRestoreIsSingleFlight() async {
        let service = FakeOAuthService()
        let tokenStore = FakeRefreshTokenStore(token: "r1")
        let session = makeStore(service: service, tokenStore: tokenStore)

        service.refreshResult = .success(makeOAuthToken(access: "a1", refresh: "r1"))
        service.refreshDelayNanoseconds = 80_000_000

        let results = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
            for _ in 0..<6 {
                group.addTask { await session.restoreIfPossible() }
            }
            var values: [Bool] = []
            for await value in group {
                values.append(value)
            }
            return values
        }

        XCTAssertEqual(service.refreshCallCount, 1)
        XCTAssertTrue(results.allSatisfy { $0 })
        let state = await session.currentState()
        XCTAssertEqual(state, .loggedIn)
    }

    func testLogoutClearsLocalStateAndRevokes() async throws {
        let service = FakeOAuthService()
        let tokenStore = FakeRefreshTokenStore()
        let holder = AccessTokenHolder()
        let session = makeStore(service: service, tokenStore: tokenStore, holder: holder)

        service.exchangeResult = .success(makeOAuthToken(access: "a1", refresh: "r1"))
        try await session.signIn(code: "code", transaction: transaction(for: service))

        await session.logout()

        let state = await session.currentState()
        XCTAssertEqual(state, .loggedOut)
        XCTAssertNil(holder.current())
        XCTAssertNil(try tokenStore.readRefreshToken())
        XCTAssertEqual(service.revokeCallCount, 1)
        XCTAssertEqual(service.logoutCallCount, 1)
    }
}
