//
//  OnlineDanmakuMatchViewController.swift
//  AniXPlayer
//
//  macOS：在线播放前的「选择弹幕库」窗口内容。
//
//  与播放器的 MatchsViewController 不同，这里不依赖 PlayerViewController 的 delegate：
//  用户选定后只把结果交回在线观看页，由调用方写入匹配缓存并启动播放。
//

import Cocoa
import SnapKit

// MARK: - Result cell

final class OnlineDanmakuMatchCell: BaseView {

    private let titleLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 13, weight: .semibold),
        color: .labelColor
    )

    private let episodeLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 12),
        color: .secondaryLabelColor
    )

    private let idLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 10),
        color: .tertiaryLabelColor
    )

    private let badgeView = NSView()

    private let typeLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 10, weight: .semibold),
        color: .white,
        alignment: .center
    )

    var match: Match? {
        didSet {
            updateContent()
        }
    }

    var rowIndex: Int = 0 {
        didSet {
            setAccessibilityIdentifier("\(AccessibilityID.OnlineDanmakuMatch.rowPrefix)\(rowIndex)")
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        badgeView.wantsLayer = true
        badgeView.layer?.cornerRadius = 3
        badgeView.layer?.backgroundColor = NSColor.mainColor.cgColor

        addSubview(titleLabel)
        addSubview(episodeLabel)
        addSubview(idLabel)
        addSubview(badgeView)
        badgeView.addSubview(typeLabel)

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.leading.equalToSuperview().offset(8)
            make.trailing.lessThanOrEqualTo(badgeView.snp.leading).offset(-8)
        }
        episodeLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
            make.leading.equalTo(titleLabel)
            make.trailing.lessThanOrEqualTo(badgeView.snp.leading).offset(-8)
        }
        idLabel.snp.makeConstraints { make in
            make.top.equalTo(episodeLabel.snp.bottom).offset(2)
            make.leading.equalTo(titleLabel)
            make.trailing.lessThanOrEqualTo(badgeView.snp.leading).offset(-8)
            make.bottom.lessThanOrEqualToSuperview().offset(-7)
        }
        badgeView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-10)
            make.centerY.equalToSuperview()
        }
        typeLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(6)
            make.top.bottom.equalToSuperview().inset(2)
        }
    }

    private func updateContent() {
        guard let match else {
            titleLabel.text = ""
            episodeLabel.text = ""
            idLabel.text = ""
            typeLabel.text = ""
            return
        }

        let animeTitle = match.animeTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let episodeTitle = match.episodeTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let typeDescription = match.typeDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let typeText = !typeDescription.isEmpty
            ? typeDescription
            : (match.type.displayName.isEmpty ? NSLocalizedString("弹幕库", comment: "") : match.type.displayName)

        titleLabel.text = animeTitle.isEmpty ? NSLocalizedString("未知作品", comment: "") : animeTitle
        episodeLabel.text = episodeTitle.isEmpty ? NSLocalizedString("未知剧集", comment: "") : episodeTitle
        idLabel.text = String(
            format: NSLocalizedString("弹幕库 #%d", comment: ""),
            match.episodeId
        )
        typeLabel.text = typeText
        badgeView.isHidden = typeText.isEmpty

        toolTip = "\(titleLabel.text ?? "")\n\(episodeLabel.text ?? "")\n\(typeText)"
        setAccessibilityLabel(
            "\(titleLabel.text ?? "")，\(episodeLabel.text ?? "")，\(typeText)"
        )
    }
}

// MARK: - View controller

final class OnlineDanmakuMatchViewController: ViewController {

    /// 用户做出选择后回调；窗口控制器负责关闭窗口。
    var onFinish: ((OnlineDanmakuMatchOutcome) -> Void)?

    private final class Row {
        let match: Match
        init(match: Match) {
            self.match = match
        }
    }

