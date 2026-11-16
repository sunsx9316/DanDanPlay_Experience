//
//  WelcomeScheduleViewController.swift
//  AniXPlayer
//
//  macOS：欢迎页新番时间表（季度 / 星期 / 搜索 / 关注）。
//

import Cocoa
import SnapKit

final class WelcomeScheduleViewController: ViewController, WelcomeShellLoginAware {

    weak var router: WelcomeShellRouting?

    private let service = HomePageService()
    private let favoriteService = FavoriteUserDataService()

    private var seasonOptions: [WelcomeSeasonOption] = [.currentSeason]
    private var allItems: [BangumiIntro] = []
    private var filteredItems: [BangumiIntro] = []
    private var selectedFilter: WelcomeScheduleFilter = .all
    private var loadTask: Task<Void, Never>?
    private var isLoggedIn = false
    private var initialSearchText: String?

    /// 周一至周日 + 已关注 + 全部；airDay 顺序为 1,2,3,4,5,6,0。
    private let dayAirDays = [1, 2, 3, 4, 5, 6, 0]

    // MARK: Views

    private lazy var headerView: WelcomeShellPageHeaderView = {
        let view = WelcomeShellPageHeaderView(
            title: NSLocalizedString("新番时间表", comment: ""),
            subtitle: NSLocalizedString("按季度和星期浏览正在连载的新番", comment: "")
        )
        let refreshButton = WelcomeShellClosureButton(
            image: welcomeShellSymbol("arrow.clockwise", pointSize: 12, weight: .semibold)
        )
        refreshButton.isBordered = false
        refreshButton.contentTintColor = .mainColor
        refreshButton.toolTip = NSLocalizedString("刷新", comment: "")
        refreshButton.onClick = { [weak self] in
            self?.refreshCurrentQuarter()
        }
        view.trailingStack.addArrangedSubview(refreshButton)
        return view
    }()

