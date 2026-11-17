import XCTest

final class OnlineDanmakuMatchTests: XCTestCase {

    func testKeywordJoinsSubjectAndEpisode() {
        XCTAssertEqual(
            OnlineDanmakuMatchQuery.keyword(subjectTitle: "葬送的芙莉莲", episodeTitle: "第1话"),
            "葬送的芙莉莲 第1话"
        )
    }

    func testKeywordTrimsEmptyParts() {
        XCTAssertEqual(
            OnlineDanmakuMatchQuery.keyword(subjectTitle: "", episodeTitle: "第1话"),
            "第1话"
        )
        XCTAssertEqual(
            OnlineDanmakuMatchQuery.keyword(subjectTitle: "作品", episodeTitle: "  "),
            "作品"
        )
        XCTAssertEqual(
            OnlineDanmakuMatchQuery.keyword(subjectTitle: "  ", episodeTitle: " "),
            ""
        )
    }

    func testNormalizeRemovesOnlyTrailingMP4() {
        XCTAssertEqual(
            OnlineDanmakuMatchQuery.normalizeVirtualName("作品 第1话.mp4"),
            "作品 第1话"
        )
        XCTAssertEqual(
            OnlineDanmakuMatchQuery.normalizeVirtualName("作品 第1话.MP4"),
            "作品 第1话"
        )
        XCTAssertEqual(
            OnlineDanmakuMatchQuery.normalizeVirtualName("作品 第1.5话"),
            "作品 第1.5话"
        )
        XCTAssertEqual(
            OnlineDanmakuMatchQuery.normalizeVirtualName("作品.mp4 第1话"),
            "作品.mp4 第1话"
        )
    }

    func testNormalizeTrimsWhitespace() {
        XCTAssertEqual(
            OnlineDanmakuMatchQuery.normalizeVirtualName("  作品 第1话.mp4  "),
            "作品 第1话"
        )
    }
}
