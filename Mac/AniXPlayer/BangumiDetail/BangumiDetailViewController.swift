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
    private var localFilesByEpisode: [Int: [LocalLibraryFile]] = [:]
    private let localPlayback = BangumiDetailLocalPlayback()

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
        heroView.onTapResourceSearch = { [weak self] in
            self?.openResourceSearch()
        }
        heroView.onTapOnline = { [weak self] in
            self?.openOnlinePlayback()
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
        episodesCard.onPlayLocalEpisode = { [weak self] _, files, sourceView in
            self?.playLocalFiles(files, from: sourceView)
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

        localFilesByEpisode = localPlayback.filesByEpisode(animeId: detail.animeId)

        heroView.configure(with: detail)
        metadataCard.configure(with: detail)
        trackingCard.configure(with: detail)
        episodesCard.configure(with: detail, localFilesByEpisode: localFilesByEpisode)
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

    private func openResourceSearch() {
        guard let keyword = detail?.animeTitle else { return }
        guard BangumiDetailMainShellRouter.open(.resourceSearch, keyword: keyword) else {
            view.show(text: NSLocalizedString("无法打开主窗口，请从「搜索」或「首页」重新进入。", comment: ""))
            return
        }
    }

    private func openOnlinePlayback() {
        guard let keyword = detail?.animeTitle else { return }
        guard BangumiDetailMainShellRouter.open(.online, keyword: keyword) else {
            view.show(text: NSLocalizedString("无法打开主窗口，请从「搜索」或「首页」重新进入。", comment: ""))
            return
        }
    }

    private func playLocalFiles(_ files: [LocalLibraryFile], from sourceView: NSView) {
        localPlayback.play(files: files, from: sourceView, hostView: view)
    }

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
        vc.configure(
            episodes: detail.episodes,
            seasons: detail.seasons,
            localFilesByEpisode: localFilesByEpisode,
            localPlayback: localPlayback
        )
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

// MARK: - Local playback

/// 详情页的媒体库播放入口。
/// 只读查询匹配文件，播放前检查文件夹授权与磁盘文件，
/// 最终复用主窗口已有的播放器路径。
@MainActor
final class BangumiDetailLocalPlayback: NSObject {

    private let store: LocalLibraryStore?
    private var pendingFiles: [LocalLibraryFile] = []
    private weak var pendingHostView: NSView?

    init(store: LocalLibraryStore? = nil) {
        self.store = store ?? (try? LocalLibraryStore())
        super.init()
    }

    /// 返回 animeId 下按剧集分组的可播放文件；查询失败时返回空字典。
    func filesByEpisode(animeId: Int) -> [Int: [LocalLibraryFile]] {
        guard let store = store, animeId > 0 else { return [:] }
        guard let files = try? store.matchedFiles(animeId: animeId) else { return [:] }
        let grouped = Dictionary(grouping: files) { $0.episodeId ?? 0 }
        return grouped.filter { $0.key > 0 }
    }

    func play(files: [LocalLibraryFile], from sourceView: NSView, hostView: NSView) {
        let playable = files.filter { $0.id > 0 && !$0.isMissing }
        guard !playable.isEmpty else {
            hostView.show(text: NSLocalizedString("没有可播放的本地文件。", comment: ""))
            return
        }

        if playable.count == 1 {
            play(playable[0], hostView: hostView)
            return
        }

        pendingFiles = playable
        pendingHostView = hostView

        let menu = NSMenu()
        menu.autoenablesItems = false
        for (index, file) in playable.enumerated() {
            let item = NSMenuItem(
                title: "\(file.fileName) — \(file.path)",
                action: #selector(playMenuItem(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = index
            item.toolTip = file.path
            menu.addItem(item)
        }
        menu.popUp(
            positioning: nil,
            at: NSPoint(x: 0, y: sourceView.bounds.maxY + 4),
            in: sourceView
        )
    }

    @objc private func playMenuItem(_ sender: NSMenuItem) {
        guard pendingFiles.indices.contains(sender.tag) else { return }
        let file = pendingFiles[sender.tag]
        let hostView = pendingHostView
        pendingFiles = []
        pendingHostView = nil
        play(file, hostView: hostView)
    }

    private func play(_ file: LocalLibraryFile, hostView: NSView?) {
        guard let hostView = hostView ?? NSApp.keyWindow?.contentView else { return }
        guard let store = store else {
            hostView.show(text: NSLocalizedString("没有可播放的本地文件。", comment: ""))
            return
        }
        guard let folder = (try? store.folder(id: file.folderId)) ?? nil else {
            hostView.show(text: NSLocalizedString("找不到该文件所属的媒体库文件夹", comment: ""))
            return
        }
        guard LocalLibraryFolderAccess.shared.ensureAccess(folder: folder) else {
            hostView.show(text: NSLocalizedString(
                "媒体库文件夹的访问权限已失效，请在媒体库中重新授权。",
                comment: ""
            ))
            return
        }
        guard FileManager.default.fileExists(atPath: file.path) else {
            hostView.show(text: String(
                format: NSLocalizedString("文件不存在或已移动：%@", comment: ""),
                file.path
            ))
            return
        }
        guard let mainViewController = BangumiDetailMainShellRouter.activateMainWindow() else {
            hostView.show(text: NSLocalizedString(
                "无法打开主窗口，请从「搜索」或「首页」重新进入。",
                comment: ""
            ))
            return
        }

        let playerFile = LocalFile(with: file.fileURL)
        mainViewController.openLocalFiles([playerFile], startWith: playerFile)
    }
}
