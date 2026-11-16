//
//  LocalLibraryEpisodeListViewController.swift
//  AniXPlayer
//
//  macOS：本地媒体库的剧集分组弹窗。
//

import Cocoa
import SnapKit

final class LocalLibraryEpisodeListViewController: ViewController {

    var onPlay: (([LocalLibraryFile], LocalLibraryFile) -> Void)?

    private let group: LocalLibraryAnimeGroup

    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let playAllButton = NSButton(title: "", target: nil, action: nil)
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()

    init(group: LocalLibraryAnimeGroup) {
        self.group = group
        super.init()
        preferredContentSize = NSSize(width: 680, height: 500)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 680, height: 500))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.setAccessibilityIdentifier(AccessibilityID.LocalLibrary.episodeSheet)
        setup()
    }

    private func setup() {
        titleLabel.stringValue = group.animeTitle
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 2

        let missingText = group.missingCount > 0
            ? " · " + String(format: NSLocalizedString("缺失 %d 集", comment: ""), group.missingCount)
            : ""
        detailLabel.stringValue = String(
            format: NSLocalizedString("%d 集 · %@%@", comment: ""),
            group.episodeCount,
            group.sizeText,
            missingText
        )
        detailLabel.font = .systemFont(ofSize: 11.5)
        detailLabel.textColor = .secondaryLabelColor

        playAllButton.title = NSLocalizedString("播放全部", comment: "")
        playAllButton.bezelStyle = .rounded
        playAllButton.target = self
        playAllButton.action = #selector(playAllTapped)
        playAllButton.isEnabled = group.files.contains(where: { !$0.isMissing })
        playAllButton.setAccessibilityIdentifier(AccessibilityID.LocalLibrary.episodePlayAll)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("episode"))
        column.title = NSLocalizedString("剧集", comment: "")
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 46
        tableView.intercellSpacing = NSSize(width: 0, height: 1)
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.gridStyleMask = []
        tableView.allowsMultipleSelection = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.doubleAction = #selector(rowDoubleClicked)
        tableView.setAccessibilityIdentifier(AccessibilityID.LocalLibrary.episodeTable)

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let closeButton = NSButton(
            title: NSLocalizedString("关闭", comment: ""),
            target: self,
            action: #selector(closeTapped)
        )
        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = "\u{1b}"
        closeButton.setAccessibilityIdentifier(AccessibilityID.LocalLibrary.episodeClose)

        view.addSubview(titleLabel)
        view.addSubview(detailLabel)
        view.addSubview(playAllButton)
        view.addSubview(scrollView)
        view.addSubview(closeButton)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalTo(playAllButton.snp.leading).offset(-12)
            make.top.equalToSuperview().offset(18)
        }
        detailLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.trailing.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
        }
        playAllButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalTo(titleLabel)
        }
        scrollView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.top.equalTo(detailLabel.snp.bottom).offset(12)
            make.bottom.equalTo(closeButton.snp.top).offset(-12)
        }
        closeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.bottom.equalToSuperview().offset(-16)
        }
    }

    private func play(_ file: LocalLibraryFile) {
        guard !file.isMissing else { return }
        let callback = onPlay
        let files = group.files
        dismiss(self)
        DispatchQueue.main.async {
            callback?(files, file)
        }
    }

    @objc private func playAllTapped() {
        guard let first = group.files.first(where: { !$0.isMissing }) else { return }
        let callback = onPlay
        let files = group.files
        dismiss(self)
        DispatchQueue.main.async {
            callback?(files, first)
        }
    }

    @objc private func rowDoubleClicked() {
        let row = tableView.clickedRow
        guard row >= 0, row < group.files.count else { return }
        play(group.files[row])
    }

    @objc private func closeTapped() {
        dismiss(self)
    }
}

extension LocalLibraryEpisodeListViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        group.files.count
    }
}

extension LocalLibraryEpisodeListViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < group.files.count else { return nil }
        let identifier = NSUserInterfaceItemIdentifier("LocalLibraryEpisodeCell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? LocalLibraryEpisodeCellView
            ?? LocalLibraryEpisodeCellView(identifier: identifier)
        let file = group.files[row]
        cell.update(with: file)
        cell.onPlay = { [weak self] in self?.play(file) }
        cell.setAccessibilityIdentifier("\(AccessibilityID.LocalLibrary.episodePrefix)\(file.id)")
        return cell
    }
}

// MARK: - Row

private final class LocalLibraryEpisodeCellView: NSTableCellView {

    var onPlay: (() -> Void)?

    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let missingLabel = NSTextField(labelWithString: "")
    private let playButton = NSButton(title: "", target: nil, action: nil)

    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: .zero)
        self.identifier = identifier
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        titleLabel.font = .systemFont(ofSize: 12.5, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail
        detailLabel.font = .systemFont(ofSize: 10.5)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byTruncatingMiddle
        missingLabel.font = .systemFont(ofSize: 10.5, weight: .semibold)
        missingLabel.textColor = .systemRed

        playButton.image = NSImage.safeSystemSymbol("play.circle")
        playButton.isBordered = false
        playButton.bezelStyle = .inline
        playButton.contentTintColor = .controlAccentColor
        playButton.toolTip = NSLocalizedString("播放", comment: "")
        playButton.target = self
        playButton.action = #selector(playTapped)

        addSubview(titleLabel)
        addSubview(detailLabel)
        addSubview(missingLabel)
        addSubview(playButton)

        playButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-10)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(22)
        }
        missingLabel.snp.makeConstraints { make in
            make.trailing.equalTo(playButton.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.trailing.lessThanOrEqualTo(missingLabel.snp.leading).offset(-8)
            make.top.equalToSuperview().offset(7)
        }
        detailLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.trailing.lessThanOrEqualTo(missingLabel.snp.leading).offset(-8)
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
        }
    }

    func update(with file: LocalLibraryFile) {
        titleLabel.stringValue = file.displayEpisodeTitle
        titleLabel.textColor = file.isMissing ? .secondaryLabelColor : .labelColor

        var parts = [file.fileName]
        parts.append(file.sizeText)
        if !file.mediaMetadata.isEmpty {
            parts.append(file.mediaMetadata.displayText)
        }
        detailLabel.stringValue = parts.joined(separator: " · ")
        missingLabel.stringValue = file.isMissing ? NSLocalizedString("缺失", comment: "") : ""
        playButton.isEnabled = !file.isMissing
        playButton.setAccessibilityIdentifier("\(AccessibilityID.LocalLibrary.episodePrefix)\(file.id).play")
        playButton.setAccessibilityLabel(
            "\(NSLocalizedString("播放", comment: "")) \(file.displayEpisodeTitle)"
        )
        toolTip = file.path
    }

    @objc private func playTapped() {
        onPlay?()
    }
}
