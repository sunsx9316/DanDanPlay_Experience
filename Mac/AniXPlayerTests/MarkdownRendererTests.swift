//
//  MarkdownRendererTests.swift
//  AniXPlayerTests
//
//  无宿主单元测试：Markdown 解析为 NSAttributedString 的纯逻辑结果。
//

import AppKit
import XCTest

final class MarkdownRendererTests: XCTestCase {

    private func render(_ markdown: String, skipsLeadingH1: Bool = false) -> NSAttributedString {
        MarkdownRenderer.render(
            markdown,
            options: MarkdownRenderer.Options(skipsLeadingH1: skipsLeadingH1)
        )
    }

    private func attributes(
        in attributed: NSAttributedString,
        at substring: String
    ) -> [NSAttributedString.Key: Any]? {
        let range = (attributed.string as NSString).range(of: substring)
        guard range.location != NSNotFound else { return nil }
        return attributed.attributes(at: range.location, effectiveRange: nil)
    }

    // MARK: - Headings

    func testHeadingsAreNonEmptyAndStyled() {
        let attributed = render("# 一级标题\n\n## 二级标题\n\n### 三级标题")

        XCTAssertFalse(attributed.string.isEmpty)
        XCTAssertTrue(attributed.string.contains("一级标题"))
        XCTAssertTrue(attributed.string.contains("二级标题"))
        XCTAssertTrue(attributed.string.contains("三级标题"))
        XCTAssertFalse(attributed.string.contains("# 一级标题"))

        guard let h1Font = attributes(in: attributed, at: "一级标题")?[.font] as? NSFont else {
            return XCTFail("H1 缺少字体属性")
        }
        XCTAssertGreaterThan(h1Font.pointSize, 17)
        XCTAssertTrue(h1Font.fontDescriptor.symbolicTraits.contains(.bold))

        guard let h2Font = attributes(in: attributed, at: "二级标题")?[.font] as? NSFont else {
            return XCTFail("H2 缺少字体属性")
        }
        XCTAssertGreaterThan(h2Font.pointSize, 13)
        XCTAssertLessThan(h2Font.pointSize, h1Font.pointSize)
    }

    func testLeadingH1CanBeSkippedForMembershipWindow() {
        let markdown = "# 弹弹play会员\n\n## 权益\n\n- **无广告**播放"

        let skipped = render(markdown, skipsLeadingH1: true)
        XCTAssertFalse(skipped.string.contains("弹弹play会员"))
        XCTAssertTrue(skipped.string.contains("权益"))
        XCTAssertTrue(skipped.string.contains("无广告"))

        let kept = render(markdown)
        XCTAssertTrue(kept.string.contains("弹弹play会员"))
    }

    // MARK: - Inline styles

    func testBoldItalicAndInlineCodeKeepStyles() {
        let attributed = render("这是 **粗体** 与 *斜体*，以及 `let value = 1`。")

        XCTAssertFalse(attributed.string.isEmpty)
        XCTAssertTrue(attributed.string.contains("粗体"))
        XCTAssertTrue(attributed.string.contains("斜体"))
        XCTAssertFalse(attributed.string.contains("**"))
        XCTAssertFalse(attributed.string.contains("`"))

        guard let boldFont = attributes(in: attributed, at: "粗体")?[.font] as? NSFont else {
            return XCTFail("粗体缺少字体属性")
        }
        XCTAssertTrue(boldFont.fontDescriptor.symbolicTraits.contains(.bold))

        guard let italicFont = attributes(in: attributed, at: "斜体")?[.font] as? NSFont else {
            return XCTFail("斜体缺少字体属性")
        }
        XCTAssertTrue(italicFont.fontDescriptor.symbolicTraits.contains(.italic))

        let codeAttributes = attributes(in: attributed, at: "let value = 1")
        guard let codeFont = codeAttributes?[.font] as? NSFont else {
            return XCTFail("行内代码缺少字体属性")
        }
        XCTAssertTrue(codeFont.isFixedPitch)
        XCTAssertNotNil(codeAttributes?[.backgroundColor])
    }

    // MARK: - Lists and quotes

