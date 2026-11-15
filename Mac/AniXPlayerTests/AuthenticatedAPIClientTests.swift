import XCTest

final class AuthenticatedAPIClientTests: XCTestCase {
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

    func testInjectsBearerToken() async throws {
        var seenAuthorization: String?
        StubURLProtocol.handler = { request in
            seenAuthorization = request.value(forHTTPHeaderField: "Authorization")
            return (200, [:], Data("{}".utf8))
        }

        let api = AuthenticatedAPIClient(
            client: client,
            tokenProvider: { "token-1" },
            refreshHandler: { "token-2" }
        )
        let request = URLRequest(url: URL(string: "https://example.com/user/me")!)
        let _: Data = try await api.send(request)

        XCTAssertEqual(seenAuthorization, "Bearer token-1")
    }

    func testRetriesOnceAfter401() async throws {
        var callCount = 0
        var authorizations: [String] = []

        StubURLProtocol.handler = { request in
            callCount += 1
            authorizations.append(request.value(forHTTPHeaderField: "Authorization") ?? "")
            if callCount == 1 {
                return (401, [:], Data())
            }
            return (200, [:], Data("{\"ok\":true}".utf8))
        }

        var refreshCount = 0
        let api = AuthenticatedAPIClient(
            client: client,
            tokenProvider: { "old-token" },
            refreshHandler: {
                refreshCount += 1
                return "new-token"
            }
        )
        let request = URLRequest(url: URL(string: "https://example.com/user/me")!)
        let _: Data = try await api.send(request)

        XCTAssertEqual(callCount, 2)
        XCTAssertEqual(refreshCount, 1)
        XCTAssertEqual(authorizations, ["Bearer old-token", "Bearer new-token"])
    }

    func testDoesNotRetryMoreThanOnce() async {
        var callCount = 0
        StubURLProtocol.handler = { _ in
            callCount += 1
            return (401, [:], Data())
        }

        var refreshCount = 0
        let api = AuthenticatedAPIClient(
            client: client,
            tokenProvider: { "old-token" },
            refreshHandler: {
                refreshCount += 1
                return "new-token"
            }
        )
        let request = URLRequest(url: URL(string: "https://example.com/user/me")!)

        do {
            let _: Data = try await api.send(request)
            XCTFail("expected error")
        } catch let error as APIError {
            XCTAssertTrue(error.isUnauthorized)
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        XCTAssertEqual(callCount, 2)
        XCTAssertEqual(refreshCount, 1)
    }

    func testTokenProviderFailureDoesNotSendRequest() async {
        var callCount = 0
        StubURLProtocol.handler = { _ in
            callCount += 1
            return (200, [:], Data())
        }

        let api = AuthenticatedAPIClient(
            client: client,
            tokenProvider: { throw APIError.unauthorized },
            refreshHandler: { "new-token" }
        )
        let request = URLRequest(url: URL(string: "https://example.com/user/me")!)

        do {
            let _: Data = try await api.send(request)
            XCTFail("expected error")
        } catch let error as APIError {
            XCTAssertTrue(error.isUnauthorized)
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        XCTAssertEqual(callCount, 0)
    }
}
