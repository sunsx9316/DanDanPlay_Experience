//
//  BangumiDetailTrackingCardView.swift
//  AniXPlayer
//
//  macOS：番剧详情的追番状态 / 评分 / 短评编辑卡片。
//

import Cocoa
import SnapKit

final class BangumiDetailTrackingCardView: BangumiDetailCardView, NSTextViewDelegate {

    struct Edit {
        /// nil 表示不修改状态。
        let status: FavoriteStatus?
        /// nil 表示不修改评分；0 不能在保存时表示“清空”。
        let rating: Int?
        /// nil 表示不修改；一个空格表示清空。
        let comment: String?
        /// true 时执行取消关注（DELETE），忽略 rating/comment。
        let shouldRemove: Bool

        var isEmpty: Bool {
            status == nil && rating == nil && comment == nil && !shouldRemove
        }
    }

    var onSave: ((Edit) -> Void)?

    private var detail: BangumiDetail?
    private var pendingStatus: FavoriteStatus?
    private var pendingRemove = false
    private var selectedRating = 0
    private var serverComment = ""

    private enum StatusTag {
        static let none = 100
        static let favorited = 0
        static let finished = 1
        static let abandoned = 2
        static let remove = 3
    }

    private let statusPopup: NSPopUpButton = {
        let popup = NSPopUpButton()
        popup.addItem(withTitle: NSLocalizedString("未关注", comment: ""))
        popup.item(at: 0)?.tag = StatusTag.none
        popup.item(at: 0)?.isEnabled = false
        popup.addItems(withTitles: [
            NSLocalizedString("关注", comment: ""),
            NSLocalizedString("看完", comment: ""),
            NSLocalizedString("抛弃", comment: ""),
            NSLocalizedString("取消关注", comment: ""),
        ])
        popup.item(at: 1)?.tag = StatusTag.favorited
        popup.item(at: 2)?.tag = StatusTag.finished
        popup.item(at: 3)?.tag = StatusTag.abandoned
        popup.item(at: 4)?.tag = StatusTag.remove
        popup.setAccessibilityIdentifier(AccessibilityID.Favorite.detailStatusPopup)
        return popup
    }()

