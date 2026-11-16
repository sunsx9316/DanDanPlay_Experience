//
//  BangumiDetailViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/29.
//

import Cocoa
import SnapKit

final class BangumiDetailViewController: WelcomeShellScrollPageViewController {

    private let animateId: Int

    private var detail: BangumiDetail?
    private var hasLoadedComments = false
    private var isLoadingComments = false
    private var commentsRequestID = 0

    private let stateView = BangumiDetailPageStateView()
    private let heroView = BangumiDetailHeroView()
    private let metadataCard = BangumiDetailMetadataCardView()
    private let trackingCard = BangumiDetailTrackingCardView()
    private let episodesCard = BangumiDetailEpisodesCardView()
    private let communityCard = BangumiDetailCommunityCardView()

    init(animateId: Int) {
        self.animateId = animateId
        super.init()
        title = NSLocalizedString("作品详情", comment: "")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.setAccessibilityIdentifier(AccessibilityID.BangumiDetail.root)
        contentStack.spacing = 12

        buildLayout()
        showLoadingState()
        startRefresh()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.title = detail?.animeTitle ?? title ?? NSLocalizedString("作品详情", comment: "")
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        updateWindowMinimumSize()
    }

    // MARK: - Layout

    private func buildLayout() {
        addFullWidth(stateView, spacingAfter: 4)
        addFullWidth(heroView)
        addFullWidth(metadataCard)
        addFullWidth(trackingCard)
        addFullWidth(episodesCard)
        addFullWidth(communityCard)

        [metadataCard, trackingCard, episodesCard, communityCard].forEach { $0.isHidden = true }

        stateView.isHidden = true

        heroView.onFavoriteToggle = { [weak self] animeId, isLike in
            self?.toggleFavorite(animeId: animeId, isLike: isLike)
        }
        heroView.onTapMetadata = { [weak self] in
            self?.pushMetadata()
        }
        heroView.onTapEpisodes = { [weak self] in
            self?.scrollToEpisodes()
        }
        heroView.onLayoutChange = { [weak self] in
            self?.layoutContent()
        }

        metadataCard.onViewAll = { [weak self] in
            self?.pushMetadata()
        }

        trackingCard.onSave = { [weak self] edit in
            self?.applyFavoriteEdit(edit)
        }

        episodesCard.onViewAll = { [weak self] in
            self?.pushEpisodeList()
        }
        episodesCard.onActivateEpisode = { [weak self] in
            self?.pushEpisodeList()
        }
        episodesCard.onLayoutChange = { [weak self] in
            self?.layoutContent()
        }

        communityCard.onViewAllComments = { [weak self] in
            self?.pushCommentList()
        }
        communityCard.onRetryComments = { [weak self] in
            self?.loginThenLoadComments()
        }
        communityCard.onLogin = { [weak self] in
            self?.loginThenLoadComments()
        }
        communityCard.onSelectAnime = { [weak self] animeId in
            self?.pushDetail(animateId: animeId)
        }
        communityCard.onFavoriteToggle = { [weak self] animeId, isLike in
            self?.toggleFavorite(animeId: animeId, isLike: isLike)
        }
        communityCard.onLayoutChange = { [weak self] in
            self?.layoutContent()
        }
    }

    // MARK: - Loading

