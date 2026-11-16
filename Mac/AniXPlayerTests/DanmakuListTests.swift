//
//  DanmakuListTests.swift
//  AniXPlayerTests
//
//  macOS 弹幕列表：时间解析、排序、搜索与屏蔽状态（纯逻辑）。
//

import XCTest

final class DanmakuListTests: XCTestCase {

    private func makeEntry(
        time: TimeInterval,
        text: String,
        isFiltered: Bool = false,
        userId: String = "1",
        source: String = "dandanplay",
        commentId: Int = 1
    ) -> DanmakuListEntry {
        return DanmakuListEntry(
            time: time,
            text: text,
            isFiltered: isFiltered,
            userId: userId,
            source: source,
            commentId: commentId
        )
    }

    // MARK: - 时间

    func testResolvedTimePrefersOriginAppearTime() {
        XCTAssertEqual(
            DanmakuListLogic.resolvedTime(originAppearTime: 12.5, rawCommentTime: 5, appearTime: 3),
            12.5
        )
        XCTAssertEqual(
            DanmakuListLogic.resolvedTime(originAppearTime: nil, rawCommentTime: 5, appearTime: 3),
            5
        )
        XCTAssertEqual(
            DanmakuListLogic.resolvedTime(originAppearTime: nil, rawCommentTime: nil, appearTime: 3),
            3
        )
        XCTAssertEqual(
            DanmakuListLogic.resolvedTime(originAppearTime: nil, rawCommentTime: nil, appearTime: nil),
            0
        )
    }

    func testFormattedTime() {
        XCTAssertEqual(DanmakuListLogic.formattedTime(0), "00:00")
        XCTAssertEqual(DanmakuListLogic.formattedTime(5.9), "00:05")
        XCTAssertEqual(DanmakuListLogic.formattedTime(59.99), "00:59")
        XCTAssertEqual(DanmakuListLogic.formattedTime(60), "01:00")
        XCTAssertEqual(DanmakuListLogic.formattedTime(3_599), "59:59")
        XCTAssertEqual(DanmakuListLogic.formattedTime(3_600), "1:00:00")
        XCTAssertEqual(DanmakuListLogic.formattedTime(3_661), "1:01:01")
        XCTAssertEqual(DanmakuListLogic.formattedTime(-5), "00:00")
    }

    // MARK: - 排序

    func testSortedByTimeAndKeepsOriginalOrderForTies() {
        let entries = [
            makeEntry(time: 5, text: "first"),
            makeEntry(time: 1, text: "early"),
            makeEntry(time: 5, text: "second"),
            makeEntry(time: 3, text: "middle")
        ]

        let sorted = DanmakuListLogic.sorted(entries)
        XCTAssertEqual(sorted.map { $0.text }, ["early", "middle", "first", "second"])
    }

    // MARK: - 搜索

    func testSearchedEmptyKeywordReturnsAll() {
        let entries = [
            makeEntry(time: 1, text: "hello"),
            makeEntry(time: 2, text: "world")
        ]

        XCTAssertEqual(DanmakuListLogic.searched(entries, text: "").count, 2)
        XCTAssertEqual(DanmakuListLogic.searched(entries, text: "   ").count, 2)
    }

    func testSearchedIsCaseAndDiacriticInsensitive() {
        let entries = [
            makeEntry(time: 1, text: "Hello World"),
            makeEntry(time: 2, text: "Café"),
            makeEntry(time: 3, text: "其他内容")
        ]

        XCTAssertEqual(DanmakuListLogic.searched(entries, text: "hello").map { $0.text }, ["Hello World"])
        XCTAssertEqual(DanmakuListLogic.searched(entries, text: "CAFE").map { $0.text }, ["Café"])
    }

    func testSearchedNoMatch() {
        let entries = [makeEntry(time: 1, text: "hello")]
        XCTAssertTrue(DanmakuListLogic.searched(entries, text: "missing").isEmpty)
    }

    // MARK: - 屏蔽

    func testMatchesFilterExactAndRegex() {
        let exact = DanmakuListFilterRule(
            text: "前排",
            isRegularExpression: false,
            isEnabled: true
        )
        XCTAssertTrue(DanmakuListLogic.matchesFilter(text: "前排", rules: [exact]))
        XCTAssertFalse(DanmakuListLogic.matchesFilter(text: "前排！", rules: [exact]))

        let regex = DanmakuListFilterRule(
            text: "^哈+$",
            isRegularExpression: true,
            isEnabled: true
        )
        XCTAssertTrue(DanmakuListLogic.matchesFilter(text: "哈哈哈", rules: [regex]))
        XCTAssertFalse(DanmakuListLogic.matchesFilter(text: "哈哈a", rules: [regex]))
    }

    func testMatchesFilterSkipsDisabledRules() {
        let disabled = DanmakuListFilterRule(
            text: "广告",
            isRegularExpression: false,
            isEnabled: false
        )
        XCTAssertFalse(DanmakuListLogic.matchesFilter(text: "广告", rules: [disabled]))
    }

    func testPreparedAppliesFilterRulesAndKeepsExistingFilteredState() {
        let entries = [
            makeEntry(time: 3, text: "广告", isFiltered: false),
            makeEntry(time: 1, text: "前排", isFiltered: true),
            makeEntry(time: 2, text: "普通弹幕", isFiltered: false)
        ]
        let rules = [
            DanmakuListFilterRule(text: "广告", isRegularExpression: false, isEnabled: true)
        ]

        let prepared = DanmakuListLogic.prepared(entries, filterRules: rules)
        XCTAssertEqual(prepared.map { $0.text }, ["前排", "普通弹幕", "广告"])
        XCTAssertEqual(prepared.filter { $0.isFiltered }.map { $0.text }, ["前排", "广告"])
        XCTAssertEqual(DanmakuListLogic.filteredCount(prepared), 2)
    }
}