    private lazy var seasonPopup: NSPopUpButton = {
        let popup = NSPopUpButton()
        popup.controlSize = .regular
        popup.target = self
        popup.action = #selector(seasonChanged)
        popup.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.scheduleSeasonPopup)
        return popup
    }()

    private lazy var searchField: NSSearchField = {
        let field = NSSearchField()
        field.placeholderString = NSLocalizedString("搜索新番", comment: "")
        field.delegate = self
        field.target = self
        field.action = #selector(searchEntered)
        field.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.scheduleSearchField)
        return field
    }()

    private lazy var dayControl: NSSegmentedControl = {
        let control = NSSegmentedControl(
            labels: [
                NSLocalizedString("周一", comment: ""),
                NSLocalizedString("周二", comment: ""),
                NSLocalizedString("周三", comment: ""),
                NSLocalizedString("周四", comment: ""),
                NSLocalizedString("周五", comment: ""),
                NSLocalizedString("周六", comment: ""),
                NSLocalizedString("周日", comment: ""),
                NSLocalizedString("已关注", comment: ""),
                NSLocalizedString("全部", comment: ""),
            ],
            trackingMode: .selectOne,
            target: self,
            action: #selector(dayChanged)
        )
        control.segmentStyle = .texturedRounded
        control.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.scheduleDayFilter)
        return control
    }()

    private let summaryLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 11),
        color: .secondaryLabelColor
    )

    private let stateView = WelcomeShellStateView()

    private lazy var waterfallLayout: WaterfallLayout = {
        let layout = WaterfallLayout()
        layout.columnCount = 4
        layout.itemPadding = 12
        layout.sectionInset = NSEdgeInsets(top: 8, left: 22, bottom: 24, right: 22)
        layout.delegate = self
        return layout
    }()

    private lazy var collectionView: CollectionView = {
        let cv = CollectionView()
        cv.collectionViewLayout = waterfallLayout
        cv.registerItem(class: TimelineCollectionViewCell.self)
        cv.dataSource = self
        cv.delegate = self
        cv.backgroundColors = [.clear]
        cv.isSelectable = true
        cv.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.scheduleList)
        return cv
    }()

    private lazy var scrollView: ScrollView<CollectionView> = {
        let sv = ScrollView<CollectionView>()
        sv.containerView = collectionView
        sv.hasVerticalScroller = true
        sv.borderType = .noBorder
        sv.drawsBackground = false
        return sv
    }()

    // MARK: Init

    init(initialSearchText: String? = nil) {
        self.initialSearchText = initialSearchText
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Lifecycle

    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 620))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.scheduleRoot)
        title = NSLocalizedString("新番时间表", comment: "")

        setupLayout()
        stateView.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.scheduleStatus)
        selectToday()
        rebuildSeasonPopup()
        if let text = initialSearchText, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            searchField.stringValue = text
            dayControl.selectedSegment = 8
            selectedFilter = .all
        }
        loadInitial()
    }

    deinit {
        loadTask?.cancel()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        updateCollectionFrame()    }

    // MARK: Layout

    private func setupLayout() {
        let controls = NSStackView(views: [seasonPopup, searchField, NSView()])
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.spacing = 8

        seasonPopup.snp.makeConstraints { make in
            make.width.equalTo(180)
        }
        searchField.snp.makeConstraints { make in
            make.width.equalTo(210)
        }

        view.addSubview(headerView)
        view.addSubview(controls)
        view.addSubview(dayControl)
        view.addSubview(summaryLabel)
        view.addSubview(scrollView)
        view.addSubview(stateView)

        headerView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.trailing.equalToSuperview().inset(22)
        }
        controls.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom).offset(8)
            make.leading.trailing.equalTo(headerView)
        }
        dayControl.snp.makeConstraints { make in
            make.top.equalTo(controls.snp.bottom).offset(8)
            make.leading.equalTo(headerView)
            make.trailing.lessThanOrEqualTo(headerView)
        }
        summaryLabel.snp.makeConstraints { make in
            make.top.equalTo(dayControl.snp.bottom).offset(7)
            make.leading.trailing.equalTo(headerView)
        }
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(summaryLabel.snp.bottom).offset(4)
            make.leading.trailing.bottom.equalToSuperview()
        }
        stateView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(scrollView)
            make.leading.greaterThanOrEqualToSuperview().offset(30)
            make.trailing.lessThanOrEqualToSuperview().offset(-30)
        }
    }

    private func updateCollectionFrame() {
        let bounds = scrollView.contentView.bounds
        guard bounds.width > 0 else { return }

        let columns = max(2, Int(bounds.width / 175))
        if waterfallLayout.columnCount != columns {
            waterfallLayout.columnCount = columns
        }

        if collectionView.frame.width != bounds.width {
            collectionView.frame.size.width = bounds.width
            waterfallLayout.invalidateLayout()
        }
        let contentHeight = max(
            waterfallLayout.collectionViewContentSize.height,
            bounds.height
        )
        if collectionView.frame.height != contentHeight {
            collectionView.frame.size.height = contentHeight
        }
    }

    // MARK: Data

    private func loadInitial() {
        loadTask?.cancel()
        showLoading()

        loadTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard AccessTokenHolder.shared.current() != nil else {
                self.isLoggedIn = false
                self.applyLoggedOutState()
                return
            }
            self.isLoggedIn = true

            do {
                let homepage = try await self.service.loadHomepage()
                guard !Task.isCancelled else { return }
                self.seasonOptions = WelcomeShellDataMapper.seasonOptions(seasons: homepage.bangumiSeasons)
                self.rebuildSeasonPopup()
                self.allItems = WelcomeShellDataMapper.currentSeasonBangumi(from: homepage)
                if self.allItems.isEmpty {
                    self.allItems = try await self.service.loadShinBangumi()
                }
                guard !Task.isCancelled else { return }
                self.loadingFinished()
            } catch {
                guard !Task.isCancelled else { return }
                do {
                    self.allItems = try await self.service.loadShinBangumi()
                    guard !Task.isCancelled else { return }
                    self.loadingFinished()
                } catch {
                    guard !Task.isCancelled else { return }
                    self.loadingFailed(error.localizedDescription)
                }
            }
        }
    }

    private func refreshCurrentQuarter() {
        guard isLoggedIn else {
            loadInitial()
            return
        }
        guard let option = selectedSeasonOption() else {
            loadInitial()
            return
        }
        loadQuarter(option)
    }

    private func loadQuarter(_ option: WelcomeSeasonOption) {
        loadTask?.cancel()
        showLoading()

        loadTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                let items: [BangumiIntro]
                if option.isCurrentSeason {
                    items = try await self.service.loadShinBangumi()
                } else if let year = option.year, let month = option.month {
                    items = try await self.service.loadSeasonBangumi(year: year, month: month)
                } else {
                    items = []
                }
                guard !Task.isCancelled else { return }
                self.allItems = items
                self.loadingFinished()
            } catch {
                guard !Task.isCancelled else { return }
                self.loadingFailed(error.localizedDescription)
            }
        }
    }

    private func rebuildSeasonPopup() {
        let previousTitle = seasonPopup.titleOfSelectedItem
        seasonPopup.removeAllItems()
        for option in seasonOptions {
            seasonPopup.addItem(withTitle: option.title)
            seasonPopup.lastItem?.tag = seasonOptions.firstIndex(of: option) ?? 0
        }
        if let previousTitle = previousTitle,
           let index = seasonOptions.firstIndex(where: { $0.title == previousTitle }) {
            seasonPopup.selectItem(at: index)
        } else {
            seasonPopup.selectItem(at: 0)
        }
    }

    private func selectedSeasonOption() -> WelcomeSeasonOption? {
        let index = seasonPopup.indexOfSelectedItem
        guard index >= 0, index < seasonOptions.count else { return seasonOptions.first }
        return seasonOptions[index]
    }

    private func showLoading() {
        stateView.isHidden = false
        stateView.configure(title: NSLocalizedString("正在加载新番…", comment: ""))
        collectionView.isHidden = true
        summaryLabel.text = ""
    }

    private func loadingFinished() {
        stateView.isHidden = true
        collectionView.isHidden = false
        collectionView.reloadData()
        collectionView.layoutSubtreeIfNeeded()
        applyFilter()
        viewDidLayout()
    }

    private func loadingFailed(_ message: String) {
        allItems = []
        filteredItems = []
        collectionView.reloadData()
        collectionView.isHidden = true
        stateView.isHidden = false
        stateView.configure(
            title: NSLocalizedString("新番时间表加载失败", comment: ""),
            detail: message,
            actionTitle: NSLocalizedString("重试", comment: ""),
            onAction: { [weak self] in
                self?.refreshCurrentQuarter()
            }
        )
        summaryLabel.text = ""
    }

    private func applyLoggedOutState() {
        allItems = []
        filteredItems = []
        collectionView.reloadData()
        collectionView.isHidden = true
        stateView.isHidden = false
        stateView.configure(
            title: NSLocalizedString("登录后查看新番时间表", comment: ""),
            detail: NSLocalizedString("新番数据需要登录弹弹play账号", comment: ""),
            actionTitle: NSLocalizedString("登录", comment: ""),
            onAction: { [weak self] in
                guard let self = self else { return }
                Task { @MainActor in
                    _ = await LoginGate.shared.ensureLoggedIn(presenting: self.view.window)
                }
            }
        )
        summaryLabel.text = ""
    }

    private func applyFilter() {
        filteredItems = WelcomeShellDataMapper.filterBangumi(
            allItems,
            filter: selectedFilter,
            searchText: searchField.stringValue
        )
        collectionView.reloadData()
        collectionView.layoutSubtreeIfNeeded()

        let isEmpty = filteredItems.isEmpty
        collectionView.isHidden = isEmpty
        stateView.isHidden = !isEmpty
        if isEmpty {
            let keyword = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let title: String
            if !keyword.isEmpty {
                title = NSLocalizedString("没有匹配的新番", comment: "")
            } else {
                switch selectedFilter {
                case .favorited:
                    title = NSLocalizedString("还没有关注新番", comment: "")
                case .weekday:
                    title = NSLocalizedString("这一天没有新番", comment: "")
                case .all:
                    title = NSLocalizedString("暂无新番数据", comment: "")
                }
            }
            stateView.configure(
                title: title,
                actionTitle: keyword.isEmpty ? nil : NSLocalizedString("清除搜索", comment: ""),
                onAction: { [weak self] in
                    self?.searchField.stringValue = ""
                    self?.applyFilter()
                }
            )
        }

        let seasonTitle = selectedSeasonOption()?.title ?? ""
        if !seasonTitle.isEmpty {
            summaryLabel.text = String(
                format: NSLocalizedString("%@ · 共 %d 部", comment: ""),
                seasonTitle,
                filteredItems.count
            )
        } else {
            summaryLabel.text = String(format: NSLocalizedString("共 %d 部", comment: ""), filteredItems.count)
        }
        viewDidLayout()
    }

    private func selectToday() {
        let today = WelcomeShellDataMapper.currentAirDay()
        if let index = dayAirDays.firstIndex(of: today) {
            dayControl.selectedSegment = index
            selectedFilter = .weekday(today)
        } else {
            dayControl.selectedSegment = 8
            selectedFilter = .all
        }
    }

    // MARK: Actions

    @objc private func seasonChanged() {
        guard isLoggedIn else {
            applyLoggedOutState()
            return
        }
        guard let option = selectedSeasonOption() else { return }
        loadQuarter(option)
    }

    @objc private func dayChanged() {
        let index = dayControl.selectedSegment
        if index >= 0 && index < dayAirDays.count {
            selectedFilter = .weekday(dayAirDays[index])
        } else if index == dayAirDays.count {
            selectedFilter = .favorited
        } else {
            selectedFilter = .all
        }
        applyFilter()
    }

    @objc private func searchEntered() {
        let keyword = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            applyFilter()
            return
        }
        dayControl.selectedSegment = 8
        selectedFilter = .all
        applyFilter()
    }

    private func toggleFavorite(animeId: Int, isFavorited: Bool) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard await LoginGate.shared.ensureAccessToken(presenting: self.view.window) else {
                return
            }
            do {
                if isFavorited {
                    try await self.favoriteService.updateFavorite(
                        animeId: animeId,
                        favoriteStatus: .favorited
                    )
                } else {
                    try await self.favoriteService.removeFavorite(animeId: animeId)
                }
                if let index = self.allItems.firstIndex(where: { $0.animeId == animeId }) {
                    self.allItems[index].isFavorited = isFavorited
                }
                self.applyFilter()
            } catch {
                self.view.show(error: error)
                self.collectionView.reloadData()
            }
        }
    }

    // MARK: External

    func applyExternalSearch(_ text: String) {
        guard isViewLoaded else { return }
        searchField.stringValue = text
        dayControl.selectedSegment = 8
        selectedFilter = .all
        applyFilter()
    }

    func welcomeShellLoginStateDidChange() {
        loadInitial()
    }
}