    private let initialKeyword: String
    private var rows: [Row] = []
    private var selectedMatch: Match?
    private var currentRequest: MatchNetworkHandle.MatchRequest?
    private var searchGeneration = 0
    private var didStartInitialSearch = false

    private lazy var searchField: NSSearchField = {
        let field = NSSearchField()
        field.stringValue = initialKeyword
        field.placeholderString = NSLocalizedString("弹幕库搜索关键词", comment: "")
        field.sendsWholeSearchString = true
        field.sendsSearchStringImmediately = false
        field.target = self
        field.action = #selector(searchAction)
        field.setAccessibilityIdentifier(AccessibilityID.OnlineDanmakuMatch.searchField)
        return field
    }()

    private lazy var searchButton: NSButton = {
        let button = NSButton(
            title: NSLocalizedString("搜索", comment: ""),
            target: self,
            action: #selector(searchAction)
        )
        button.bezelStyle = .rounded
        button.setAccessibilityIdentifier(AccessibilityID.OnlineDanmakuMatch.searchButton)
        return button
    }()

    private let searchSpinner: NSProgressIndicator = {
        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false
        spinner.isHidden = true
        return spinner
    }()

    private let statusLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 11),
        color: .secondaryLabelColor,
        lines: 2,
        lineBreakMode: .byWordWrapping
    )

    private lazy var scrollView: ScrollView<OutlineView> = {
        let outlineView = OutlineView()
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.style = .plain
        outlineView.rowSizeStyle = .custom
        outlineView.rowHeight = 68
        outlineView.headerView = nil
        outlineView.allowsEmptySelection = true
        outlineView.enableRowHoverTracking()
        outlineView.registerClassCell(class: OnlineDanmakuMatchCell.self)
        outlineView.target = self
        outlineView.doubleAction = #selector(doubleClickAction)
        outlineView.setAccessibilityIdentifier(AccessibilityID.OnlineDanmakuMatch.results)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "match"))
        column.isEditable = false
        column.resizingMask = .autoresizingMask
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.autoresizesOutlineColumn = false

        let scroll = ScrollView(containerView: outlineView)
        scroll.hasHorizontalScroller = false
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        return scroll
    }()

    private var outlineView: NSOutlineView {
        return scrollView.containerView
    }

    private lazy var startButton: NSButton = {
        let button = NSButton(
            title: NSLocalizedString("开始播放", comment: ""),
            target: self,
            action: #selector(startAction)
        )
        button.bezelStyle = .rounded
        button.keyEquivalent = "\r"
        button.isEnabled = false
        button.setAccessibilityIdentifier(AccessibilityID.OnlineDanmakuMatch.start)
        return button
    }()

    private lazy var directPlayButton: NSButton = {
        let button = NSButton(
            title: NSLocalizedString("直接播放（不加载弹幕）", comment: ""),
            target: self,
            action: #selector(directPlayAction)
        )
        button.bezelStyle = .rounded
        button.setAccessibilityIdentifier(AccessibilityID.OnlineDanmakuMatch.directPlay)
        return button
    }()

    private lazy var cancelButton: NSButton = {
        let button = NSButton(
            title: NSLocalizedString("取消", comment: ""),
            target: self,
            action: #selector(cancelAction)
        )
        button.bezelStyle = .rounded
        button.keyEquivalent = "\u{1b}"
        button.keyEquivalentModifierMask = []
        button.setAccessibilityIdentifier(AccessibilityID.OnlineDanmakuMatch.cancel)
        return button
    }()

    init(initialKeyword: String) {
        self.initialKeyword = OnlineDanmakuMatchQuery.normalizeVirtualName(initialKeyword)
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        currentRequest?.cancel()
    }

    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 660, height: 520))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.setAccessibilityIdentifier(AccessibilityID.OnlineDanmakuMatch.root)
        statusLabel.setAccessibilityIdentifier(AccessibilityID.OnlineDanmakuMatch.status)

        let titleLabel = welcomeShellLabel(
            NSLocalizedString("选择弹幕库", comment: ""),
            font: .systemFont(ofSize: 16, weight: .semibold),
            color: .labelColor
        )
        let hintLabel = welcomeShellLabel(
            NSLocalizedString("默认使用在线剧集的虚拟文件名匹配，可修改后重新搜索。", comment: ""),
            font: .systemFont(ofSize: 11),
            color: .secondaryLabelColor,
            lines: 2,
            lineBreakMode: .byWordWrapping
        )

        let searchRow = NSStackView(views: [searchField, searchButton, searchSpinner])
        searchRow.orientation = .horizontal
        searchRow.alignment = .centerY
        searchRow.spacing = 8
        searchRow.distribution = .fill
        searchField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        searchButton.setContentHuggingPriority(.required, for: .horizontal)
        searchSpinner.setContentHuggingPriority(.required, for: .horizontal)

        let footerHint = welcomeShellLabel(
            NSLocalizedString("双击匹配结果可直接开始播放", comment: ""),
            font: .systemFont(ofSize: 10.5),
            color: .tertiaryLabelColor
        )
        footerHint.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let footerSpacer = NSView()
        footerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        footerSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let footer = NSStackView(views: [
            footerHint,
            footerSpacer,
            cancelButton,
            directPlayButton,
            startButton
        ])
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 8

        view.addSubview(titleLabel)
        view.addSubview(hintLabel)
        view.addSubview(searchRow)
        view.addSubview(statusLabel)
        view.addSubview(scrollView)
        view.addSubview(footer)

        titleLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().offset(18)
            make.trailing.equalToSuperview().offset(-18)
        }
        hintLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.leading.trailing.equalTo(titleLabel)
        }
        searchRow.snp.makeConstraints { make in
            make.top.equalTo(hintLabel.snp.bottom).offset(12)
            make.leading.trailing.equalTo(titleLabel)
        }
        searchField.snp.makeConstraints { make in
            make.width.greaterThanOrEqualTo(260)
        }
        searchSpinner.snp.makeConstraints { make in
            make.width.height.equalTo(16)
        }
        statusLabel.snp.makeConstraints { make in
            make.top.equalTo(searchRow.snp.bottom).offset(6)
            make.leading.trailing.equalTo(titleLabel)
        }
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(statusLabel.snp.bottom).offset(8)
            make.leading.trailing.equalTo(titleLabel)
            make.bottom.equalTo(footer.snp.top).offset(-12)
        }
        footer.snp.makeConstraints { make in
            make.leading.trailing.equalTo(titleLabel)
            make.bottom.equalToSuperview().offset(-16)
            make.height.greaterThanOrEqualTo(28)
        }
        startButton.snp.makeConstraints { make in
            make.width.greaterThanOrEqualTo(90)
        }
        cancelButton.snp.makeConstraints { make in
            make.width.greaterThanOrEqualTo(64)
        }

        updateStatus(.idle)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        guard !didStartInitialSearch else { return }
        didStartInitialSearch = true
        startSearch(with: searchField.stringValue)
    }

    // MARK: Search

    @objc private func searchAction() {
        startSearch(with: searchField.stringValue)
    }

    private func startSearch(with rawKeyword: String) {
        let keyword = OnlineDanmakuMatchQuery.normalizeVirtualName(rawKeyword)
        guard !keyword.isEmpty else {
            updateStatus(.message(NSLocalizedString("请输入搜索关键词", comment: "")))
            return
        }

        searchField.stringValue = keyword
        searchGeneration += 1
        let generation = searchGeneration

        currentRequest?.cancel()
        currentRequest = nil
        rows = []
        selectedMatch = nil
        outlineView.deselectAll(nil)
        outlineView.reloadData()
        startButton.isEnabled = false
        searchButton.isEnabled = false
        searchSpinner.isHidden = false
        searchSpinner.startAnimation(nil)
        updateStatus(.searching)

        currentRequest = MatchNetworkHandle.match(
            fileName: keyword,
            matchMode: .fileNameOnly
        ) { [weak self] collection, error in
            DispatchQueue.main.async {
                guard let self, generation == self.searchGeneration else { return }
                self.finishSearch(collection: collection, error: error)
            }
        }
    }

    private func finishSearch(collection: MatchCollection?, error: Error?) {
        searchButton.isEnabled = true
        searchSpinner.stopAnimation(nil)
        searchSpinner.isHidden = true
        currentRequest = nil

        if let error {
            updateStatus(.error(error))
            return
        }

        let matches = collection?.collection ?? []
        rows = matches.map { Row(match: $0) }
        outlineView.reloadData()
        if rows.isEmpty {
            updateStatus(.empty)
        } else {
            outlineView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            outlineView.scrollRowToVisible(0)
            selectedMatch = rows[0].match
            startButton.isEnabled = true
            updateStatus(.resultCount(rows.count))
        }
    }

    /// 取消正在进行的搜索；窗口关闭时调用，避免网络回调继续持有窗口。
    func cancelPendingSearch() {
        searchGeneration += 1
        currentRequest?.cancel()
        currentRequest = nil
        searchSpinner.stopAnimation(nil)
        searchSpinner.isHidden = true
        searchButton.isEnabled = true
    }

    // MARK: Actions

    @objc private func startAction() {
        guard let selectedMatch else { return }
        finish(with: .matched(selectedMatch))
    }

    @objc private func directPlayAction() {
        finish(with: .directPlay)
    }

    @objc private func cancelAction() {
        finish(with: .cancelled)
    }

    @objc private func doubleClickAction() {
        let row = outlineView.clickedRow
        guard row >= 0, row < rows.count else { return }
        finish(with: .matched(rows[row].match))
    }

    private func finish(with outcome: OnlineDanmakuMatchOutcome) {
        cancelPendingSearch()
        onFinish?(outcome)
    }

    // MARK: Status

    private enum Status {
        case idle
        case message(String)
        case searching
        case empty
        case error(Error)
        case resultCount(Int)
    }

    private func updateStatus(_ status: Status) {
        switch status {
        case .idle:
            statusLabel.text = NSLocalizedString("请选择匹配结果，或直接播放（不加载弹幕）", comment: "")
        case .message(let message):
            statusLabel.text = message
        case .searching:
            statusLabel.text = NSLocalizedString("正在搜索弹幕库…", comment: "")
        case .empty:
            statusLabel.text = NSLocalizedString("没有找到匹配的弹幕库，可修改关键词后重新搜索", comment: "")
        case .error(let error):
            statusLabel.text = String(
                format: NSLocalizedString("搜索弹幕库失败：%@", comment: ""),
                error.localizedDescription
            )
        case .resultCount(let count):
            statusLabel.text = String(
                format: NSLocalizedString("已找到 %d 个匹配结果", comment: ""),
                count
            )
        }
    }
}

// MARK: - Outline view data source / delegate

extension OnlineDanmakuMatchViewController: NSOutlineViewDataSource {

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return rows.count
        }
        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        return rows[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return false
    }
}

extension OnlineDanmakuMatchViewController: NSOutlineViewDelegate {

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let row = item as? Row else { return nil }
        let cell = outlineView.dequeueReusableCell(class: OnlineDanmakuMatchCell.self)
        let index = rows.firstIndex { $0 === row } ?? 0
        cell.rowIndex = index
        cell.match = row.match
        return cell
    }

    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        return outlineView.themedRowView(forRow: outlineView.row(forItem: item))
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard let outlineView = notification.object as? NSOutlineView else { return }
        let row = outlineView.selectedRow
        guard row >= 0, row < rows.count else {
            selectedMatch = nil
            startButton.isEnabled = false
            return
        }
        selectedMatch = rows[row].match
        startButton.isEnabled = true
    }
}
