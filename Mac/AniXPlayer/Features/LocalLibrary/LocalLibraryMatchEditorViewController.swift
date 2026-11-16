//
//  LocalLibraryMatchEditorViewController.swift
//  AniXPlayer
//
//  macOS：本地媒体库的匹配修正。
//  通过现有 /search/anime 搜索 Bangumi，再用 /bangumi/{id} 加载剧集，
//  由用户明确选择番剧和剧集后写入媒体库；搜索失败不会伪造结果。
//

import Cocoa
import SnapKit

final class LocalLibraryMatchEditorViewController: ViewController {

    /// 匹配写入或取消后回调，让媒体库刷新。
    var onApplied: (() -> Void)?

    private let store: LocalLibraryStore
    private let targets: [LocalLibraryFile]

    private var targetIndex = 0
    private var animeResults: [SearchUpgradeAnimeItem] = []
    private var selectedAnime: SearchUpgradeAnimeItem?
    private var detail: BangumiDetail?
    private var episodes: [BangumiEpisode] = []
    private var selectedEpisode: BangumiEpisode?
    private var searchTask: Task<Void, Never>?
    private var episodeRequestGeneration = 0

    private let headerLabel = NSTextField(labelWithString: "")
    private let hintLabel = NSTextField(labelWithString: "")
    private let targetLabel = NSTextField(labelWithString: "")
    private let targetPopup = NSPopUpButton()
    private let searchField = NSSearchField()
    private let searchButton = NSButton(title: "", target: nil, action: nil)
    private let spinner = NSProgressIndicator()
    private let animeTable = NSTableView()
    private let episodeTable = NSTableView()
    private let animeScroll = NSScrollView()
    private let episodeScroll = NSScrollView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let applyButton = NSButton(title: "", target: nil, action: nil)
    private let clearButton = NSButton(title: "", target: nil, action: nil)
    private let cancelButton = NSButton(title: "", target: nil, action: nil)

