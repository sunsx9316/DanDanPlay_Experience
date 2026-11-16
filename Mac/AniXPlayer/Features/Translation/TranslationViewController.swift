//
//  TranslationViewController.swift
//  AniXPlayer
//
//  macOS only：AI 字幕翻译界面。
//

import Cocoa
import SnapKit
import UniformTypeIdentifiers

@MainActor
final class TranslationViewController: ViewController {
    private let accessCheck: () async -> Bool
    private let api: SubtitleTranslationAPIProviding
    private let engine: SubtitleTranslationEngine

    private var document: SubtitleDocument?
    private var services: [TranslationServiceOption] = TranslationServiceCatalog.fallback
    private var lastUsage: SubtitleServiceUsageResponse?
    private var translationTask: Task<Void, Never>?
    private var isBusy = false

    // MARK: - Views

    private lazy var chooseFileButton: Button = {
        let button = Button(
            title: NSLocalizedString("选择字幕文件…", comment: ""),
            target: self,
            action: #selector(chooseFileTapped)
        )
        button.bezelStyle = .rounded
        button.setAccessibilityIdentifier(AccessibilityID.Translation.chooseFileButton)
        button.setAccessibilityLabel(NSLocalizedString("选择字幕文件", comment: ""))
        return button
    }()

    private lazy var fileLabel: Label = {
        let label = Label(labelWithString: NSLocalizedString("尚未选择字幕文件", comment: ""))
        label.font = .ddp_small()
        label.textColor = .subtitleTextColor
        label.lineBreakMode = .byTruncatingMiddle
        label.maximumNumberOfLines = 1
        return label
    }()

