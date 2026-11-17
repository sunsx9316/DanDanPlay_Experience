//
//  AccountProfileTests.swift
//  AniXPlayerTests
//
//  账号资料请求模型、校验、关联状态与请求编码测试。
//

import Foundation
import XCTest

final class AccountProfileValidationTests: XCTestCase {

    func testScreenNameTrimsAndChecksLength() throws {
        XCTAssertEqual(try AccountProfileValidator.screenName("  Kaede  "), "Kaede")
        XCTAssertEqual(try AccountProfileValidator.screenName("a"), "a")
        XCTAssertEqual(try AccountProfileValidator.screenName(String(repeating: "a", count: 50)).count, 50)

        XCTAssertThrowsError(try AccountProfileValidator.screenName("   ")) { error in
            XCTAssertEqual(error as? AccountProfileValidationError, .emptyScreenName)
        }
        XCTAssertThrowsError(try AccountProfileValidator.screenName(String(repeating: "a", count: 51))) { error in
            XCTAssertEqual(error as? AccountProfileValidationError, .invalidScreenNameLength)
        }
    }

    func testEmailChangeValidation() throws {
        let values = try AccountProfileValidator.emailChange(
            old: " old@example.com ",
            new: " new@example.com "
        )
        XCTAssertEqual(values.old, "old@example.com")
        XCTAssertEqual(values.new, "new@example.com")

        XCTAssertThrowsError(try AccountProfileValidator.emailChange(old: "bad", new: "new@example.com")) {
            XCTAssertEqual($0 as? AccountProfileValidationError, .invalidOldEmail)
        }
        XCTAssertThrowsError(try AccountProfileValidator.emailChange(old: "old@example.com", new: "bad")) {
            XCTAssertEqual($0 as? AccountProfileValidationError, .invalidNewEmail)
        }
        XCTAssertThrowsError(try AccountProfileValidator.emailChange(
            old: "old@example.com",
            new: "OLD@example.com"
        )) {
            XCTAssertEqual($0 as? AccountProfileValidationError, .unchangedEmail)
        }
    }

    func testPasswordChangeValidation() throws {
        let values = try AccountProfileValidator.passwordChange(
            old: "12345",
            new: "abcdef",
            confirmation: "abcdef"
        )
        XCTAssertEqual(values.old, "12345")
        XCTAssertEqual(values.new, "abcdef")

        XCTAssertEqual(
            try AccountProfileValidator.passwordChange(
                old: String(repeating: "a", count: 20),
                new: String(repeating: "b", count: 20),
                confirmation: String(repeating: "b", count: 20)
            ).new.count,
            20
        )

        XCTAssertThrowsError(try AccountProfileValidator.passwordChange(
            old: "1234",
            new: "abcdef",
            confirmation: "abcdef"
        )) {
            XCTAssertEqual($0 as? AccountProfileValidationError, .invalidOldPassword)
        }
        XCTAssertThrowsError(try AccountProfileValidator.passwordChange(
            old: String(repeating: "a", count: 20),
            new: String(repeating: "b", count: 21),
            confirmation: String(repeating: "b", count: 21)
        )) {
            XCTAssertEqual($0 as? AccountProfileValidationError, .invalidNewPassword)
        }
        XCTAssertThrowsError(try AccountProfileValidator.passwordChange(
            old: "12345",
            new: "abc",
            confirmation: "abc"
        )) {
            XCTAssertEqual($0 as? AccountProfileValidationError, .invalidNewPassword)
        }
        XCTAssertThrowsError(try AccountProfileValidator.passwordChange(
            old: "12345",
            new: "abcdef",
            confirmation: "abcdeg"
        )) {
            XCTAssertEqual($0 as? AccountProfileValidationError, .passwordMismatch)
        }
        XCTAssertThrowsError(try AccountProfileValidator.passwordChange(
            old: "12345",
            new: "12345",
            confirmation: "12345"
        )) {
            XCTAssertEqual($0 as? AccountProfileValidationError, .unchangedPassword)
        }
    }
}

final class OAuthLinkedAccountTests: XCTestCase {

