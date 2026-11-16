//
//  BangumiDetailCommunityCardView.swift
//  AniXPlayer
//
//  macOS：详情页社区卡片（短评 / 关联作品 / 相似作品）。
//

import Cocoa
import SnapKit

final class BangumiDetailCommunityCardView: BangumiDetailCardView {

    enum CommentsState {
        case loading
        case loaded([BangumiComment])
        case failed(String)
        case login
    }

    var onViewAllComments: (() -> Void)?
    var onRetryComments: (() -> Void)?
    var onLogin: (() -> Void)?
    var onSelectAnime: ((Int) -> Void)?
    var onFavoriteToggle: ((Int, Bool) -> Void)?
    var onLayoutChange: (() -> Void)?

    private let segmentedControl = NSSegmentedControl(
        labels: [
            NSLocalizedString("短评", comment: ""),
            NSLocalizedString("关联作品", comment: ""),
            NSLocalizedString("相似作品", comment: ""),
        ],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )

    private let commentsContainer: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 10
        stack.detachesHiddenViews = true
        return stack
    }()
    private let commentsRowsStack: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 12
        stack.detachesHiddenViews = true
        return stack
    }()
    private let commentsStateView = WelcomeShellStateView()
    private let commentsViewAllButton = WelcomeShellClosureButton()

    private let relatedContainer = NSStackView()
    private let relatedGrid = WelcomeShellPosterGridView()
    private let relatedStateView = WelcomeShellStateView()
    private let similarContainer = NSStackView()
    private let similarGrid = WelcomeShellPosterGridView()
    private let similarStateView = WelcomeShellStateView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configure(with item: BangumiDetail) {
        configureGrid(
            relatedGrid,
            stateView: relatedStateView,
            items: item.relateds,
            emptyTitle: NSLocalizedString("暂无关联作品", comment: ""),
            itemIdentifierPrefix: AccessibilityID.BangumiDetail.relatedItemPrefix,
            favoriteIdentifierPrefix: AccessibilityID.BangumiDetail.relatedFavoritePrefix
        )
        configureGrid(
            similarGrid,
            stateView: similarStateView,
            items: item.similars,
            emptyTitle: NSLocalizedString("暂无相似作品", comment: ""),
            itemIdentifierPrefix: AccessibilityID.BangumiDetail.similarItemPrefix,
            favoriteIdentifierPrefix: AccessibilityID.BangumiDetail.similarFavoritePrefix
        )
    }

    func updateComments(_ state: CommentsState) {
        commentsRowsStack.arrangedSubviews.forEach {
            commentsRowsStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        switch state {
        case .loading:
            commentsRowsStack.isHidden = true
            commentsStateView.isHidden = false
            commentsStateView.configure(title: NSLocalizedString("正在加载短评…", comment: ""))
        case .login:
            commentsRowsStack.isHidden = true
            commentsStateView.isHidden = false
            commentsStateView.configure(
                title: NSLocalizedString("登录后查看短评", comment: ""),
                actionTitle: NSLocalizedString("登录", comment: ""),
                onAction: { [weak self] in
                    self?.onLogin?()
                }
            )
            commentsStateView.setActionAccessibilityIdentifier(AccessibilityID.BangumiDetail.stateAction)
        case .failed(let message):
            commentsRowsStack.isHidden = true
            commentsStateView.isHidden = false
            commentsStateView.configure(
                title: NSLocalizedString("短评加载失败", comment: ""),
                detail: message,
                actionTitle: NSLocalizedString("重试", comment: ""),
                onAction: { [weak self] in
                    self?.onRetryComments?()
                }
            )
            commentsStateView.setActionAccessibilityIdentifier(AccessibilityID.BangumiDetail.stateAction)
        case .loaded(let comments):
            if comments.isEmpty {
                commentsRowsStack.isHidden = true
                commentsStateView.isHidden = false
                commentsStateView.configure(title: NSLocalizedString("还没有短评", comment: ""))
            } else {
                commentsRowsStack.isHidden = false
                commentsStateView.isHidden = true
                commentsStateView.reset()
                let latest = comments.sorted {
                    ($0.updatedTime ?? .distantPast) > ($1.updatedTime ?? .distantPast)
                }
                for (index, comment) in latest.prefix(3).enumerated() {
                    let row = BangumiDetailCommentPreviewView()
                    row.update(comment: comment)
                    let identifier = comment.id > 0 ? "\(comment.id)" : "\(index)"
                    row.setAccessibilityIdentifier(
                        "\(AccessibilityID.BangumiDetail.commentItemPrefix)\(identifier)"
                    )
                    commentsRowsStack.addArrangedSubview(row)
                }
            }
        }
        onLayoutChange?()
    }

    // MARK: - Setup

    private func setup() {
        setAccessibilityIdentifier(AccessibilityID.BangumiDetail.community)
        addStaticHeader(
            title: NSLocalizedString("社区", comment: ""),
            symbolName: "person.2"
        )

        segmentedControl.segmentStyle = .rounded
        segmentedControl.selectedSegment = 0
        segmentedControl.segmentDistribution = .fillEqually
        segmentedControl.addTarget(self, action: #selector(segmentChanged))
        segmentedControl.setAccessibilityIdentifier(AccessibilityID.BangumiDetail.communitySegment)
        contentStack.addArrangedSubview(segmentedControl)

        buildCommentsContainer()
        buildPosterContainer(relatedContainer, grid: relatedGrid, stateView: relatedStateView)
        buildPosterContainer(similarContainer, grid: similarGrid, stateView: similarStateView)

        contentStack.addArrangedSubview(commentsContainer)
        contentStack.addArrangedSubview(relatedContainer)
        contentStack.addArrangedSubview(similarContainer)
        relatedContainer.isHidden = true
        similarContainer.isHidden = true

        commentsContainer.setAccessibilityIdentifier(AccessibilityID.BangumiDetail.comments)
        relatedGrid.setAccessibilityIdentifier(AccessibilityID.BangumiDetail.related)
        similarGrid.setAccessibilityIdentifier(AccessibilityID.BangumiDetail.similar)
    }

    private func buildCommentsContainer() {
        commentsViewAllButton.title = NSLocalizedString("查看全部", comment: "")
        commentsViewAllButton.isBordered = false
        commentsViewAllButton.controlSize = .small
        commentsViewAllButton.contentTintColor = .mainColor
        commentsViewAllButton.font = .systemFont(ofSize: 12, weight: .medium)
        commentsViewAllButton.setAccessibilityIdentifier(AccessibilityID.BangumiDetail.commentsViewAll)
        commentsViewAllButton.onClick = { [weak self] in
            self?.onViewAllComments?()
        }

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let title = welcomeShellLabel(
            NSLocalizedString("最新短评", comment: ""),
            font: .systemFont(ofSize: 13, weight: .semibold),
            color: .labelColor
        )
        let headerRow = NSStackView(views: [title, spacer, commentsViewAllButton])
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 8
        headerRow.setAccessibilityIdentifier(AccessibilityID.BangumiDetail.commentsHeader)

        commentsContainer.addArrangedSubview(headerRow)
        commentsContainer.addArrangedSubview(commentsRowsStack)
        commentsContainer.addArrangedSubview(commentsStateView)
        commentsStateView.isHidden = true
    }

    private func buildPosterContainer(
        _ container: NSStackView,
        grid: WelcomeShellPosterGridView,
        stateView: WelcomeShellStateView
    ) {
        container.orientation = .vertical
        container.alignment = .width
        container.spacing = 8
        container.detachesHiddenViews = true

        grid.onSelect = { [weak self] item in
            self?.onSelectAnime?(item.animeId)
        }
        grid.onFavoriteToggle = { [weak self] item, isLike in
            self?.onFavoriteToggle?(item.animeId, isLike)
        }
        grid.onHeightChange = { [weak self] in
            self?.onLayoutChange?()
        }
        stateView.isHidden = true

        container.addArrangedSubview(grid)
        container.addArrangedSubview(stateView)
        grid.snp.makeConstraints { make in
            make.width.equalTo(container)
        }
    }

    private func configureGrid(
        _ grid: WelcomeShellPosterGridView,
        stateView: WelcomeShellStateView,
        items: [BangumiIntro],
        emptyTitle: String,
        itemIdentifierPrefix: String,
        favoriteIdentifierPrefix: String
    ) {
        grid.itemIdentifierPrefix = itemIdentifierPrefix
        grid.favoriteIdentifierPrefix = favoriteIdentifierPrefix
        // 490pt 首页窗口下保持 2 列；900/1000pt 窗口为 4-6 列。
        grid.minimumTileWidth = 160
        grid.reload(items: items)
        grid.isHidden = items.isEmpty
        stateView.isHidden = !items.isEmpty
        if items.isEmpty {
            stateView.configure(title: emptyTitle)
        } else {
            stateView.reset()
        }
    }

    // MARK: - Actions

    @objc private func segmentChanged() {
        let selected = segmentedControl.selectedSegment
        commentsContainer.isHidden = selected != 0
        relatedContainer.isHidden = selected != 1
        similarContainer.isHidden = selected != 2
        onLayoutChange?()
    }
}