    func testUnorderedAndOrderedListsAreRendered() {
        let attributed = render("- 第一项\n- 第二项\n\n1. 步骤一\n2. 步骤二")

        XCTAssertFalse(attributed.string.isEmpty)
        XCTAssertTrue(attributed.string.contains("第一项"))
        XCTAssertTrue(attributed.string.contains("第二项"))
        XCTAssertTrue(attributed.string.contains("步骤一"))
        XCTAssertTrue(attributed.string.contains("步骤二"))
        XCTAssertEqual(
            attributed.string.components(separatedBy: "•").count - 1,
            2,
            "无序列表应渲染两个项目符号"
        )
        XCTAssertTrue(attributed.string.contains("1."))
        XCTAssertTrue(attributed.string.contains("2."))
    }

    func testBlockquoteAndParagraphSpacing() {
        let attributed = render("第一段\n\n> 这是一段引用\n\n第二段")

        XCTAssertTrue(attributed.string.contains("│"))
        XCTAssertTrue(attributed.string.contains("这是一段引用"))

        guard let paragraph = attributes(in: attributed, at: "第一段")?[.paragraphStyle] as? NSParagraphStyle else {
            return XCTFail("段落缺少 paragraphStyle")
        }
        XCTAssertGreaterThan(paragraph.paragraphSpacing, 0)
    }

    // MARK: - Links

    func testLinksKeepLinkAttribute() {
        let attributed = render("[官网](https://www.dandanplay.com) 和 [00:12](00:12) 处")

        XCTAssertFalse(attributed.string.isEmpty)
        XCTAssertTrue(attributed.string.contains("官网"))
        XCTAssertTrue(attributed.string.contains("00:12"))
        XCTAssertFalse(attributed.string.contains("]("))

        guard let officialLink = attributes(in: attributed, at: "官网")?[.link] as? URL else {
            return XCTFail("普通链接缺少 link 属性")
        }
        XCTAssertEqual(officialLink.absoluteString, "https://www.dandanplay.com")

        let timestampLink = attributes(in: attributed, at: "00:12")?[.link] as? URL
        XCTAssertNotNil(timestampLink, "时间戳链接必须保留 link 属性")
        XCTAssertEqual(timestampLink?.scheme, "anix-timestamp")
        XCTAssertTrue(timestampLink?.absoluteString.contains("t=12") == true)

        XCTAssertEqual(MarkdownRenderer.timestampSeconds(from: "00:12"), 12)
        XCTAssertEqual(MarkdownRenderer.timestampSeconds(from: "01:02:03"), 3723)
        XCTAssertNil(MarkdownRenderer.timestampSeconds(from: "https://www.dandanplay.com"))
    }

    func testLinkDestinationWithParentheses() {
        let attributed = render("[维基](https://en.wikipedia.org/wiki/Foo_(bar))")

        guard let link = attributes(in: attributed, at: "维基")?[.link] as? URL else {
            return XCTFail("带括号的链接缺少 link 属性")
        }
        XCTAssertEqual(link.absoluteString, "https://en.wikipedia.org/wiki/Foo_(bar)")
    }

    func testSummaryMarkdownTimestampRemainsLink() {
        let markdown = SummaryMarkdown.make(
            summary: "本集讲述主角的冒险。",
            topics: [
                SummaryTopic(
                    order: 1,
                    title: "开场",
                    parts: [
                        SummaryTopicPart(start: "01:23", content: "主角出发。")
                    ]
                )
            ]
        )

        let attributed = render(markdown)
        XCTAssertTrue(attributed.string.contains("01:23"))
        XCTAssertFalse(attributed.string.contains("]("))
        XCTAssertNotNil(
            attributes(in: attributed, at: "01:23")?[.link],
            "总结里的时间戳必须保留 link 属性"
        )
    }

    // MARK: - Fallback

    func testMalformedMarkdownDoesNotCrashOrBecomeEmpty() {
        let malformed = "未闭合的 **粗体、[链接]( 与 `代码"
        let attributed = render(malformed)

        XCTAssertFalse(attributed.string.isEmpty)
        XCTAssertTrue(attributed.string.contains("未闭合的"))
        XCTAssertGreaterThan(attributed.length, 0)
    }

    func testEmptyInputReturnsEmptyAttributedString() {
        XCTAssertEqual(render("").length, 0)
        XCTAssertEqual(render("   \n\n").length, 0)
    }
}