    func testDecodesBangumiAccount() throws {
        let json = """
        {
          "userId": 42,
          "userName": "kaede",
          "screenName": "Kaede",
          "email": "a@b.com",
          "emailVerified": true,
          "profileImage": "https://example.com/a.png",
          "privileges": { "member": "2099-01-01T00:00:00+08:00" },
          "linkedAccounts": {
            "bangumi": {
              "userId": "bgm-1",
              "userName": "bgm-user",
              "display": "BGM Display",
              "avatar": "https://example.com/bgm.png",
              "expires": "2099-02-03T04:05:06+08:00"
            }
          }
        }
        """

        let profile = try JSONDecoder().decode(OAuthUserProfile.self, from: Data(json.utf8))
        let account = try XCTUnwrap(profile.bangumiAccount)
        XCTAssertEqual(account.userId, "bgm-1")
        XCTAssertEqual(account.userName, "bgm-user")
        XCTAssertEqual(account.displayName, "BGM Display")
        XCTAssertEqual(account.avatar, "https://example.com/bgm.png")
        XCTAssertNotNil(account.expires)
        XCTAssertFalse(account.isExpired(now: Date(timeIntervalSince1970: 0)))
    }

    func testOldProfileWithoutLinkedAccountsStillDecodes() throws {
        let json = """
        {
          "userId": 7,
          "userName": "u",
          "screenName": "S",
          "emailVerified": false
        }
        """
        let profile = try JSONDecoder().decode(OAuthUserProfile.self, from: Data(json.utf8))
        XCTAssertNil(profile.linkedAccounts)
        XCTAssertNil(profile.bangumiAccount)
    }

    func testLinkedAccountToleratesMissingAndNumericFields() throws {
        let json = """
        {
          "linkedAccounts": {
            "bangumi": {
              "userId": 12345,
              "userName": "bgm"
            }
          }
        }
        """
        let profile = try JSONDecoder().decode(OAuthUserProfile.self, from: Data(json.utf8))
        let account = try XCTUnwrap(profile.bangumiAccount)
        XCTAssertEqual(account.userId, "12345")
        XCTAssertEqual(account.userName, "bgm")
        XCTAssertEqual(account.displayName, "bgm")
        XCTAssertNil(account.expires)
        XCTAssertFalse(account.isExpired())
    }

    func testBangumiLinkStatus() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(
            AccountBangumiLinkState(account: nil, now: now).status,
            .notLinked
        )
        XCTAssertTrue(AccountBangumiLinkState(account: nil, now: now).needsAuthorization)

        let active = OAuthLinkedAccount(
            expires: now.addingTimeInterval(3600)
        )
        XCTAssertEqual(
            AccountBangumiLinkState(account: active, now: now).status,
            .linked
        )
        XCTAssertFalse(AccountBangumiLinkState(account: active, now: now).needsAuthorization)

        let expired = OAuthLinkedAccount(
            expires: now.addingTimeInterval(-1)
        )
        XCTAssertEqual(
            AccountBangumiLinkState(account: expired, now: now).status,
            .expired
        )
        XCTAssertTrue(AccountBangumiLinkState(account: expired, now: now).needsAuthorization)
    }
}

final class AccountProfileServiceTests: XCTestCase {
    private var client: APIClient!
    private let environment = APIEnvironment(host: "https://api.dandanplay.net", clientId: "test-client")

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

    private func makeService() -> AccountProfileService {
        let authenticated = AuthenticatedAPIClient(
            client: client,
            tokenProvider: { "token-1" },
            refreshHandler: { "token-2" }
        )
        return AccountProfileService(environment: environment, client: authenticated)
    }

