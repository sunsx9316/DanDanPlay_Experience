//
//  SummaryViewController.swift
//  AniXPlayer
//
//  macOS only：AI 视频总结窗口内容。
//

import Cocoa
import SnapKit
import UniformTypeIdentifiers
import ANXLog

final class SummaryViewController: ViewController {
    typealias AccessCheck = () async -> Bool

    // MARK: - Dependencies

    private let accessCheck: AccessCheck
    private let service: AISummaryService
    private let cache: SummaryCache

    // MARK: - State

    private var videoURL: URL?
    private var subtitleURL: URL?
    private var fileHash = ""
    private var hashTask: Task<Void, Never>?
    private var generationTask: Task<Void, Never>?
    private var generatedMarkdown = ""
    private var isGenerating = false

    // MARK: - UI

    private lazy var videoPathField: TextField = {
        let field = TextField()
        field.isEditable = false
        field.isSelectable = true
        field.placeholderString = NSLocalizedString("可选，用于缓存与文件校验", comment: "")
        field.lineBreakMode = .byTruncatingMiddle
        field.setAccessibilityIdentifier(AccessibilityID.Summary.videoField)
        return field
    }()

    private lazy var subtitlePathField: TextField = {
        let field = TextField()
        field.isEditable = false
        field.isSelectable = true
        field.placeholderString = NSLocalizedString("必选，支持 .srt / .ass / .ssa", comment: "")
        field.lineBreakMode = .byTruncatingMiddle
        field.setAccessibilityIdentifier(AccessibilityID.Summary.subtitleField)
        return field
    }()

    private lazy var titleField: TextField = {
        let field = TextField()
        field.placeholderString = NSLocalizedString("视频标题（可选）", comment: "")
        field.setAccessibilityIdentifier(AccessibilityID.Summary.titleField)
        return field
    }()

    private lazy var videoSubtitleField: TextField = {
        let field = TextField()
        field.placeholderString = NSLocalizedString("本集标题（可选）", comment: "")
        field.setAccessibilityIdentifier(AccessibilityID.Summary.videoSubtitleField)
        return field
    }()

    private lazy var chooseVideoButton: Button = {
        let button = Button(
            title: NSLocalizedString("选择…", comment: ""),
            target: self,
            action: #selector(chooseVideoFile)
        )
        button.bezelStyle = .rounded
        button.setAccessibilityIdentifier(AccessibilityID.Summary.chooseVideoButton)
        return button
    }()

    private lazy var chooseSubtitleButton: Button = {
        let button = Button(
            title: NSLocalizedString("选择…", comment: ""),
            target: self,
            action: #selector(chooseSubtitleFile)
        )
        button.bezelStyle = .rounded
        button.setAccessibilityIdentifier(AccessibilityID.Summary.chooseSubtitleButton)
        return button
    }()

    private lazy var textView: MarkdownTextView = {
        let textView = MarkdownTextView()
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.setAccessibilityIdentifier(AccessibilityID.Summary.textView)
        return textView
    }()

    private lazy var scrollView: MarkdownScrollView = {
        let scrollView = MarkdownScrollView(textView: textView)
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        return scrollView
    }()

