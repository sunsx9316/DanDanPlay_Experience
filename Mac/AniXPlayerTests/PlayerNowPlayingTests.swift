import XCTest

final class PlayerNowPlayingTests: XCTestCase {

    func testEmptyStateHasNoMediaAndZeroProgress() {
        let state = PlayerNowPlayingState.empty

        XCTAssertFalse(state.hasMedia)
        XCTAssertEqual(state.progress, 0)
        XCTAssertFalse(state.isPlaying)
    }

    func testProgressClampsToPlayableRange() {
        var state = PlayerNowPlayingState.empty
        state.title = "Test"
        state.duration = 100

        state.position = 25
        XCTAssertEqual(state.progress, 0.25, accuracy: 0.0001)

        state.position = -10
        XCTAssertEqual(state.progress, 0, accuracy: 0.0001)

        state.position = 150
        XCTAssertEqual(state.progress, 1, accuracy: 0.0001)

        state.duration = 0
        XCTAssertEqual(state.progress, 0, accuracy: 0.0001)
    }

    func testTimeThrottlePublishesAtMostOncePerSecond() {
        var throttle = PlayerNowPlayingTimeThrottle(interval: 1, seekThreshold: 2)

        XCTAssertTrue(throttle.shouldPublish(position: 0, now: 10))
        XCTAssertFalse(throttle.shouldPublish(position: 0.5, now: 10.4))
        XCTAssertFalse(throttle.shouldPublish(position: 0.9, now: 10.9))
        XCTAssertTrue(throttle.shouldPublish(position: 1.1, now: 11.0))
    }

    func testTimeThrottlePublishesSeeksImmediately() {
        var throttle = PlayerNowPlayingTimeThrottle(interval: 1, seekThreshold: 2)

        XCTAssertTrue(throttle.shouldPublish(position: 10, now: 20))
        XCTAssertFalse(throttle.shouldPublish(position: 10.2, now: 20.2))
        XCTAssertTrue(throttle.shouldPublish(position: 30, now: 20.3))
    }

    func testTimeThrottleResetAllowsNextPublish() {
        var throttle = PlayerNowPlayingTimeThrottle(interval: 1, seekThreshold: 2)

        XCTAssertTrue(throttle.shouldPublish(position: 5, now: 30))
        XCTAssertFalse(throttle.shouldPublish(position: 5.5, now: 30.2))

        throttle.reset()
        XCTAssertTrue(throttle.shouldPublish(position: 5.6, now: 30.3))
    }
}