    private let currentStatusLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setAccessibilityIdentifier(AccessibilityID.Favorite.detailStatusLabel)
        return label
    }()

    private let ratingPopup: NSPopUpButton = {
        let popup = NSPopUpButton()
        popup.addItem(withTitle: NSLocalizedString("未评分", comment: ""))
        popup.item(at: 0)?.tag = 0
        for score in 1...10 {
            popup.addItem(withTitle: String(format: NSLocalizedString("%d 分", comment: ""), score))
            popup.item(at: score)?.tag = score
        }
        popup.setAccessibilityIdentifier(AccessibilityID.Favorite.detailRatingPopup)
        return popup
    }()

    private let commentTextView: NSTextView = {
        let textView = NSTextView()
        textView.font = .systemFont(ofSize: 12.5)
        textView.textColor = .textColor
        textView.drawsBackground = false
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.setAccessibilityIdentifier(AccessibilityID.Favorite.detailCommentView)
        return textView
    }()

    private let commentScrollView: ScrollView<NSTextView>
    private let commentCountLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.alignment = .right
        label.setAccessibilityIdentifier(AccessibilityID.Favorite.detailCommentCountLabel)
        return label
    }()
    private let saveButton = Button()
    private let clearCommentButton = Button()
    private let hintLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .systemFont(ofSize: 11.5)
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = 2
        label.lineBreakMode = .byWordWrapping
        label.cell?.wraps = true
        label.setAccessibilityIdentifier("detail.tracking.hint")
        return label
    }()

    override init(frame frameRect: NSRect) {
        self.commentScrollView = ScrollView<NSTextView>(containerView: NSTextView())
        super.init(frame: frameRect)
        commentScrollView.containerView = commentTextView
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with item: BangumiDetail) {
        detail = item
        pendingStatus = nil
        pendingRemove = false
        selectedRating = Int(item.userRating.rounded())
        serverComment = item.comment

        currentStatusLabel.text = statusDescription(for: item)
        statusPopup.selectItem(withTag: statusTag(for: item))
        ratingPopup.selectItem(withTag: selectedRating)
        // 服务端不支持通过 rating=0 清空评分，已评分的作品不再提供“未评分”选项。
        ratingPopup.item(at: 0)?.isEnabled = selectedRating == 0

        commentTextView.string = item.comment
        updateCommentCount()
        updateEditingState()
    }

    func textDidChange(_ notification: Notification) {
        guard notification.object as? NSTextView === commentTextView else { return }
        if commentTextView.string.count > FavoriteUserDataService.maxCommentLength {
            commentTextView.string = String(commentTextView.string.prefix(FavoriteUserDataService.maxCommentLength))
        }
        updateCommentCount()
    }

    override func layout() {
        super.layout()
        let contentSize = commentScrollView.contentSize
        guard contentSize.width > 0 else { return }
        if commentTextView.frame.width != contentSize.width {
            commentTextView.frame = NSRect(
                x: 0,
                y: 0,
                width: contentSize.width,
                height: max(commentTextView.frame.height, contentSize.height)
            )
        }
    }

    // MARK: - Setup

    private func setup() {
        setAccessibilityIdentifier(AccessibilityID.Favorite.detailRoot)
        let header = addStaticHeader(
            title: NSLocalizedString("我的追番", comment: ""),
            symbolName: "heart.text.square"
        )
        header.setAccessibilityIdentifier(AccessibilityID.BangumiDetail.tracking)

        statusPopup.addTarget(self, action: #selector(statusChanged))
        ratingPopup.addTarget(self, action: #selector(ratingChanged))
        saveButton.addTarget(self, action: #selector(saveClicked))
        clearCommentButton.addTarget(self, action: #selector(clearCommentClicked))
        commentTextView.delegate = self

        saveButton.title = NSLocalizedString("保存", comment: "")
        saveButton.bezelStyle = .rounded
        saveButton.setAccessibilityIdentifier(AccessibilityID.Favorite.detailSaveButton)
        clearCommentButton.title = NSLocalizedString("清空短评", comment: "")
        clearCommentButton.bezelStyle = .rounded
        clearCommentButton.setAccessibilityIdentifier(AccessibilityID.Favorite.detailClearCommentButton)

        commentScrollView.hasVerticalScroller = true
        commentScrollView.hasHorizontalScroller = false
        commentScrollView.borderType = .bezelBorder
        commentScrollView.drawsBackground = false
        commentScrollView.snp.makeConstraints { make in
            make.height.equalTo(78)
        }

        let statusTitle = makeRowTitle(NSLocalizedString("追番状态", comment: ""))
        statusPopup.snp.makeConstraints { make in
            make.width.equalTo(112)
        }
        let statusRow = NSStackView(views: [statusTitle, statusPopup, currentStatusLabel])
        statusRow.orientation = .horizontal
        statusRow.alignment = .centerY
        statusRow.spacing = 8

        let ratingTitle = makeRowTitle(NSLocalizedString("我的评分", comment: ""))
        ratingPopup.snp.makeConstraints { make in
            make.width.equalTo(90)
        }
        let ratingRow = NSStackView(views: [ratingTitle, ratingPopup])
        ratingRow.orientation = .horizontal
        ratingRow.alignment = .centerY
        ratingRow.spacing = 8

        let commentTitle = makeRowTitle(NSLocalizedString("短评", comment: ""))
        let commentSpacer = NSView()
        commentSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let commentHeaderRow = NSStackView(views: [commentTitle, commentSpacer, commentCountLabel])
        commentHeaderRow.orientation = .horizontal
        commentHeaderRow.alignment = .centerY
        commentHeaderRow.spacing = 8

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let actionRow = NSStackView(views: [spacer, clearCommentButton, saveButton])
        actionRow.orientation = .horizontal
        actionRow.alignment = .centerY
        actionRow.spacing = 8

        contentStack.addArrangedSubview(statusRow)
        contentStack.addArrangedSubview(ratingRow)
        contentStack.addArrangedSubview(commentHeaderRow)
        contentStack.addArrangedSubview(commentScrollView)
        contentStack.addArrangedSubview(hintLabel)
        contentStack.addArrangedSubview(actionRow)
        contentStack.setCustomSpacing(12, after: commentScrollView)
        contentStack.setCustomSpacing(8, after: hintLabel)

        updateEditingState()
    }

    private func makeRowTitle(_ title: String) -> Label {
        let label = Label(labelWithString: title)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.snp.makeConstraints { make in
            make.width.equalTo(64)
        }
        return label
    }

    // MARK: - Actions

    @objc private func statusChanged() {
        let tag = statusPopup.selectedTag()
        pendingRemove = tag == StatusTag.remove
        pendingStatus = status(from: tag)
        updateEditingState()
    }

    @objc private func ratingChanged() {
        selectedRating = ratingPopup.selectedTag()
    }

    @objc private func saveClicked() {
        guard let detail = detail else { return }

        if pendingRemove {
            onSave?(Edit(status: nil, rating: nil, comment: nil, shouldRemove: true))
            return
        }

        var status: FavoriteStatus?
        if let pendingStatus = pendingStatus, pendingStatus != currentStatus(of: detail) {
            status = pendingStatus
        }

        var rating: Int?
        let serverRating = Int(detail.userRating.rounded())
        if selectedRating != 0, selectedRating != serverRating {
            rating = selectedRating
        }

        var comment: String?
        let trimmedComment = commentTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedServerComment = serverComment.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedComment != trimmedServerComment {
            comment = trimmedComment.isEmpty ? " " : trimmedComment
        }

        let edit = Edit(status: status, rating: rating, comment: comment, shouldRemove: false)
        guard !edit.isEmpty else {
            window?.contentViewController?.view.show(text: NSLocalizedString("没有需要保存的修改", comment: ""))
            return
        }
        onSave?(edit)
    }

    @objc private func clearCommentClicked() {
        guard let detail = detail, detail.isFavorited, !pendingRemove else { return }
        onSave?(Edit(status: nil, rating: nil, comment: " ", shouldRemove: false))
    }

    // MARK: - Private

    private func updateEditingState() {
        let isFavorited = detail?.isFavorited == true
        let canEditDetails = isFavorited && !pendingRemove

        ratingPopup.isEnabled = canEditDetails
        commentTextView.isEditable = canEditDetails
        clearCommentButton.isEnabled = canEditDetails
            && !serverComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        saveButton.isEnabled = canEditDetails || pendingStatus != nil || pendingRemove

        if pendingRemove {
            hintLabel.text = NSLocalizedString("保存后将取消关注，评分和短评将无法编辑。", comment: "")
        } else if isFavorited {
            hintLabel.text = NSLocalizedString("修改状态、评分或短评后点击保存生效。", comment: "")
        } else {
            hintLabel.text = NSLocalizedString("选择「关注」「看完」或「抛弃」并保存后，即可评分和撰写短评。", comment: "")
        }
    }

    private func updateCommentCount() {
        let count = commentTextView.string.count
        commentCountLabel.text = "\(count)/\(FavoriteUserDataService.maxCommentLength)"
        commentCountLabel.textColor = count >= FavoriteUserDataService.maxCommentLength
            ? .systemRed
            : .secondaryLabelColor
    }

    private func statusTag(for detail: BangumiDetail) -> Int {
        guard detail.isFavorited else { return StatusTag.none }
        switch detail.favoriteStatus {
        case .finished:
            return StatusTag.finished
        case .abandoned:
            return StatusTag.abandoned
        case .favorited, .unknow:
            return StatusTag.favorited
        }
    }

    private func status(from tag: Int) -> FavoriteStatus? {
        switch tag {
        case StatusTag.favorited:
            return .favorited
        case StatusTag.finished:
            return .finished
        case StatusTag.abandoned:
            return .abandoned
        default:
            return nil
        }
    }

    private func currentStatus(of detail: BangumiDetail) -> FavoriteStatus? {
        guard detail.isFavorited else { return nil }
        switch detail.favoriteStatus {
        case .finished:
            return .finished
        case .abandoned:
            return .abandoned
        case .favorited, .unknow:
            return .favorited
        }
    }

    private func statusDescription(for detail: BangumiDetail) -> String {
        guard detail.isFavorited else {
            return NSLocalizedString("当前：未关注", comment: "")
        }
        let status: String
        switch detail.favoriteStatus {
        case .finished:
            status = NSLocalizedString("已看完", comment: "")
        case .abandoned:
            status = NSLocalizedString("已抛弃", comment: "")
        case .favorited, .unknow:
            status = NSLocalizedString("已关注", comment: "")
        }
        return String(format: NSLocalizedString("当前：%@", comment: ""), status)
    }
}