    private lazy var statusLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setAccessibilityIdentifier(AccessibilityID.Summary.statusLabel)
        return label
    }()

    private lazy var quotaLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.alignment = .right
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setAccessibilityIdentifier(AccessibilityID.Summary.quotaLabel)
        return label
    }()

    private lazy var progressIndicator: NSProgressIndicator = {
        let indicator = NSProgressIndicator()
        indicator.style = .spinning
        indicator.controlSize = .small
        indicator.isDisplayedWhenStopped = false
        indicator.isHidden = true
        return indicator
    }()

    private lazy var copyButton: Button = {
        let button = Button(
            title: NSLocalizedString("复制结果", comment: ""),
            target: self,
            action: #selector(copyResult)
        )
        button.bezelStyle = .rounded
        button.isEnabled = false
        button.setAccessibilityIdentifier(AccessibilityID.Summary.copyButton)
        return button
    }()

    private lazy var generateButton: Button = {
        let button = Button(
            title: NSLocalizedString("生成总结", comment: ""),
            target: self,
            action: #selector(generateSummary)
        )
        button.bezelStyle = .rounded
        button.keyEquivalent = "\r"
        button.font = .systemFont(ofSize: 14, weight: .medium)
        button.setAccessibilityIdentifier(AccessibilityID.Summary.generateButton)
        return button
    }()

    private lazy var footerStack: NSStackView = {
        let statusRow = NSStackView(views: [statusLabel, progressIndicator])
        statusRow.orientation = .horizontal
        statusRow.alignment = .centerY
        statusRow.spacing = 8

        let statusSpacer = NSView()
        statusSpacer.setContentHuggingPriority(.fittingSizeCompression, for: .horizontal)
        statusSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let topRow = NSStackView(views: [statusRow, statusSpacer, quotaLabel])
        topRow.orientation = .horizontal
        topRow.alignment = .centerY
        topRow.spacing = 8
        statusRow.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let buttonSpacer = NSView()
        buttonSpacer.setContentHuggingPriority(.fittingSizeCompression, for: .horizontal)
        buttonSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let bottomRow = NSStackView(views: [buttonSpacer, copyButton, generateButton])
        bottomRow.orientation = .horizontal
        bottomRow.alignment = .centerY
        bottomRow.spacing = 10

        let stack = NSStackView(views: [topRow, bottomRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10

        topRow.snp.makeConstraints { make in
            make.width.equalTo(stack.snp.width)
        }
        bottomRow.snp.makeConstraints { make in
            make.width.equalTo(stack.snp.width)
        }
        return stack
    }()

    // MARK: - Init

    init(
        accessCheck: @escaping AccessCheck = { true },
        service: AISummaryService = AISummaryService(),
        cache: SummaryCache = SummaryCache()
    ) {
        self.accessCheck = accessCheck
        self.service = service
        self.cache = cache
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        hashTask?.cancel()
        generationTask?.cancel()
    }

    // MARK: - Lifecycle

    override func loadView() {
        self.view = BaseView(frame: NSRect(x: 0, y: 0, width: 760, height: 640))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = NSLocalizedString("AI 视频总结", comment: "")
        self.view.setAccessibilityIdentifier(AccessibilityID.Summary.window)
        setupUI()
        showPlaceholder()
        statusLabel.stringValue = NSLocalizedString("选择字幕文件后生成总结", comment: "")
    }

    func cancelPendingWork() {
        hashTask?.cancel()
        generationTask?.cancel()
    }

    // MARK: - UI Setup

    private func setupUI() {
        // 时间戳仍由 MarkdownTextView 复制；这里只补充状态栏提示。
        textView.onTimestampActivated = { [weak self] _, _ in
            self?.statusLabel.stringValue = NSLocalizedString("已复制到剪贴板", comment: "")
            return false
        }

        let videoRow = makeFormRow(
            title: NSLocalizedString("视频文件", comment: ""),
            field: videoPathField,
            button: chooseVideoButton
        )
        let subtitleRow = makeFormRow(
            title: NSLocalizedString("字幕文件", comment: ""),
            field: subtitlePathField,
            button: chooseSubtitleButton
        )
        let titleRow = makeFormRow(
            title: NSLocalizedString("标题", comment: ""),
            field: titleField,
            button: nil
        )
        let videoSubtitleRow = makeFormRow(
            title: NSLocalizedString("副标题", comment: ""),
            field: videoSubtitleField,
            button: nil
        )

        let formStack = NSStackView(views: [videoRow, subtitleRow, titleRow, videoSubtitleRow])
        formStack.orientation = .vertical
        formStack.alignment = .leading
        formStack.spacing = 10

        let separator = NSBox()
        separator.boxType = .separator

        self.view.addSubview(formStack)
        self.view.addSubview(separator)
        self.view.addSubview(scrollView)
        self.view.addSubview(footerStack)

        formStack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
        }

        for row in [videoRow, subtitleRow, titleRow, videoSubtitleRow] {
            row.snp.makeConstraints { make in
                make.width.equalTo(formStack.snp.width)
            }
        }

        separator.snp.makeConstraints { make in
            make.top.equalTo(formStack.snp.bottom).offset(14)
            make.leading.trailing.equalTo(formStack)
        }

        scrollView.snp.makeConstraints { make in
            make.top.equalTo(separator.snp.bottom).offset(14)
            make.leading.trailing.equalTo(formStack)
            make.bottom.equalTo(footerStack.snp.top).offset(-14)
            make.height.greaterThanOrEqualTo(220)
        }

        footerStack.snp.makeConstraints { make in
            make.leading.trailing.equalTo(formStack)
            make.bottom.equalToSuperview().offset(-16)
        }

        scrollView.setAccessibilityIdentifier(AccessibilityID.Summary.textView + ".scroll")
    }

    private func makeFormRow(title: String, field: TextField, button: Button?) -> NSStackView {
        let label = Label(labelWithString: title)
        label.textColor = .secondaryLabelColor
        label.alignment = .right
        label.snp.makeConstraints { make in
            make.width.equalTo(60)
        }

        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        var views: [NSView] = [label, field]
        if let button = button {
            button.setContentHuggingPriority(.required, for: .horizontal)
            views.append(button)
        }

        let row = NSStackView(views: views)
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        return row
    }

    // MARK: - File Selection

    @objc private func chooseVideoFile() {
        let panel = NSOpenPanel()
        panel.title = NSLocalizedString("选择视频文件", comment: "")
        panel.prompt = NSLocalizedString("选择", comment: "")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = Self.videoContentTypes

        guard panel.runModal() == .OK, let url = panel.url else { return }

        videoURL = url
        videoPathField.stringValue = url.lastPathComponent
        videoPathField.toolTip = url.path

        if titleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            titleField.stringValue = (url.lastPathComponent as NSString).deletingPathExtension
        }

        statusLabel.stringValue = NSLocalizedString("正在计算视频校验值…", comment: "")
        updateFileHash(for: url)
    }

    @objc private func chooseSubtitleFile() {
        let panel = NSOpenPanel()
        panel.title = NSLocalizedString("选择字幕文件", comment: "")
        panel.prompt = NSLocalizedString("选择", comment: "")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = Self.subtitleContentTypes

        guard panel.runModal() == .OK, let url = panel.url else { return }

        subtitleURL = url
        subtitlePathField.stringValue = url.lastPathComponent
        subtitlePathField.toolTip = url.path
        statusLabel.stringValue = NSLocalizedString("可以生成总结了", comment: "")
    }

    private static var videoContentTypes: [UTType] {
        var types: [UTType] = [.movie, .video]
        let extensions = ["mp4", "mkv", "avi", "mov", "wmv", "flv", "ts", "m2ts", "webm", "rmvb", "m4v", "mpg", "mpeg"]
        for ext in extensions {
            guard let type = UTType(filenameExtension: ext), !types.contains(type) else { continue }
            types.append(type)
        }
        return types
    }

    private static var subtitleContentTypes: [UTType] {
        let types = ["srt", "ass", "ssa"].compactMap { UTType(filenameExtension: $0) }
        return types.isEmpty ? [.plainText] : types
    }

    private func updateFileHash(for url: URL) {
        fileHash = ""
        hashTask?.cancel()
        hashTask = Task.detached(priority: .utility) { [weak self] in
            let hash = SummaryFileHash.md5Prefix(of: url) ?? ""
            await MainActor.run {
                guard let self = self, self.videoURL == url else { return }
                self.fileHash = hash
                if !self.isGenerating,
                   self.statusLabel.stringValue == NSLocalizedString("正在计算视频校验值…", comment: "") {
                    self.statusLabel.stringValue = hash.isEmpty
                        ? NSLocalizedString("无法读取视频文件，本次不会使用缓存", comment: "")
                        : NSLocalizedString("选择字幕文件后生成总结", comment: "")
                }
            }
        }
    }

    // MARK: - Generate

    @objc private func generateSummary() {
        guard !isGenerating else { return }
        guard let subtitleURL = subtitleURL else {
            presentAlert(
                title: NSLocalizedString("需要字幕文件", comment: ""),
                message: NSLocalizedString(
                    "AI 视频总结首期需要字幕文件，请选择 .srt / .ass / .ssa 字幕；暂不支持语音识别。",
                    comment: ""
                )
            )
            return
        }

        isGenerating = true
        setBusy(true, status: NSLocalizedString("准备生成…", comment: ""))

        generationTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            defer { self.finishGeneration() }

            do {
                guard await LoginGate.shared.ensureLoggedIn(presenting: self.view.window) else {
                    self.statusLabel.stringValue = NSLocalizedString("需要登录弹弹play账号", comment: "")
                    return
                }

                if self.videoURL != nil, let hashTask = self.hashTask {
                    _ = await hashTask.value
                }
                let hash = self.fileHash

                if !hash.isEmpty, let entry = self.cache.load(hash: hash) {
                    switch self.askCacheAction(entry: entry) {
                    case .reuse:
                        self.displayCached(entry)
                        return
                    case .cancel:
                        self.statusLabel.stringValue = NSLocalizedString("已取消", comment: "")
                        return
                    case .regenerate:
                        break
                    }
                }

                guard await self.accessCheck() else {
                    self.statusLabel.stringValue = NSLocalizedString("需要弹弹play会员", comment: "")
                    self.presentAlert(
                        title: NSLocalizedString("AI 视频总结", comment: ""),
                        message: NSLocalizedString("AI 视频总结是弹弹play会员功能，请开通会员后使用。", comment: "")
                    )
                    return
                }

                self.statusLabel.stringValue = NSLocalizedString("正在解析字幕…", comment: "")
                let transcriptions = try await Task.detached(priority: .userInitiated) {
                    try SubtitleTranscriptParser.transcriptions(from: subtitleURL)
                }.value

                guard !transcriptions.isEmpty else {
                    self.statusLabel.stringValue = NSLocalizedString("字幕文件中没有可用的文本", comment: "")
                    self.presentAlert(
                        title: NSLocalizedString("没有可用字幕文本", comment: ""),
                        message: NSLocalizedString("字幕文件中没有可用的文本，请换一个字幕文件。", comment: "")
                    )
                    return
                }

                guard self.confirmConsumption(transcriptionCount: transcriptions.count) else {
                    self.statusLabel.stringValue = NSLocalizedString("已取消生成", comment: "")
                    return
                }

                let request = SummaryVideoRequest(
                    fileName: self.videoURL?.lastPathComponent ?? "",
                    fileHash: hash,
                    videoTitle: self.titleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
                    videoSubtitle: self.videoSubtitleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
                    transcriptions: transcriptions
                )

                self.statusLabel.stringValue = NSLocalizedString("正在生成总结，可能需要 1-2 分钟…", comment: "")
                let response = try await self.service.generateSummary(for: request)

                if !hash.isEmpty {
                    do {
                        try self.cache.save(
                            response,
                            hash: hash,
                            fileName: request.fileName.isEmpty ? nil : request.fileName,
                            videoTitle: request.videoTitle.isEmpty ? nil : request.videoTitle
                        )
                    } catch {
                        ANX.logError(.HTTP, "[Summary] 保存本地缓存失败：\(error)")
                    }
                }

                self.display(response: response, fromCache: false)
            } catch is CancellationError {
                self.statusLabel.stringValue = NSLocalizedString("已取消", comment: "")
            } catch {
                self.handle(error: error)
            }
        }
    }

    private func finishGeneration() {
        isGenerating = false
        setBusy(false, status: nil)
    }

    private func setBusy(_ busy: Bool, status: String?) {
        if let status = status {
            statusLabel.stringValue = status
        }
        generateButton.isEnabled = !busy
        if busy {
            progressIndicator.isHidden = false
            progressIndicator.startAnimation(nil)
        } else {
            progressIndicator.stopAnimation(nil)
            progressIndicator.isHidden = true
        }
    }

    // MARK: - Results

    private func displayCached(_ entry: SummaryCacheEntry) {
        let markdown = SummaryMarkdown.make(from: entry.response)
        applyMarkdown(markdown)

        let date = Self.cacheDateFormatter.string(from: entry.createdAt)
        statusLabel.stringValue = String(
            format: NSLocalizedString("已加载本地缓存（%@）", comment: ""),
            date
        )
        quotaLabel.stringValue = NSLocalizedString("查看缓存不消耗额度", comment: "")
    }

    private func display(response: SummaryVideoResponse, fromCache: Bool) {
        let markdown = SummaryMarkdown.make(from: response)
        applyMarkdown(markdown)

        var status = fromCache
            ? NSLocalizedString("已加载本地缓存", comment: "")
            : NSLocalizedString("生成完成", comment: "")

        if let usage = response.usage, let remain = response.countRemain {
            status += String(
                format: NSLocalizedString(" · 本次使用 %d 次，本月剩余 %d 次", comment: ""),
                usage,
                remain
            )
            quotaLabel.stringValue = String(
                format: NSLocalizedString("本月剩余 %d 次", comment: ""),
                remain
            )
        } else if let remain = response.countRemain {
            status += String(format: NSLocalizedString(" · 本月剩余 %d 次", comment: ""), remain)
            quotaLabel.stringValue = String(format: NSLocalizedString("本月剩余 %d 次", comment: ""), remain)
        } else {
            quotaLabel.stringValue = ""
        }

        statusLabel.stringValue = status
    }

    private func applyMarkdown(_ markdown: String) {
        generatedMarkdown = markdown
        copyButton.isEnabled = !markdown.isEmpty
        if markdown.isEmpty {
            showPlaceholder()
            return
        }
        renderMarkdown(markdown)
    }

    private func renderMarkdown(_ markdown: String) {
        textView.setMarkdown(markdown)
        textView.scrollToBeginningOfDocument(nil)
    }

    private func showPlaceholder() {
        textView.setPlainText(
            NSLocalizedString("生成结果将显示在这里", comment: ""),
            color: .tertiaryLabelColor
        )
    }

    @objc private func copyResult() {
        guard !generatedMarkdown.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(generatedMarkdown, forType: .string)
        statusLabel.stringValue = NSLocalizedString("已复制到剪贴板", comment: "")
    }

    // MARK: - Cache Prompt

    private enum CacheAction {
        case reuse
        case regenerate
        case cancel
    }

    private func askCacheAction(entry: SummaryCacheEntry) -> CacheAction {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("发现已生成的总结", comment: "")
        let date = Self.cacheDateFormatter.string(from: entry.createdAt)
        alert.informativeText = String(
            format: NSLocalizedString("该视频已有本地总结（%@）。直接查看不会消耗额度。", comment: ""),
            date
        )
        alert.alertStyle = .informational
        alert.addButton(withTitle: NSLocalizedString("查看已生成总结", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("重新生成", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("取消", comment: ""))

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return .reuse
        case .alertSecondButtonReturn:
            return .regenerate
        default:
            return .cancel
        }
    }

    private static let cacheDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    // MARK: - Prompts

    private func confirmConsumption(transcriptionCount: Int) -> Bool {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("生成 AI 视频总结", comment: "")
        alert.informativeText = String(
            format: NSLocalizedString(
                "将消耗 1 次用量，使用 %d 条字幕为当前视频生成总结。\n\n由于模型限制，生成结果可能不完全准确。",
                comment: ""
            ),
            transcriptionCount
        )
        alert.alertStyle = .informational
        alert.addButton(withTitle: NSLocalizedString("继续", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("取消", comment: ""))
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func presentAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("好", comment: ""))
        alert.runModal()
    }

    private func handle(error: Error) {
        if let apiError = error as? APIError, case .cancelled = apiError {
            statusLabel.stringValue = NSLocalizedString("已取消", comment: "")
            return
        }

        let message = error.localizedDescription
        statusLabel.stringValue = message
        ANX.logError(.HTTP, "[Summary] 生成失败：\(error)")
        presentAlert(title: NSLocalizedString("AI 视频总结", comment: ""), message: message)
    }
}
