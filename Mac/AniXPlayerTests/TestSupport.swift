import Foundation
import XCTest

func makeOAuthToken(
    access: String = "access-1",
    refresh: String = "refresh-1",
    expiresIn: TimeInterval = 3600
) -> OAuthToken {
    OAuthToken(
        accessToken: access,
        refreshToken: refresh,
        expiresAt: Date().addingTimeInterval(expiresIn),
        scope: "user_login"
    )
}

final class FakeOAuthService: OAuthServicing {
    let environment = APIEnvironment(host: "https://api.dandanplay.net", clientId: "test-client")

    var exchangeResult: Result<OAuthToken, Error> = .failure(OAuthServiceError.profileDecoding)
    var refreshResult: Result<OAuthToken, Error> = .failure(OAuthServiceError.profileDecoding)
    var profileResult: Result<OAuthUserProfile, Error> = .success(
        OAuthUserProfile(userId: 1, userName: "user", screenName: "Screen")
    )

    var exchangeCallCount = 0
    var refreshCallCount = 0
    var revokeCallCount = 0
    var logoutCallCount = 0
    var refreshDelayNanoseconds: UInt64 = 0

    func makeAuthorizeRequest(now: Date) -> (url: URL, transaction: OAuthTransaction) {
        let transaction = OAuthTransaction(
            state: "state",
            verifier: "verifier",
            redirectURI: environment.redirectURI,
            createdAt: now
        )
        return (URL(string: "https://api.dandanplay.net/api/v2/oauth/authorize")!, transaction)
    }

    func exchangeCode(_ code: String, transaction: OAuthTransaction) async throws -> OAuthToken {
        exchangeCallCount += 1
        return try exchangeResult.get()
    }

    func refresh(refreshToken: String) async throws -> OAuthToken {
        refreshCallCount += 1
        if refreshDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: refreshDelayNanoseconds)
        }
        return try refreshResult.get()
    }

    func revoke(refreshToken: String) async {
        revokeCallCount += 1
    }

    func logout(accessToken: String) async {
        logoutCallCount += 1
    }

    func fetchProfile(accessToken: String) async throws -> OAuthUserProfile {
        try profileResult.get()
    }
}

final class FakeRefreshTokenStore: RefreshTokenStore {
    var token: String?
    var readError: Error?
    var saveError: Error?
    var deleteError: Error?
    var deleteCount = 0
    var saveCount = 0

    init(token: String? = nil) {
        self.token = token
    }

    func readRefreshToken() throws -> String? {
        if let readError = readError {
            throw readError
        }
        return token
    }

    func saveRefreshToken(_ token: String) throws {
        saveCount += 1
        if let saveError = saveError {
            throw saveError
        }
        self.token = token
    }

    func deleteRefreshToken() throws {
        deleteCount += 1
        if let deleteError = deleteError {
            throw deleteError
        }
        token = nil
    }
}

/// URLProtocol stub：不发真实网络请求。
final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (status: Int, headers: [String: String], body: Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        do {
            let result = try handler(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: result.status,
                httpVersion: nil,
                headerFields: result.headers
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: result.body)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
