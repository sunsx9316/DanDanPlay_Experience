//
//  MarkdownTextView.swift
//  AniXPlayer
//
//  macOS only：可点击链接的 Markdown 文本视图。
//  与 MarkdownRenderer 一起供会员权益说明和 AI 视频总结使用。
//

import AppKit

final class MarkdownTextView: NSTextView, NSTextViewDelegate {

    /// 点击时间戳链接时优先交给外部处理（例如播放器跳转）；返回 true 表示已处理。
    /// 未设置或返回 false 时复制时间戳到剪贴板，链接仍然可点击。
    var onTimestampActivated: ((_ timestamp: String, _ seconds: TimeInterval) -> Bool)?

    private(set) var markdown = ""

    private let renderStyle = MarkdownRenderer.Style()

    // MARK: - Init

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        commonInit()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    convenience init() {
        self.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        isEditable = false
        isSelectable = true
        isRichText = true
        drawsBackground = false
        backgroundColor = .clear
        isAutomaticLinkDetectionEnabled = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false

        textContainerInset = NSSize(width: 0, height: 6)
        minSize = .zero
        maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        isHorizontallyResizable = false
        isVerticallyResizable = true
        autoresizingMask = [.width]
        textContainer?.widthTracksTextView = true
        textContainer?.lineFragmentPadding = 0
        textContainer?.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )

        delegate = self
        linkTextAttributes = [
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .cursor: NSCursor.pointingHand
        ]
    }

    // MARK: - Content

    func setMarkdown(_ markdown: String, skipsLeadingH1: Bool = false) {
        self.markdown = markdown
        let options = MarkdownRenderer.Options(
            style: renderStyle,
            skipsLeadingH1: skipsLeadingH1
        )
        let rendered = MarkdownRenderer.render(markdown, options: options)
        let normalized = NSMutableAttributedString(attributedString: rendered)

        // 渲染器已把纯时间戳转成自定义协议；这里兜底处理仍然使用相对 URL 的时间戳，
        // 保证 NSTextView 能稳定识别为可点击链接。
        let fullRange = NSRange(location: 0, length: normalized.length)
        normalized.enumerateAttribute(.link, in: fullRange) { value, range, _ in
            guard let url = value as? URL, url.scheme == nil,
                  let timestamp = Self.timestampLink(from: url),
                  let customURL = URL(string: "anix-timestamp://seek?t=\(Int(timestamp.seconds))") else {
                return
            }
            normalized.addAttribute(.link, value: customURL, range: range)
        }

        textStorage?.setAttributedString(normalized)

        // 文本变化后立即重算滚动区文档高度；宽度未知时等下一次 layout。
        if let markdownScrollView = enclosingScrollView as? MarkdownScrollView {
            markdownScrollView.fitDocument()
        } else {
            enclosingScrollView?.needsLayout = true
        }
    }

    func setPlainText(_ text: String, color: NSColor? = nil) {
        markdown = ""
        let rendered = MarkdownRenderer.plainText(text, style: renderStyle, color: color)
        textStorage?.setAttributedString(rendered)
        if let markdownScrollView = enclosingScrollView as? MarkdownScrollView {
            markdownScrollView.fitDocument()
        }
    }

    /// 当前宽度下文本所需高度，供滚动容器自适应。
    func documentHeight(forWidth width: CGFloat) -> CGFloat {
        guard width > 0, let textStorage = textStorage else {
            return 0
        }

        let copiedStorage = NSTextStorage(attributedString: textStorage)
        let container = NSTextContainer(
            size: NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        )
        container.lineFragmentPadding = textContainer?.lineFragmentPadding ?? 0
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(container)
        copiedStorage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: container)

        let usedRect = layoutManager.usedRect(for: container)
        return ceil(usedRect.height + textContainerInset.height * 2)
    }

    // MARK: - Links

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        guard let url = Self.url(from: link) else { return false }
        return openLink(url)
    }

    @discardableResult
    func openLink(_ url: URL) -> Bool {
        if let timestamp = Self.timestampLink(from: url) {
            if onTimestampActivated?(timestamp.text, timestamp.seconds) == true {
                return true
            }
            copyToPasteboard(timestamp.text)
            return true
        }

        if NSWorkspace.shared.open(url) {
            return true
        }

        // 相对链接或无法打开的自定义协议：保留可点击行为，复制原文避免点击无反应。
        copyToPasteboard(url.absoluteString)
        return true
    }

    // MARK: - Timestamp parsing

    struct TimestampLink: Equatable {
        let text: String
        let seconds: TimeInterval
    }

    /// 支持 `00:12`、`01:02:03`、`anix-timestamp://seek?t=72`。
    static func timestampLink(from url: URL) -> TimestampLink? {
        if url.scheme?.lowercased() == "anix-timestamp" {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let value = components.queryItems?.first(where: { $0.name == "t" })?.value,
               let seconds = TimeInterval(value) {
                return TimestampLink(text: displayTime(seconds), seconds: seconds)
            }
        }

        return timestampLink(fromRawString: url.absoluteString)
    }

    static func timestampLink(fromRawString raw: String) -> TimestampLink? {
        guard let seconds = MarkdownRenderer.timestampSeconds(from: raw) else { return nil }
        return TimestampLink(
            text: raw.trimmingCharacters(in: .whitespacesAndNewlines),
            seconds: seconds
        )
    }

    private static func displayTime(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    private static func url(from link: Any) -> URL? {
        if let url = link as? URL {
            return url
        }
        if let string = link as? String {
            return URL(string: string)
        }
        return nil
    }

    private func copyToPasteboard(_ string: String) {
        guard !string.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
}

// MARK: - Scroll container

/// 让 MarkdownTextView 的宽度跟随滚动区、正文高度随内容增长。
final class MarkdownScrollView: NSScrollView {
    let markdownTextView: MarkdownTextView

    init(textView: MarkdownTextView) {
        self.markdownTextView = textView
        super.init(frame: .zero)
        // 由 MarkdownScrollView 统一计算文档高度，避免 NSTextView 在滚动容器里
        // 自行收缩到不包含段间距的高度。
        textView.isVerticallyResizable = false
        hasVerticalScroller = true
        hasHorizontalScroller = false
        scrollerStyle = .overlay
        drawsBackground = false
        borderType = .noBorder
        documentView = textView
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        fitDocument()
    }

    func fitDocument() {
        let width = contentSize.width
        guard width > 0 else { return }

        var frame = markdownTextView.frame
        frame.size.width = width
        let height = markdownTextView.documentHeight(forWidth: width)
        frame.size.height = max(height, contentSize.height)
        if frame != markdownTextView.frame {
            markdownTextView.frame = frame
        }
    }
}