    private func bodyData(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: bufferSize)
            if count <= 0 { break }
            data.append(contentsOf: buffer[0..<count])
        }
        return data
    }

    func testScreenNameRequestUsesPostJSONAndBearer() async throws {
        var captured: URLRequest?
        StubURLProtocol.handler = { request in
            captured = request
            return (200, ["Content-Type": "application/json"], Data("{\"success\":true}".utf8))
        }

        try await makeService().updateScreenName("New Name")

        let request = try XCTUnwrap(captured)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/v2/user/profile")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-1")
        let body = try XCTUnwrap(bodyData(from: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(json, ["screenName": "New Name"])
    }

    func testEmailAndPasswordRequestEncoding() async throws {
        var bodies: [String: Any] = [:]
        StubURLProtocol.handler = { request in
            if let data = self.bodyData(from: request),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                bodies[request.url?.path ?? ""] = json
            }
            return (200, [:], Data())
        }

        let service = makeService()
        try await service.updateEmail(oldEmail: "old@example.com", newEmail: "new@example.com")
        try await service.updatePassword(oldPassword: "12345", newPassword: "abcdef")

        XCTAssertEqual(
            bodies["/api/v2/user/email"] as? [String: String],
            ["oldEmail": "old@example.com", "newEmail": "new@example.com"]
        )
        XCTAssertEqual(
            bodies["/api/v2/user/password"] as? [String: String],
            ["oldPassword": "12345", "newPassword": "abcdef"]
        )
    }

    func testServerFailureMessageIsPropagated() async {
        StubURLProtocol.handler = { _ in
            (200, ["Content-Type": "application/json"], Data("""
            {"success":false,"errorCode":1,"errorMessage":"旧密码错误"}
            """.utf8))
        }

        do {
            try await makeService().updatePassword(oldPassword: "12345", newPassword: "abcdef")
            XCTFail("expected error")
        } catch {
            XCTAssertEqual(error.localizedDescription, "旧密码错误")
        }
    }

    func testWebTokenAndEmailVerifyURL() async throws {
        var requestedURL: URL?
        StubURLProtocol.handler = { request in
            requestedURL = request.url
            return (200, ["Content-Type": "application/json"], Data("""
            {"success":true,"webToken":"token 1","business":"email_verify"}
            """.utf8))
        }

        let service = makeService()
        let token = try await service.fetchWebToken(business: AccountProfileBusiness.emailVerify)
        XCTAssertEqual(token, "token 1")

        let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(requestedURL), resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.path, "/api/v2/oauth/webToken")
        XCTAssertEqual(components.queryItems?.first { $0.name == "business" }?.value, "email_verify")

        let verifyURL = try XCTUnwrap(service.makeEmailVerificationURL(webToken: token))
        let verifyComponents = try XCTUnwrap(URLComponents(url: verifyURL, resolvingAgainstBaseURL: false))
        XCTAssertEqual(verifyComponents.path, "/api/v2/account/email/verify")
        XCTAssertEqual(verifyComponents.queryItems?.first { $0.name == "webToken" }?.value, "token 1")
    }

    func testBangumiAuthorizationAndManagementURLs() async throws {
        var requestedURL: URL?
        StubURLProtocol.handler = { request in
            requestedURL = request.url
            return (200, ["Content-Type": "application/json"], Data("""
            {"success":true,"state":"s","url":"https://bgm.tv/oauth/authorize?state=s"}
            """.utf8))
        }

        let service = makeService()
        let authorizationURL = try await service.fetchBangumiAuthorizationURL()
        XCTAssertEqual(authorizationURL.host, "bgm.tv")
        XCTAssertEqual(authorizationURL.path, "/oauth/authorize")

        let loginComponents = try XCTUnwrap(URLComponents(
            url: try XCTUnwrap(requestedURL),
            resolvingAgainstBaseURL: false
        ))
        XCTAssertEqual(loginComponents.path, "/api/v2/oauthprovider/bangumi/login")
        XCTAssertEqual(loginComponents.queryItems?.first { $0.name == "redirectUrl" }?.value, "")

        let managementURL = try XCTUnwrap(service.makeBangumiManagementURL(webToken: "manage token"))
        let managementComponents = try XCTUnwrap(URLComponents(
            url: managementURL,
            resolvingAgainstBaseURL: false
        ))
        XCTAssertEqual(managementComponents.path, "/api/v2/oauthprovider/bangumi/manage")
        XCTAssertEqual(managementComponents.queryItems?.first { $0.name == "webToken" }?.value, "manage token")
    }

    func testMissingWebTokenThrows() async {
        StubURLProtocol.handler = { _ in
            (200, ["Content-Type": "application/json"], Data("{\"success\":true}".utf8))
        }

        do {
            _ = try await makeService().fetchWebToken(business: AccountProfileBusiness.oauthBangumi)
            XCTFail("expected error")
        } catch AccountProfileServiceError.missingWebToken {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