// MARK: - Collection view

extension WelcomeScheduleViewController: NSCollectionViewDataSource {
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        filteredItems.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let cell = collectionView.dequeueItem(class: TimelineCollectionViewCell.self, for: indexPath)
        guard indexPath.item < filteredItems.count else { return cell }
        let item = filteredItems[indexPath.item]
        cell.configure(with: item)
        cell.view.setAccessibilityIdentifier("\(AccessibilityID.WelcomeShell.scheduleItemPrefix)\(item.animeId)")
        cell.favoritedButton.setAccessibilityIdentifier("\(AccessibilityID.WelcomeShell.scheduleFavoritePrefix)\(item.animeId)")
        cell.onFavoriteToggle = { [weak self] animeId, isFavorited in
            self?.toggleFavorite(animeId: animeId, isFavorited: isFavorited)
        }
        return cell
    }
}

extension WelcomeScheduleViewController: NSCollectionViewDelegate {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first, indexPath.item < filteredItems.count else { return }
        collectionView.deselectItems(at: indexPaths)
        router?.openDetail(animeId: filteredItems[indexPath.item].animeId)
    }
}

extension WelcomeScheduleViewController: WaterfallLayoutDelegate {
    func waterfallLayout(_ layout: WaterfallLayout, heightForItemAt indexPath: IndexPath, itemWidth: CGFloat) -> CGFloat {
        guard indexPath.item < filteredItems.count else { return itemWidth * 1.4 + 82 }
        let item = filteredItems[indexPath.item]
        let titleHeight = item.animeTitle.boundingRect(
            with: NSSize(width: itemWidth - 4, height: 40),
            options: .usesLineFragmentOrigin,
            attributes: [.font: NSFont.ddp_normal()]
        ).height.rounded(.up)
        return itemWidth * 1.4 + titleHeight + 54
    }
}

// MARK: - Search

extension WelcomeScheduleViewController: NSSearchFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSSearchField, field === searchField else { return }
        applyFilter()
    }
}