    private lazy var usageLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .ddp_small()
        label.textColor = .subtitleTextColor
        label.alignment = .right
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        return label
    }()

    private lazy var servicePopup: PopUpButton = {
        let popup = PopUpButton()
        popup.target = self
        popup.action = #selector(serviceChanged)
        popup.setAccessibilityIdentifier(AccessibilityID.Translation.servicePopup)
        popup.setAccessibilityLabel(NSLocalizedString("翻译服务", comment: ""))
        return popup
    }()

    private lazy var fromLanguagePopup: PopUpButton = {
        let popup = PopUpButton()
        popup.target = self
        popup.action = #selector(languageChanged)
        popup.setAccessibilityIdentifier(AccessibilityID.Translation.fromLanguagePopup)
        popup.setAccessibilityLabel(NSLocalizedString("源语言", comment: ""))
        return popup
    }()

    private lazy var toLanguagePopup: PopUpButton = {
        let popup = PopUpButton()
        popup.target = self
        popup.action = #selector(languageChanged)
        popup.setAccessibilityIdentifier(AccessibilityID.Translation.toLanguagePopup)
        popup.setAccessibilityLabel(NSLocalizedString("目标语言", comment: ""))
        return popup
    }()

    private lazy var modePopup: PopUpButton = {
        let popup = PopUpButton()
        popup.target = self
        popup.action = #selector(modeChanged)
        popup.setAccessibilityIdentifier(AccessibilityID.Translation.modePopup)
        popup.setAccessibilityLabel(NSLocalizedString("输出模式", comment: ""))
        return popup
    }()

    private lazy var tableView: TableView = {
        let tableView = TableView(frame: NSRect(x: 0, y: 0, width: 868, height: 430))
        tableView.autoresizingMask = [.width]
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 44
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = false
        tableView.allowsEmptySelection = true
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.headerView = NSTableHeaderView()
        tableView.setAccessibilityIdentifier(AccessibilityID.Translation.previewTable)
        tableView.setAccessibilityLabel(NSLocalizedString("字幕预览", comment: ""))

        let columns: [(id: String, title: String, width: CGFloat, minWidth: CGFloat)] = [
            ("index", NSLocalizedString("序号", comment: ""), 52, 44),
            ("time", NSLocalizedString("时间", comment: ""), 176, 160),
            ("original", NSLocalizedString("原文", comment: ""), 300, 160),
            ("translated", NSLocalizedString("译文", comment: ""), 300, 160),
        ]
        for column in columns {
            let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(column.id))
            tableColumn.title = column.title
            tableColumn.width = column.width
            tableColumn.minWidth = column.minWidth
            tableView.addTableColumn(tableColumn)
        }
        return tableView
    }()

    private lazy var scrollView: NSScrollView = {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        scrollView.documentView = tableView
        return scrollView
    }()

    private lazy var progressIndicator: NSProgressIndicator = {
        let progress = NSProgressIndicator()
        progress.style = .bar
        progress.isIndeterminate = false
        progress.minValue = 0
        progress.maxValue = 1
        progress.doubleValue = 0
        progress.controlSize = .small
        progress.setAccessibilityIdentifier(AccessibilityID.Translation.progress)
        progress.setAccessibilityLabel(NSLocalizedString("翻译进度", comment: ""))
        return progress
    }()

    private lazy var statusLabel: Label = {
        let label = Label(labelWithString: NSLocalizedString("请选择 SRT / ASS / SSA 字幕文件", comment: ""))
        label.font = .ddp_small()
        label.textColor = .textColor
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.setAccessibilityIdentifier(AccessibilityID.Translation.statusLabel)
        label.setAccessibilityLabel(NSLocalizedString("翻译状态", comment: ""))
        return label
    }()

    private lazy var translateButton: Button = {
        let button = Button(
            title: NSLocalizedString("开始翻译", comment: ""),
            target: self,
            action: #selector(translateTapped)
        )
        button.bezelStyle = .rounded
        button.keyEquivalent = "\r"
        button.setAccessibilityIdentifier(AccessibilityID.Translation.translateButton)
        button.setAccessibilityLabel(NSLocalizedString("开始翻译", comment: ""))
        return button
    }()

    private lazy var cancelButton: Button = {
        let button = Button(
            title: NSLocalizedString("取消", comment: ""),
            target: self,
            action: #selector(cancelTapped)
        )
        button.bezelStyle = .rounded
        button.setAccessibilityIdentifier(AccessibilityID.Translation.cancelButton)
        button.setAccessibilityLabel(NSLocalizedString("取消翻译", comment: ""))
        return button
    }()

    private lazy var exportButton: Button = {
        let button = Button(
            title: NSLocalizedString("导出…", comment: ""),
            target: self,
            action: #selector(exportTapped)
        )
        button.bezelStyle = .rounded
        button.setAccessibilityIdentifier(AccessibilityID.Translation.exportButton)
        button.setAccessibilityLabel(NSLocalizedString("导出翻译后的字幕", comment: ""))
        return button
    }()

    // MARK: - Init

    init(
        accessCheck: @escaping () async -> Bool,
        api: SubtitleTranslationAPIProviding = SubtitleTranslationAPIClient()
    ) {
        self.accessCheck = accessCheck
        self.api = api
        self.engine = SubtitleTranslationEngine(api: api)
        super.init()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        translationTask?.cancel()
    }

    // MARK: - Lifecycle

    override func loadView() {
        self.view = BaseView(frame: NSRect(x: 0, y: 0, width: 900, height: 640))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        reloadLanguagePopups()
        reloadServicePopup(preferredID: TranslationServiceCatalog.defaultServiceID)
        reloadModePopup()
        setupLayout()
        updateUsageLabel()
        updateControlState()
    }

    // MARK: - Layout

    private func setupLayout() {
        let serviceTitle = Self.fieldLabel(NSLocalizedString("服务", comment: ""))
        let fromTitle = Self.fieldLabel(NSLocalizedString("源语言", comment: ""))
        let toTitle = Self.fieldLabel(NSLocalizedString("目标语言", comment: ""))
        let modeTitle = Self.fieldLabel(NSLocalizedString("输出", comment: ""))

        view.addSubview(chooseFileButton)
        view.addSubview(fileLabel)
        view.addSubview(usageLabel)
        view.addSubview(serviceTitle)
        view.addSubview(servicePopup)
        view.addSubview(fromTitle)
        view.addSubview(fromLanguagePopup)
        view.addSubview(toTitle)
        view.addSubview(toLanguagePopup)
        view.addSubview(modeTitle)
        view.addSubview(modePopup)
        view.addSubview(scrollView)
        view.addSubview(progressIndicator)
        view.addSubview(statusLabel)
        view.addSubview(cancelButton)
        view.addSubview(exportButton)
        view.addSubview(translateButton)

        chooseFileButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalToSuperview().offset(16)
            make.width.equalTo(128)
            make.height.equalTo(30)
        }

        usageLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalTo(chooseFileButton)
            make.width.lessThanOrEqualTo(220)
        }

        fileLabel.snp.makeConstraints { make in
            make.leading.equalTo(chooseFileButton.snp.trailing).offset(10)
            make.trailing.equalTo(usageLabel.snp.leading).offset(-12)
            make.centerY.equalTo(chooseFileButton)
        }

        serviceTitle.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalTo(chooseFileButton.snp.bottom).offset(18)
        }

        servicePopup.snp.makeConstraints { make in
            make.leading.equalTo(serviceTitle.snp.trailing).offset(6)
            make.centerY.equalTo(serviceTitle)
            make.width.equalTo(112)
        }

        fromTitle.snp.makeConstraints { make in
            make.leading.equalTo(servicePopup.snp.trailing).offset(14)
            make.centerY.equalTo(serviceTitle)
        }

        fromLanguagePopup.snp.makeConstraints { make in
            make.leading.equalTo(fromTitle.snp.trailing).offset(6)
            make.centerY.equalTo(serviceTitle)
            make.width.equalTo(120)
        }

        toTitle.snp.makeConstraints { make in
            make.leading.equalTo(fromLanguagePopup.snp.trailing).offset(14)
            make.centerY.equalTo(serviceTitle)
        }

        toLanguagePopup.snp.makeConstraints { make in
            make.leading.equalTo(toTitle.snp.trailing).offset(6)
            make.centerY.equalTo(serviceTitle)
            make.width.equalTo(120)
        }

        modeTitle.snp.makeConstraints { make in
            make.leading.equalTo(toLanguagePopup.snp.trailing).offset(14)
            make.centerY.equalTo(serviceTitle)
        }

        modePopup.snp.makeConstraints { make in
            make.leading.equalTo(modeTitle.snp.trailing).offset(6)
            make.centerY.equalTo(serviceTitle)
            make.width.equalTo(100)
            make.trailing.lessThanOrEqualToSuperview().offset(-16)
        }

        scrollView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.top.equalTo(serviceTitle.snp.bottom).offset(16)
            make.bottom.equalTo(progressIndicator.snp.top).offset(-16)
        }

        progressIndicator.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalTo(cancelButton.snp.leading).offset(-16)
            make.bottom.equalTo(statusLabel.snp.top).offset(-8)
            make.height.equalTo(8)
        }

        statusLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.bottom.equalToSuperview().offset(-18)
            make.trailing.equalTo(cancelButton.snp.leading).offset(-16)
        }

        translateButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview().offset(-16)
            make.width.equalTo(96)
            make.height.equalTo(30)
        }

        exportButton.snp.makeConstraints { make in
            make.trailing.equalTo(translateButton.snp.leading).offset(-10)
            make.centerY.equalTo(translateButton)
            make.width.equalTo(88)
            make.height.equalTo(30)
        }

        cancelButton.snp.makeConstraints { make in
            make.trailing.equalTo(exportButton.snp.leading).offset(-10)
            make.centerY.equalTo(translateButton)
            make.width.equalTo(72)
            make.height.equalTo(30)
        }
    }

    private static func fieldLabel(_ text: String) -> Label {
        let label = Label(labelWithString: text)
        label.font = .ddp_small()
        label.textColor = .subtitleTextColor
        return label
    }

    // MARK: - Popup data

    private func reloadServicePopup(preferredID: Int?) {
        servicePopup.removeAllItems()
        for service in services {
            servicePopup.addItem(withTitle: service.name)
            servicePopup.lastItem?.tag = service.id
        }

        let targetID = preferredID ?? TranslationServiceCatalog.defaultServiceID
        if let index = services.firstIndex(where: { $0.id == targetID }) {
            servicePopup.selectItem(at: index)
        } else if !services.isEmpty {
            servicePopup.selectItem(at: 0)
        }
    }

    private func reloadLanguagePopups() {
        fromLanguagePopup.removeAllItems()
        for language in TranslationLanguages.from {
            fromLanguagePopup.addItem(withTitle: language.menuTitle)
        }
        if let index = TranslationLanguages.from.firstIndex(where: {
            $0.code == TranslationLanguages.defaultFromCode
        }) {
            fromLanguagePopup.selectItem(at: index)
        }

        toLanguagePopup.removeAllItems()
        for language in TranslationLanguages.to {
            toLanguagePopup.addItem(withTitle: language.menuTitle)
        }
        if let index = TranslationLanguages.to.firstIndex(where: {
            $0.code == TranslationLanguages.defaultToCode
        }) {
            toLanguagePopup.selectItem(at: index)
        }
    }

    private func reloadModePopup() {
        modePopup.removeAllItems()
        for mode in SubtitleTranslationMode.allCases {
            modePopup.addItem(withTitle: mode.title)
            modePopup.lastItem?.tag = mode.rawValue
        }
        modePopup.selectItem(at: SubtitleTranslationMode.translated.rawValue)
    }

    private var selectedServiceID: Int {
        guard let item = servicePopup.selectedItem else {
            return TranslationServiceCatalog.defaultServiceID
        }
        return item.tag
    }

    private var selectedServiceName: String {
        servicePopup.titleOfSelectedItem ?? ""
    }

    private var selectedFromCode: String {
        let index = fromLanguagePopup.indexOfSelectedItem
        guard index >= 0, index < TranslationLanguages.from.count else {
            return TranslationLanguages.defaultFromCode
        }
        return TranslationLanguages.from[index].code
    }

    private var selectedToCode: String {
        let index = toLanguagePopup.indexOfSelectedItem
        guard index >= 0, index < TranslationLanguages.to.count else {
            return TranslationLanguages.defaultToCode
        }
        return TranslationLanguages.to[index].code
    }

    private var selectedMode: SubtitleTranslationMode {
        SubtitleTranslationMode(rawValue: modePopup.selectedItem?.tag ?? 0) ?? .translated
    }

    // MARK: - State

    private func updateControlState() {
        let hasDocument = document != nil

        chooseFileButton.isEnabled = !isBusy
        servicePopup.isEnabled = !isBusy
        fromLanguagePopup.isEnabled = !isBusy
        toLanguagePopup.isEnabled = !isBusy
        modePopup.isEnabled = !isBusy
        translateButton.isEnabled = hasDocument && !isBusy && selectedMode != .original
        cancelButton.isEnabled = isBusy
        exportButton.isEnabled = hasDocument && !isBusy
    }

    private func setStatus(_ text: String) {
        statusLabel.stringValue = text
        statusLabel.toolTip = text
    }

    // MARK: - Actions

    @objc private func chooseFileTapped() {
        guard !isBusy else { return }

        let panel = NSOpenPanel()
        panel.title = NSLocalizedString("选择字幕文件", comment: "")
        panel.prompt = NSLocalizedString("选择", comment: "")
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        let types = ["srt", "ass", "ssa"].compactMap { UTType(filenameExtension: $0) }
        if !types.isEmpty {
            panel.allowedContentTypes = types
        }

        guard let window = view.window else { return }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.loadDocument(url: url)
        }
    }

    private func loadDocument(url: URL) {
        do {
            let document = try SubtitleDocumentLoader.load(url: url)
            self.document = document
            fileLabel.stringValue = url.lastPathComponent
            fileLabel.toolTip = url.path
            progressIndicator.doubleValue = 0

            var message = String(
                format: NSLocalizedString("已载入 %d 条字幕", comment: ""),
                document.lines.count
            )
            if document.skippedLineCount > 0 {
                message += String(
                    format: NSLocalizedString("，%d 条无法解析的 Dialogue 已原样保留", comment: ""),
                    document.skippedLineCount
                )
            }
            setStatus(message)
            tableView.reloadData()
            updateControlState()
            if !document.lines.isEmpty {
                tableView.scrollRowToVisible(0)
            }
        } catch {
            document = nil
            fileLabel.stringValue = NSLocalizedString("尚未选择字幕文件", comment: "")
            fileLabel.toolTip = nil
            tableView.reloadData()
            setStatus(error.localizedDescription)
            updateControlState()
            showAlert(
                title: NSLocalizedString("无法打开字幕文件", comment: ""),
                message: error.localizedDescription,
                style: .warning
            )
        }
    }

    @objc private func serviceChanged() {
        updateUsageLabel()
    }

    @objc private func languageChanged() {
        // 目标语言影响导出文件名；不需要立即重新解析。
    }

    @objc private func modeChanged() {
        updateControlState()
    }

    @objc private func translateTapped() {
        guard !isBusy else { return }
        translationTask?.cancel()
        let task = Task { [weak self] () -> Void in
            guard let self = self else { return }
            await self.performTranslation()
        }
        translationTask = task
    }

    @objc private func cancelTapped() {
        guard isBusy else { return }
        translationTask?.cancel()
        cancelButton.isEnabled = false
        setStatus(NSLocalizedString("正在取消翻译…", comment: ""))
    }

    func cancelCurrentTranslation() {
        translationTask?.cancel()
    }

    // MARK: - Translation

    private func performTranslation() async {
        guard let selectedDocument = document else {
            setStatus(NSLocalizedString("请先选择字幕文件", comment: ""))
            return
        }

        let mode = selectedMode
        guard mode != .original else {
            setStatus(NSLocalizedString("当前为仅原文模式，无需翻译", comment: ""))
            return
        }

        let pendingTexts = selectedDocument.pendingTexts()
        guard !pendingTexts.isEmpty else {
            setStatus(NSLocalizedString("全部字幕均已翻译，无需重复翻译", comment: ""))
            return
        }

        let serviceID = selectedServiceID
        let serviceName = selectedServiceName
        let fromCode = selectedFromCode
        let toCode = selectedToCode
        let fileName = selectedDocument.sourceURL.lastPathComponent

        isBusy = true
        updateControlState()
        setStatus(NSLocalizedString("等待登录…", comment: ""))
        progressIndicator.doubleValue = 0

        defer {
            isBusy = false
            translationTask = nil
            updateControlState()
        }

        guard await LoginGate.shared.ensureLoggedIn(presenting: view.window) else {
            setStatus(Task.isCancelled
                ? NSLocalizedString("已取消翻译", comment: "")
                : NSLocalizedString("已取消登录，未开始翻译", comment: ""))
            return
        }

        if Task.isCancelled {
            setStatus(NSLocalizedString("已取消翻译", comment: ""))
            return
        }

        guard await accessCheck() else {
            setStatus(NSLocalizedString("当前账号未开通弹弹play会员，无法使用 AI 翻译", comment: ""))
            return
        }

        if Task.isCancelled {
            setStatus(NSLocalizedString("已取消翻译", comment: ""))
            return
        }

        // 登录/门禁通过后再刷新服务与额度，失败均不阻塞翻译。
        Task { [weak self] in
            await self?.refreshServices()
            await self?.refreshUsage()
        }

        let plan = SubtitleBatchPlanner.plan(
            texts: pendingTexts,
            serviceID: serviceID,
            totalLineCount: selectedDocument.lines.count
        )
        progressIndicator.minValue = 0
        progressIndicator.maxValue = Double(max(1, plan.batches.count))
        progressIndicator.doubleValue = 0
        setStatus(String(
            format: NSLocalizedString("正在翻译：%d 批（%@）…", comment: ""),
            plan.batches.count,
            plan.mode.displayName
        ))

        let outcome = await engine.translate(
            texts: pendingTexts,
            totalLineCount: selectedDocument.lines.count,
            serviceID: serviceID,
            fromLanguage: fromCode,
            toLanguage: toCode,
            fileName: fileName,
            onEvent: { [weak self] event in
                self?.handle(event: event)
            }
        )

        var updatedDocument = self.document ?? selectedDocument
        updatedDocument.applyTranslations(outcome.translations)
        self.document = updatedDocument
        tableView.reloadData()

        if outcome.wasCancelled {
            progressIndicator.doubleValue = Double(outcome.completedBatchCount)
        } else {
            progressIndicator.doubleValue = Double(outcome.totalBatchCount)
        }

        finishTranslation(
            outcome: outcome,
            document: updatedDocument,
            serviceName: serviceName
        )
    }

    private func handle(event: SubtitleTranslationEvent) {
        if let response = event.response {
            document?.applyTranslations(response.translation)
            tableView.reloadData()
        }

        progressIndicator.doubleValue = Double(event.completedBatchCount)
        var text = String(
            format: NSLocalizedString("正在翻译：%d/%d 批…", comment: ""),
            event.completedBatchCount,
            event.totalBatchCount
        )
        if let failure = event.failure {
            text += String(
                format: NSLocalizedString("（第 %d 批失败）", comment: ""),
                failure.batchNumber
            )
        }
        setStatus(text)
    }

    private func finishTranslation(
        outcome: SubtitleTranslationOutcome,
        document: SubtitleDocument,
        serviceName: String
    ) {
        let totalLines = document.lines.count
        let translatedLines = document.translatedLineCount
        let remaining = document.pendingTexts().count
        let remainText = outcome.countRemain.map(String.init) ?? NSLocalizedString("未知", comment: "")

        if outcome.wasCancelled {
            var message = String(
                format: NSLocalizedString("已取消翻译：完成 %d/%d 批，%d/%d 条字幕有译文。", comment: ""),
                outcome.completedBatchCount,
                outcome.totalBatchCount,
                translatedLines,
                totalLines
            )
            if remaining > 0 {
                message += NSLocalizedString("再次点击「开始翻译」可继续翻译未完成部分。", comment: "")
            }
            setStatus(message)
            return
        }

        if outcome.hasFailure {
            let prefix: String
            if outcome.hasContentFilterFailure {
                prefix = NSLocalizedString("部分文本未通过 ChatGPT 内容审查，已保留其他批次结果。", comment: "")
            } else if outcome.hasReachLimitFailure {
                prefix = NSLocalizedString("本月翻译额度已用完或不足，已保留其他批次结果。", comment: "")
            } else {
                prefix = String(
                    format: NSLocalizedString("有 %d 个批次翻译失败，已保留其他批次结果。", comment: ""),
                    outcome.failures.count
                )
            }

            var message = prefix
            if let countRemain = outcome.countRemain {
                message += String(
                    format: NSLocalizedString("本月剩余额度：%d。", comment: ""),
                    countRemain
                )
            }
            if remaining > 0 {
                message += NSLocalizedString("可再次点击「开始翻译」重试未完成部分。", comment: "")
            }
            setStatus(message)

            let details = outcome.failures
                .map { String(format: NSLocalizedString("批次 %d：%@", comment: ""), $0.batchNumber, $0.message) }
                .joined(separator: "\n")
            let title: String
            if outcome.hasContentFilterFailure {
                title = NSLocalizedString("ChatGPT 内容审查", comment: "")
            } else if outcome.hasReachLimitFailure {
                title = NSLocalizedString("翻译额度不足", comment: "")
            } else {
                title = NSLocalizedString("翻译未全部完成", comment: "")
            }
            showAlert(title: title, message: message + "\n\n" + details, style: .warning)
            return
        }

        var message = String(
            format: NSLocalizedString("翻译完成：%d/%d 条字幕有译文，服务：%@，本次消耗：%d，本月剩余：%@。", comment: ""),
            translatedLines,
            totalLines,
            serviceName,
            outcome.usage,
            remainText
        )
        if remaining > 0 {
            message += String(
                format: NSLocalizedString("有 %d 条未返回译文，可再次点击「开始翻译」重试。", comment: ""),
                remaining
            )
        }
        setStatus(message)
    }

    // MARK: - Services / usage

    private func refreshServices() async {
        do {
            let response = try await api.fetchServices()
            guard response.success, !response.services.isEmpty else { return }
            let preferredID = selectedServiceID
            services = response.services.map { TranslationServiceOption(id: $0.id, name: $0.name) }
            reloadServicePopup(preferredID: preferredID)
            updateControlState()
            updateUsageLabel()
        } catch {
            // 服务列表失败时保留内置列表，不阻塞翻译。
        }
    }

    private func refreshUsage() async {
        do {
            let response = try await api.fetchUsage()
            guard response.success else {
                usageLabel.stringValue = NSLocalizedString("额度暂不可用", comment: "")
                return
            }
            lastUsage = response
            updateUsageLabel()
        } catch {
            lastUsage = nil
            usageLabel.stringValue = NSLocalizedString("额度暂不可用", comment: "")
            usageLabel.toolTip = nil
        }
    }

    private func updateUsageLabel() {
        guard let usage = lastUsage else {
            usageLabel.stringValue = ""
            usageLabel.toolTip = NSLocalizedString("登录后可查看本月翻译额度", comment: "")
            return
        }

        let item = usage.services.first(where: { $0.id == selectedServiceID }) ?? usage.services.first
        if let item = item {
            usageLabel.stringValue = String(
                format: NSLocalizedString("本月剩余 %d", comment: ""),
                item.remain
            )
        } else {
            usageLabel.stringValue = usage.currentPeriod ?? NSLocalizedString("额度信息", comment: "")
        }

        var details: [String] = []
        if let period = usage.currentPeriod, !period.isEmpty {
            details.append(String(format: NSLocalizedString("当前周期：%@", comment: ""), period))
        }
        for service in usage.services {
            details.append(String(
                format: NSLocalizedString("%@：已用 %d / 总计 %d，剩余 %d", comment: ""),
                service.name,
                service.usage,
                service.total,
                service.remain
            ))
        }
        usageLabel.toolTip = details.isEmpty ? nil : details.joined(separator: "\n")
    }

    // MARK: - Export

    @objc private func exportTapped() {
        guard let document = document else {
            setStatus(NSLocalizedString("请先选择字幕文件", comment: ""))
            return
        }

        let mode = selectedMode
        if mode != .original && document.translatedLineCount == 0 {
            let message = NSLocalizedString("尚未翻译任何字幕，请先执行翻译。", comment: "")
            setStatus(message)
            showAlert(
                title: NSLocalizedString("没有可导出的译文", comment: ""),
                message: message,
                style: .informational
            )
            return
        }

        let panel = NSSavePanel()
        panel.title = NSLocalizedString("导出字幕", comment: "")
        panel.prompt = NSLocalizedString("导出", comment: "")
        panel.canCreateDirectories = true
        let baseName = document.sourceURL.deletingPathExtension().lastPathComponent
        panel.nameFieldStringValue = "\(baseName).\(selectedToCode).srt"

        var types: [UTType] = []
        if let srt = UTType(filenameExtension: "srt") {
            types.append(srt)
        }
        if document.isASS, let ass = UTType(filenameExtension: document.format.rawValue) {
            types.append(ass)
        }
        if !types.isEmpty {
            panel.allowedContentTypes = types
        }

        guard let window = view.window else { return }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard let self = self, response == .OK, let url = panel.url else { return }
            self.writeExport(document: document, mode: mode, url: url)
        }
    }

    private func writeExport(document: SubtitleDocument, mode: SubtitleTranslationMode, url: URL) {
        let requestedFormat = SubtitleFormat(rawValue: url.pathExtension.lowercased())
        if let requestedFormat = requestedFormat, requestedFormat.isASS, !document.isASS {
            let message = NSLocalizedString("SRT 字幕无法导出为 ASS 样式，请改用 .srt 扩展名。", comment: "")
            setStatus(message)
            showAlert(
                title: NSLocalizedString("导出格式不支持", comment: ""),
                message: message,
                style: .warning
            )
            return
        }

        let targetFormat = requestedFormat ?? .srt

        let content = document.exportText(mode: mode, format: targetFormat)
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            var message = String(
                format: NSLocalizedString("已导出：%@", comment: ""),
                url.lastPathComponent
            )
            if mode != .original {
                let missing = document.lines.count - document.translatedLineCount
                if missing > 0 {
                    message += String(
                        format: NSLocalizedString("（%d 条未翻译，已保留原文）", comment: ""),
                        missing
                    )
                }
            }
            setStatus(message)
        } catch {
            setStatus(error.localizedDescription)
            showAlert(
                title: NSLocalizedString("导出失败", comment: ""),
                message: error.localizedDescription,
                style: .warning
            )
        }
    }

    // MARK: - Alert

    private func showAlert(title: String, message: String, style: NSAlert.Style) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.addButton(withTitle: NSLocalizedString("好", comment: ""))

        if let window = view.window {
            alert.beginSheetModal(for: window, completionHandler: nil)
        } else {
            alert.runModal()
        }
    }
}

