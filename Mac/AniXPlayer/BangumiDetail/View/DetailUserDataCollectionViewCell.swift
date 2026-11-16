//
//  DetailUserDataCollectionViewCell.swift
//  AniXPlayer
//
//  macOS：番剧详情中的追番状态 / 评分 / 短评编辑。
//

import Cocoa
import SnapKit

final class DetailUserDataCollectionViewCell: CollectionViewItem, NSTextViewDelegate {

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

    private lazy var card: BaseView = {
        let view = BaseView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.cellHighlightColor.cgColor
        view.layer?.cornerRadius = 8
        return view
    }()

    private lazy var statusTitleLabel: Label = {
        let label = Label(labelWithString: NSLocalizedString("追番状态", comment: ""))
        label.font = .ddp_small()
        label.textColor = .subtitleTextColor
        return label
    }()

    private lazy var statusPopup: NSPopUpButton = {
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
        popup.target = self
        popup.action = #selector(statusChanged)
        popup.setAccessibilityIdentifier(AccessibilityID.Favorite.detailStatusPopup)
        return popup
    }()

    private lazy var currentStatusLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .ddp_small()
        label.textColor = .subtitleTextColor
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setAccessibilityIdentifier(AccessibilityID.Favorite.detailStatusLabel)
        return label
    }()

    private lazy var ratingTitleLabel: Label = {
        let label = Label(labelWithString: NSLocalizedString("我的评分", comment: ""))
        label.font = .ddp_small()
        label.textColor = .subtitleTextColor
        return label
    }()

    private lazy var ratingPopup: NSPopUpButton = {
        let popup = NSPopUpButton()
        popup.addItem(withTitle: NSLocalizedString("未评分", comment: ""))
        popup.item(at: 0)?.tag = 0
        for score in 1...10 {
            popup.addItem(withTitle: String(format: NSLocalizedString("%d 分", comment: ""), score))
            popup.item(at: score)?.tag = score
        }
        popup.target = self
        popup.action = #selector(ratingChanged)
        popup.setAccessibilityIdentifier(AccessibilityID.Favorite.detailRatingPopup)
        return popup
    }()

    private lazy var commentTitleLabel: Label = {
        let label = Label(labelWithString: NSLocalizedString("短评", comment: ""))
        label.font = .ddp_small()
        label.textColor = .subtitleTextColor
        return label
    }()

    private lazy var commentTextView: NSTextView = {
        let textView = NSTextView()
        textView.font = .ddp_small()
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
        textView.delegate = self
        textView.setAccessibilityIdentifier(AccessibilityID.Favorite.detailCommentView)
        return textView
    }()

    private lazy var commentScrollView: ScrollView<NSTextView> = {
        let scrollView = ScrollView<NSTextView>(containerView: commentTextView)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder
        scrollView.drawsBackground = false
        return scrollView
    }()

    private lazy var commentCountLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .ddp_small()
        label.textColor = .subtitleTextColor
        label.alignment = .right
        label.setAccessibilityIdentifier(AccessibilityID.Favorite.detailCommentCountLabel)
        return label
    }()

    private lazy var saveButton: Button = {
        let button = Button(title: NSLocalizedString("保存", comment: ""), target: self, action: #selector(saveClicked))
        button.setAccessibilityIdentifier(AccessibilityID.Favorite.detailSaveButton)
        return button
    }()

    private lazy var clearCommentButton: Button = {
        let button = Button(title: NSLocalizedString("清空短评", comment: ""), target: self, action: #selector(clearCommentClicked))
        button.setAccessibilityIdentifier(AccessibilityID.Favorite.detailClearCommentButton)
        return button
    }()

    override func loadView() {
        view = NSView()
        view.setAccessibilityIdentifier(AccessibilityID.Favorite.detailRoot)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(card)
        card.addSubview(statusTitleLabel)
        card.addSubview(statusPopup)
        card.addSubview(currentStatusLabel)
        card.addSubview(ratingTitleLabel)
        card.addSubview(ratingPopup)
        card.addSubview(commentTitleLabel)
        card.addSubview(commentScrollView)
        card.addSubview(commentCountLabel)
        card.addSubview(clearCommentButton)
        card.addSubview(saveButton)

        card.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().offset(4)
            make.bottom.equalToSuperview().offset(-4)
        }

        statusTitleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.top.equalToSuperview().offset(12)
        }

        statusPopup.snp.makeConstraints { make in
            make.leading.equalTo(statusTitleLabel.snp.trailing).offset(8)
            make.centerY.equalTo(statusTitleLabel)
            make.width.equalTo(100)
        }

        currentStatusLabel.snp.makeConstraints { make in
            make.leading.equalTo(statusPopup.snp.trailing).offset(8)
            make.centerY.equalTo(statusTitleLabel)
            make.trailing.lessThanOrEqualToSuperview().offset(-12)
        }

        ratingTitleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.top.equalTo(statusTitleLabel.snp.bottom).offset(10)
        }

        ratingPopup.snp.makeConstraints { make in
            make.leading.equalTo(ratingTitleLabel.snp.trailing).offset(8)
            make.centerY.equalTo(ratingTitleLabel)
            make.width.equalTo(90)
        }

        saveButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-12)
            make.centerY.equalTo(ratingTitleLabel)
        }

        clearCommentButton.snp.makeConstraints { make in
            make.trailing.equalTo(saveButton.snp.leading).offset(-8)
            make.centerY.equalTo(ratingTitleLabel)
        }

        commentTitleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.top.equalTo(ratingTitleLabel.snp.bottom).offset(10)
            make.width.equalTo(56)
        }

        commentScrollView.snp.makeConstraints { make in
            make.leading.equalTo(commentTitleLabel.snp.trailing).offset(4)
            make.top.equalTo(commentTitleLabel)
            make.trailing.equalTo(commentCountLabel.snp.leading).offset(-8)
            make.bottom.equalToSuperview().offset(-12)
        }

        commentCountLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-12)
            make.centerY.equalTo(commentScrollView)
            make.width.equalTo(52)
        }

        clearCommentButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        saveButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        ratingTitleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        ratingPopup.setContentCompressionResistancePriority(.required, for: .horizontal)
        commentCountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    override func viewDidLayout() {
        super.viewDidLayout()
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

    func configure(with item: BangumiDetail) {
        detail = item
        pendingStatus = nil
        pendingRemove = false
        let rating = Int(item.userRating.rounded())
        selectedRating = rating
        serverComment = item.comment

        currentStatusLabel.text = statusDescription(for: item)
        statusPopup.selectItem(withTag: statusTag(for: item))

        ratingPopup.selectItem(withTag: rating)
        // 服务端不支持通过 rating=0 清空评分，已评分的作品不再提供“未评分”选项。
        ratingPopup.item(at: 0)?.isEnabled = rating == 0

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
            view.show(text: NSLocalizedString("没有需要保存的修改", comment: ""))
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
        let canEditDetails = detail?.isFavorited == true && !pendingRemove
        ratingPopup.isEnabled = canEditDetails
        commentTextView.isEditable = canEditDetails
        clearCommentButton.isEnabled = canEditDetails
            && !serverComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func updateCommentCount() {
        let count = commentTextView.string.count
        commentCountLabel.text = "\(count)/\(FavoriteUserDataService.maxCommentLength)"
        commentCountLabel.textColor = count >= FavoriteUserDataService.maxCommentLength
            ? .systemRed
            : .subtitleTextColor
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