    private func startRefresh() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard await LoginGate.shared.ensureAccessToken(presenting: self.view.window) else {
                self.showLoginState()
                return
            }
            self.loadDetail()
        }
    }

    private func loadDetail(showLoading: Bool = true) {
        if showLoading, detail == nil {
            showLoadingState()
        }

        BangumiNetworkHandle.detail(animateId: animateId) { [weak self] response, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let error = error {
                    if self.detail == nil {
                        self.showErrorState(error.localizedDescription)
                    } else {
                        self.view.show(error: error)
                    }
                    return
                }
                guard let detail = response?.bangumi else {
                    self.showErrorState(NSLocalizedString("作品详情为空", comment: ""))
                    return
                }
                self.apply(detail: detail)
            }
        }
    }

    private func apply(detail: BangumiDetail) {
        self.detail = detail
        title = detail.animeTitle
        view.window?.title = detail.animeTitle

        heroView.configure(with: detail)
        metadataCard.configure(with: detail)
        trackingCard.configure(with: detail)
        episodesCard.configure(with: detail)
        communityCard.configure(with: detail)

        stateView.hide()
        stateView.isHidden = true
        [heroView, metadataCard, trackingCard, episodesCard, communityCard].forEach { $0.isHidden = false }
        layoutContent()

        if !hasLoadedComments {
            loadComments()
        }
    }

    private func loadComments() {
        guard detail != nil, !isLoadingComments else { return }
        guard AccessTokenHolder.shared.current() != nil else {
            communityCard.updateComments(.login)
            return
        }

        isLoadingComments = true
        commentsRequestID += 1
        let requestID = commentsRequestID
        communityCard.updateComments(.loading)

        let bangumiId = commentBangumiId
        BangumiNetworkHandle.comments(bangumiId: bangumiId, page: 0) { [weak self] response, error in
            guard let self = self, self.commentsRequestID == requestID else { return }
            DispatchQueue.main.async {
                self.isLoadingComments = false
                if let error = error {
                    self.communityCard.updateComments(.failed(error.localizedDescription))
                } else {
                    self.hasLoadedComments = true
                    self.communityCard.updateComments(.loaded(response?.comments ?? []))
                }
            }
        }
    }

    private var commentBangumiId: String {
        guard let detail = detail else { return "\(animateId)" }
        let bangumiId = detail.bangumiId.trimmingCharacters(in: .whitespacesAndNewlines)
        return (bangumiId.isEmpty || bangumiId == "0") ? "\(detail.animeId)" : bangumiId
    }

    // MARK: - States

    private func showLoadingState() {
        stateView.isHidden = false
        stateView.showLoading()
        setContentVisible(false)
        layoutContent()
    }

    private func showLoginState() {
        stateView.isHidden = false
        stateView.showLogin { [weak self] in
            self?.loginThenLoadDetail()
        }
        setContentVisible(false)
        layoutContent()
    }

    private func showErrorState(_ message: String) {
        stateView.isHidden = false
        stateView.showError(message) { [weak self] in
            self?.startRefresh()
        }
        setContentVisible(false)
        layoutContent()
    }

    private func setContentVisible(_ visible: Bool) {
        [heroView, metadataCard, trackingCard, episodesCard, communityCard].forEach {
            $0.isHidden = !visible
        }
    }

    private func loginThenLoadDetail() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard await LoginGate.shared.ensureAccessToken(presenting: self.view.window) else {
                return
            }
            self.loadDetail()
        }
    }

    private func loginThenLoadComments() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard await LoginGate.shared.ensureAccessToken(presenting: self.view.window) else {
                return
            }
            self.loadComments()
        }
    }

    private func updateWindowMinimumSize() {
        guard let window = view.window, window.styleMask.contains(.resizable) else { return }
        let minimum = NSSize(width: 860, height: 620)
        let current = window.contentMinSize
        let target = NSSize(
            width: max(current.width, minimum.width),
            height: max(current.height, minimum.height)
        )
        if target != current {
            window.contentMinSize = target
        }
        let currentContentSize = window.contentView?.bounds.size ?? .zero
        if currentContentSize.width < target.width || currentContentSize.height < target.height {
            window.setContentSize(NSSize(
                width: max(currentContentSize.width, target.width),
                height: max(currentContentSize.height, target.height)
            ))
        }
    }

    // MARK: - Favorites

    private func toggleFavorite(animeId: Int, isLike: Bool) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard await LoginGate.shared.ensureAccessToken(presenting: self.view.window) else {
                return
            }
            FavoriteNetworkHandle.changeFavorite(animateId: animeId, isLike: isLike) { [weak self] error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if let error = error {
                        self.view.show(error: error)
                    }
                    self.loadDetail(showLoading: false)
                }
            }
        }
    }

    private func applyFavoriteEdit(_ edit: BangumiDetailTrackingCardView.Edit) {
        guard let detail = detail else { return }
        let animeId = detail.animeId

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard await LoginGate.shared.ensureAccessToken(presenting: self.view.window) else {
                return
            }

            do {
                if edit.shouldRemove {
                    try await FavoriteNetworkHandle.removeFavorite(animeId: animeId)
                } else {
                    try await FavoriteNetworkHandle.updateFavorite(
                        animeId: animeId,
                        favoriteStatus: edit.status,
                        rating: edit.rating ?? 0,
                        comment: edit.comment
                    )
                }
                self.view.show(text: NSLocalizedString("已更新", comment: ""))
                self.loadDetail(showLoading: false)
            } catch {
                self.view.show(error: error)
                // 失败时重新拉取服务端数据，避免本地显示“已成功”的假象。
                self.loadDetail(showLoading: false)
            }
        }
    }

    // MARK: - Navigation

    private func pushDetail(animateId: Int) {
        let vc = BangumiDetailViewController(animateId: animateId)
        navigator?.pushViewController(vc)
    }

    private func pushMetadata() {
        guard let detail = detail else { return }
        let vc = BangumiDetailMetadataViewController()
        vc.configure(metaData: detail.metadata, titles: detail.titles, onlineDatabases: detail.onlineDatabases)
        navigator?.pushViewController(vc)
    }

    private func pushEpisodeList() {
        guard let detail = detail else { return }
        let vc = BangumiDetailEpisodeViewController()
        vc.configure(episodes: detail.episodes, seasons: detail.seasons)
        navigator?.pushViewController(vc)
    }

    private func pushCommentList() {
        let vc = BangumiCommentListViewController(bangumiId: commentBangumiId)
        navigator?.pushViewController(vc)
    }

    private func scrollToEpisodes() {
        contentView.layoutSubtreeIfNeeded()
        let rect = episodesCard.convert(episodesCard.bounds, to: contentView)
        let targetY = max(0, rect.minY - 12)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: targetY))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        scrollView.flashScrollers()
    }
}