// MARK: - Table

extension TranslationViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        document?.lines.count ?? 0
    }

    func tableView(
        _ tableView: NSTableView,
        viewFor tableColumn: NSTableColumn?,
        row: Int
    ) -> NSView? {
        guard let document = document, row >= 0, row < document.lines.count else {
            return nil
        }
        let line = document.lines[row]
        let identifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("cell")

        switch identifier.rawValue {
        case "index":
            return makeCell(
                identifier: identifier,
                text: "\(row + 1)",
                color: .subtitleTextColor,
                alignment: .right,
                toolTip: nil
            )
        case "time":
            return makeCell(
                identifier: identifier,
                text: line.displayTimeRange,
                color: .subtitleTextColor,
                alignment: .left,
                toolTip: nil
            )
        case "original":
            return makeCell(
                identifier: identifier,
                text: line.originalText.replacingOccurrences(of: "\n", with: " / "),
                color: .textColor,
                alignment: .left,
                toolTip: line.originalText
            )
        case "translated":
            let translated = (line.translatedText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return makeCell(
                identifier: identifier,
                text: translated.isEmpty ? "—" : translated.replacingOccurrences(of: "\n", with: " / "),
                color: translated.isEmpty ? .subtitleTextColor : .textColor,
                alignment: .left,
                toolTip: translated.isEmpty ? nil : translated
            )
        default:
            return nil
        }
    }

    private func makeCell(
        identifier: NSUserInterfaceItemIdentifier,
        text: String,
        color: NSColor,
        alignment: NSTextAlignment,
        toolTip: String?
    ) -> NSView {
        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = identifier
            let label = Label(labelWithString: "")
            label.font = .ddp_small()
            label.lineBreakMode = .byTruncatingTail
            label.maximumNumberOfLines = 1
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            cell.addSubview(label)
            label.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(6)
                make.trailing.equalToSuperview().offset(-6)
                make.centerY.equalToSuperview()
            }
            cell.textField = label
        }

        cell.textField?.stringValue = text
        cell.textField?.textColor = color
        cell.textField?.alignment = alignment
        cell.toolTip = toolTip
        return cell
    }
}
