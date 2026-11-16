import XCTest

final class FileRefreshTokenStoreTests: XCTestCase {
    private var directoryURL: URL!
    private var fileURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AniXPlayerTokenTests-\(UUID().uuidString)", isDirectory: true)
        fileURL = directoryURL.appendingPathComponent("oauth.refresh_token")
    }

    override func tearDownWithError() throws {
        if let directoryURL = directoryURL {
            try? FileManager.default.removeItem(at: directoryURL)
        }
        try super.tearDownWithError()
    }

    func testSaveReadOverwriteAndDelete() throws {
        let store = FileRefreshTokenStore(fileURL: fileURL)
        XCTAssertNil(try store.readRefreshToken())

        try store.saveRefreshToken("token-1")
        XCTAssertEqual(try store.readRefreshToken(), "token-1")

        try store.saveRefreshToken("token-2")
        XCTAssertEqual(try store.readRefreshToken(), "token-2")

        try store.deleteRefreshToken()
        XCTAssertNil(try store.readRefreshToken())
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testSavedFileHasOwnerOnlyPermissions() throws {
        let store = FileRefreshTokenStore(fileURL: fileURL)
        try store.saveRefreshToken("secret")

        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let permissions = (attributes[.posixPermissions] as? NSNumber)?.intValue ?? 0
        XCTAssertEqual(permissions & 0o777, 0o600)
    }

    func testEmptyTokenIsRejected() {
        let store = FileRefreshTokenStore(fileURL: fileURL)
        XCTAssertThrowsError(try store.saveRefreshToken(""))
    }

    func testFactoryHonorsEnvironmentOverride() {
        XCTAssertTrue(
            RefreshTokenStoreFactory.makeDefault(environment: ["ANIX_TOKEN_STORE": "file"])
                is FileRefreshTokenStore
        )
        XCTAssertTrue(
            RefreshTokenStoreFactory.makeDefault(environment: ["ANIX_TOKEN_STORE": "keychain"])
                is KeychainRefreshTokenStore
        )
    }
}