    init(store: LocalLibraryStore, targets: [LocalLibraryFile]) {
        self.store = store
        self.targets = targets
        super.init()
        preferredContentSize = NSSize(width: 820, height: 590)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        searchTask?.cancel()
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 820, height: 590))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.setAccessibilityIdentifier(AccessibilityID.LocalLibrary.matchSheet)
        setup()
        updateTargetUI()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        searchField.becomeFirstResponder()
    }

    // MARK: - Setup

    private func setup() {
        headerLabel.stringValue = NSLocalizedString("匹配修正", comment: "")
        headerLabel.font = .systemFont(ofSize: 18, weight: .bold)

        hintLabel.stringValue = NSLocalizedString(
            "搜索 Bangumi 番剧，选择番剧和剧集后写入媒体库。只显示真实搜索结果。",
            comment: ""
        )
        hintLabel.font = .systemFont(ofSize: 11)
        hintLabel.textColor = .secondaryLabelColor

        targetLabel.stringValue = NSLocalizedString("目标文件", comment: "")
        targetLabel.font = .systemFont(ofSize: 11, weight: .medium)
        targetLabel.textColor = .secondaryLabelColor
        targetPopup.target = self
        targetPopup.action = #selector(targetChanged)
        targetPopup.setAccessibilityIdentifier(AccessibilityID.LocalLibrary.matchTarget)

        searchField.placeholderString = NSLocalizedString("搜索番剧标题…", comment: "")
        searchField.target = self
        searchField.action = #selector(searchTapped)
        searchField.sendsSearchStringImmediately = false
        searchField.setAccessibilityIdentifier(AccessibilityID.LocalLibrary.matchSearch)

        searchButton.title = NSLocalizedString("搜索", comment: "")
        searchButton.bezelStyle = .rounded
        searchButton.target = self
        searchButton.action = #selector(searchTapped)
        searchButton.keyEquivalent = "\r"
        searchButton.setAccessibilityIdentifier(AccessibilityID.LocalLibrary.matchSearchButton)

        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false

        configure(table: animeTable, identifier: AccessibilityID.LocalLibrary.matchResults)
        configure(table: episodeTable, identifier: AccessibilityID.LocalLibrary.matchEpisodes)
        animeScroll.documentView = animeTable
        episodeScroll.documentView = episodeTable
        for scroll in [animeScroll, episodeScroll] {
            scroll.hasVerticalScroller = true
            scroll.autohidesScrollers = true
            scroll.drawsBackground = false
            scroll.borderType = .bezelBorder
        }

        statusLabel.font = .systemFont(ofSize: 11.5)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.stringValue = NSLocalizedString("输入番剧标题开始搜索", comment: "")

        applyButton.title = NSLocalizedString("应用匹配", comment: "")
        applyButton.bezelStyle = .rounded
        applyButton.target = self
        applyButton.action = #selector(applyTapped)
        applyButton.isEnabled = false
        applyButton.setAccessibilityIdentifier(AccessibilityID.LocalLibrary.matchApply)

        clearButton.title = NSLocalizedString("取消匹配", comment: "")
        clearButton.bezelStyle = .rounded
        clearButton.target = self
        clearButton.action = #selector(clearTapped)
        clearButton.setAccessibilityIdentifier(AccessibilityID.LocalLibrary.matchClear)

        cancelButton.title = NSLocalizedString("关闭", comment: "")
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelTapped)
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.setAccessibilityIdentifier(AccessibilityID.LocalLibrary.matchCancel)

        let animeHeader = makeSectionLabel(NSLocalizedString("番剧", comment: ""))
        let episodeHeader = makeSectionLabel(NSLocalizedString("剧集", comment: ""))

        view.addSubview(headerLabel)
        view.addSubview(hintLabel)
        view.addSubview(targetLabel)
        view.addSubview(targetPopup)
        view.addSubview(searchField)
        view.addSubview(searchButton)
        view.addSubview(spinner)
        view.addSubview(animeHeader)
        view.addSubview(episodeHeader)
        view.addSubview(animeScroll)
        view.addSubview(episodeScroll)
        view.addSubview(statusLabel)
        view.addSubview(applyButton)
        view.addSubview(clearButton)
        view.addSubview(cancelButton)

        headerLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.top.equalToSuperview().offset(18)
        }
        hintLabel.snp.makeConstraints { make in
            make.leading.equalTo(headerLabel)
            make.trailing.equalTo(headerLabel)
            make.top.equalTo(headerLabel.snp.bottom).offset(3)
        }
        targetLabel.snp.makeConstraints { make in
            make.leading.equalTo(headerLabel)
            make.top.equalTo(hintLabel.snp.bottom).offset(12)
        }
        targetPopup.snp.makeConstraints { make in
            make.leading.equalTo(targetLabel.snp.trailing).offset(8)
            make.centerY.equalTo(targetLabel)
            make.width.equalTo(360)
        }
        searchField.snp.makeConstraints { make in
            make.leading.equalTo(headerLabel)
            make.top.equalTo(targetLabel.snp.bottom).offset(12)
            make.width.equalTo(420)
        }
        searchButton.snp.makeConstraints { make in
            make.leading.equalTo(searchField.snp.trailing).offset(8)
            make.centerY.equalTo(searchField)
            make.width.equalTo(70)
        }
        spinner.snp.makeConstraints { make in
            make.leading.equalTo(searchButton.snp.trailing).offset(8)
            make.centerY.equalTo(searchField)
            make.width.height.equalTo(16)
        }
        animeHeader.snp.makeConstraints { make in
            make.leading.equalTo(headerLabel)
            make.top.equalTo(searchField.snp.bottom).offset(12)
        }
        episodeHeader.snp.makeConstraints { make in
            make.leading.equalTo(animeScroll.snp.trailing).offset(12)
            make.top.equalTo(animeHeader)
        }
        animeScroll.snp.makeConstraints { make in
            make.leading.equalTo(headerLabel)
            make.top.equalTo(animeHeader.snp.bottom).offset(4)
            make.width.equalTo(300)
            make.bottom.equalTo(statusLabel.snp.top).offset(-12)
        }
        episodeScroll.snp.makeConstraints { make in
            make.leading.equalTo(animeScroll.snp.trailing).offset(12)
            make.trailing.equalToSuperview().offset(-20)
            make.top.equalTo(animeScroll)
            make.bottom.equalTo(animeScroll)
        }
        statusLabel.snp.makeConstraints { make in
            make.leading.equalTo(headerLabel)
            make.trailing.lessThanOrEqualTo(clearButton.snp.leading).offset(-12)
            make.bottom.equalTo(cancelButton.snp.bottom)
        }
        cancelButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.bottom.equalToSuperview().offset(-16)
            make.width.equalTo(80)
        }
        clearButton.snp.makeConstraints { make in
            make.trailing.equalTo(cancelButton.snp.leading).offset(-8)
            make.centerY.equalTo(cancelButton)
            make.width.equalTo(92)
        }
        applyButton.snp.makeConstraints { make in
            make.trailing.equalTo(clearButton.snp.leading).offset(-8)
            make.centerY.equalTo(cancelButton)
            make.width.equalTo(92)
        }
    }

    private func configure(table: NSTableView, identifier: String) {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
        column.title = ""
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.headerView = nil
        table.rowHeight = 46
        table.intercellSpacing = NSSize(width: 0, height: 1)
        table.gridStyleMask = []
        table.allowsMultipleSelection = false
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.doubleAction = #selector(tableDoubleClicked)
        table.setAccessibilityIdentifier(identifier)
    }

    private func makeSectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .secondaryLabelColor
        return label
    }

    // MARK: - Target

    private var currentTarget: LocalLibraryFile? {
        guard targetIndex >= 0, targetIndex < targets.count else { return nil }
        return targets[targetIndex]
    }

    private func updateTargetUI() {
        guard !targets.isEmpty else { return }
        targetPopup.removeAllItems()
        targetPopup.addItems(withTitles: targets.map { file in
            "\(file.displayEpisodeTitle) — \(file.fileName)"
        })
        targetPopup.selectItem(at: targetIndex)
        targetPopup.isHidden = targets.count <= 1
        targetLabel.isHidden = targets.count <= 1

        let target = targets[targetIndex]
        if searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let title = target.animeTitle, !title.isEmpty {
            searchField.stringValue = title
        }
        statusLabel.stringValue = target.isMatched
            ? String(
                format: NSLocalizedString("当前：%@ · %@", comment: ""),
                target.animeTitle ?? "",
                target.episodeTitle ?? ""
            )
            : NSLocalizedString("当前文件尚未匹配，可搜索番剧手动修正。", comment: "")
    }

    @objc private func targetChanged() {
        targetIndex = max(0, targetPopup.indexOfSelectedItem)
        updateTargetUI()
        updateApplyState()
    }

    // MARK: - Search

    @objc private func searchTapped() {
        let keyword = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            statusLabel.stringValue = NSLocalizedString("请输入搜索关键词", comment: "")
            return
        }

        searchTask?.cancel()
        episodeRequestGeneration += 1
        animeResults = []
        selectedAnime = nil
        detail = nil
        episodes = []
        selectedEpisode = nil
        animeTable.reloadData()
        episodeTable.reloadData()
        updateApplyState()

        spinner.startAnimation(nil)
        searchButton.isEnabled = false
        statusLabel.stringValue = NSLocalizedString("正在搜索…", comment: "")

        searchTask = Task { @MainActor [weak self] in
            guard let self else { return }
            guard await LoginGate.shared.ensureAccessToken(presenting: self.view.window) else {
                self.finishSearch()
                self.statusLabel.stringValue = NSLocalizedString("登录后才能搜索番剧", comment: "")
                return
            }
            do {
                let response = try await SearchUpgradeNetworkHandle.searchAnime(keyword: keyword)
                try Task.checkCancellation()
                self.animeResults = response.animes.filter { $0.animeId > 0 }
                self.finishSearch()
                if self.animeResults.isEmpty {
                    self.statusLabel.stringValue = NSLocalizedString("没有找到番剧，请尝试其他关键词", comment: "")
                } else {
                    self.statusLabel.stringValue = String(
                        format: NSLocalizedString("找到 %d 个番剧，请选择", comment: ""),
                        self.animeResults.count
                    )
                }
                self.animeTable.reloadData()
            } catch is CancellationError {
                // 新搜索替换旧搜索。
            } catch let error as APIError {
                self.finishSearch()
                if case .cancelled = error { return }
                self.statusLabel.stringValue = error.localizedDescription
            } catch {
                self.finishSearch()
                self.statusLabel.stringValue = error.localizedDescription
            }
        }
    }

    private func finishSearch() {
        spinner.stopAnimation(nil)
        searchButton.isEnabled = true
    }

    private func loadEpisodes(for anime: SearchUpgradeAnimeItem) {
        selectedAnime = anime
        selectedEpisode = nil
        detail = nil
        episodes = []
        episodeTable.reloadData()
        updateApplyState()

        episodeRequestGeneration += 1
        let generation = episodeRequestGeneration
        statusLabel.stringValue = NSLocalizedString("正在加载剧集…", comment: "")

        BangumiNetworkHandle.detail(animateId: anime.animeId) { [weak self] response, error in
            DispatchQueue.main.async {
                guard let self, self.episodeRequestGeneration == generation else { return }
                if let error {
                    self.statusLabel.stringValue = error.localizedDescription
                    return
                }
                guard let bangumi = response?.bangumi else {
                    self.statusLabel.stringValue = NSLocalizedString("没有读取到剧集", comment: "")
                    return
                }
                self.detail = bangumi
                self.episodes = Self.orderedEpisodes(bangumi.episodes.filter { $0.episodeId > 0 })
                self.episodeTable.reloadData()
                self.statusLabel.stringValue = self.episodes.isEmpty
                    ? NSLocalizedString("该番剧没有可匹配的剧集", comment: "")
                    : String(
                        format: NSLocalizedString("已加载 %d 集，请选择剧集", comment: ""),
                        self.episodes.count
                    )
            }
        }
    }

    private static func orderedEpisodes(_ episodes: [BangumiEpisode]) -> [BangumiEpisode] {
        episodes.sorted { lhs, rhs in
            let lhsText = lhs.episodeNumber.isEmpty ? lhs.episodeTitle : lhs.episodeNumber
            let rhsText = rhs.episodeNumber.isEmpty ? rhs.episodeTitle : rhs.episodeNumber
            let lhsNumber = LocalLibraryGrouping.episodeNumber(from: lhsText)
            let rhsNumber = LocalLibraryGrouping.episodeNumber(from: rhsText)
            switch (lhsNumber, rhsNumber) {
            case let (lhsNumber?, rhsNumber?) where lhsNumber != rhsNumber:
                return lhsNumber < rhsNumber
            case (nil, .some):
                return false
            case (.some, nil):
                return true
            default:
                return lhsText.localizedStandardCompare(rhsText) == .orderedAscending
            }
        }
    }

    // MARK: - Apply

    private func updateApplyState() {
        applyButton.isEnabled = selectedAnime != nil && selectedEpisode != nil && currentTarget != nil
    }

    @objc private func applyTapped() {
        guard let target = currentTarget,
              let anime = selectedAnime,
              let episode = selectedEpisode else { return }

        let bangumi = detail
        let animeTitle: String = {
            if let title = bangumi?.animeTitle, !title.isEmpty { return title }
            return anime.animeTitle
        }()
        let info = LocalLibraryMatchInfo(
            animeId: anime.animeId,
            episodeId: episode.episodeId,
            animeTitle: animeTitle,
            episodeTitle: episode.episodeTitle,
            imageUrl: {
                if let imageUrl = bangumi?.imageUrl, !imageUrl.isEmpty, imageUrl != "Unknown" {
                    return imageUrl
                }
                if !anime.imageUrl.isEmpty, anime.imageUrl != "Unknown" {
                    return anime.imageUrl
                }
                return nil
            }(),
            type: {
                if let type = bangumi?.type.rawValue, !type.isEmpty {
                    return type
                }
                return anime.type.isEmpty ? nil : anime.type
            }()
        )

        do {
            _ = try store.applyManualMatch(fileId: target.id, info: info)
            onApplied?()
            dismiss(self)
        } catch {
            statusLabel.stringValue = error.localizedDescription
        }
    }

    @objc private func clearTapped() {
        guard let target = currentTarget else { return }
        do {
            _ = try store.clearMatch(fileId: target.id)
            onApplied?()
            dismiss(self)
        } catch {
            statusLabel.stringValue = error.localizedDescription
        }
    }

    @objc private func cancelTapped() {
        searchTask?.cancel()
        dismiss(self)
    }

    @objc private func tableDoubleClicked() {
        if animeTable.clickedRow >= 0, animeTable.clickedRow < animeResults.count {
            animeTable.selectRowIndexes(IndexSet(integer: animeTable.clickedRow), byExtendingSelection: false)
            loadEpisodes(for: animeResults[animeTable.clickedRow])
        } else if episodeTable.clickedRow >= 0, episodeTable.clickedRow < episodes.count {
            episodeTable.selectRowIndexes(IndexSet(integer: episodeTable.clickedRow), byExtendingSelection: false)
            selectedEpisode = episodes[episodeTable.clickedRow]
            updateApplyState()
        }
    }
}

extension LocalLibraryMatchEditorViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        tableView === animeTable ? animeResults.count : episodes.count
    }
}

extension LocalLibraryMatchEditorViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier(
            tableView === animeTable ? "LocalLibraryMatchAnimeCell" : "LocalLibraryMatchEpisodeCell"
        )
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? LocalLibraryMatchCellView
            ?? LocalLibraryMatchCellView(identifier: identifier)

        if tableView === animeTable {
            guard row < animeResults.count else { return nil }
            let anime = animeResults[row]
            var parts: [String] = []
            if !anime.typeDescription.isEmpty { parts.append(anime.typeDescription) }
            if anime.episodeCount > 0 {
                parts.append(String(format: NSLocalizedString("%d 集", comment: ""), anime.episodeCount))
            }
            if anime.rating > 0 {
                parts.append(String(format: "⭐ %.1f", anime.rating))
            }
            cell.update(title: anime.animeTitle, detail: parts.joined(separator: " · "))
        } else {
            guard row < episodes.count else { return nil }
            let episode = episodes[row]
            let number = episode.episodeNumber.isEmpty ? "" : episode.episodeNumber
            cell.update(title: episode.episodeTitle, detail: number)
        }
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let table = notification.object as? NSTableView else { return }
        if table === animeTable {
            let row = animeTable.selectedRow
            guard row >= 0, row < animeResults.count else { return }
            loadEpisodes(for: animeResults[row])
        } else if table === episodeTable {
            let row = episodeTable.selectedRow
            guard row >= 0, row < episodes.count else {
                selectedEpisode = nil
                updateApplyState()
                return
            }
            selectedEpisode = episodes[row]
            updateApplyState()
        }
    }
}

// MARK: - Row

private final class LocalLibraryMatchCellView: NSTableCellView {

    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")

    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: .zero)
        self.identifier = identifier
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail
        detailLabel.font = .systemFont(ofSize: 10)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byTruncatingTail

        addSubview(titleLabel)
        addSubview(detailLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.trailing.equalToSuperview().offset(-6)
            make.top.equalToSuperview().offset(7)
        }
        detailLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.trailing.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
        }
    }

    func update(title: String, detail: String) {
        titleLabel.stringValue = title
        detailLabel.stringValue = detail
    }
}
