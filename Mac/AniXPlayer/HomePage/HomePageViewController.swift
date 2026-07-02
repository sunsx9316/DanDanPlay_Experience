//
//  HomePageViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/29.
//

import Cocoa
import SnapKit
import Kingfisher

class HomePageViewController: ViewController {

    private var dataSource: Homepage? {
        didSet {
            updateBanner()
            reloadFunctionItems()
            reloadQueueData()
        }
    }

    // MARK: - Views

    private lazy var scrollView: ScrollView<NSView> = {
        let sv = ScrollView<NSView>()
        sv.containerView = contentView
        sv.hasVerticalScroller = true
        sv.borderType = .noBorder
        sv.drawsBackground = false
        return sv
    }()

    private lazy var contentView: NSView = {
        let v = NSView()
        v.frame = NSRect(x: 0, y: 0, width: 600, height: 480)
        return v
    }()

    // Banner

    private lazy var bannerCarrier: BannerCarouselView = {
        let v = BannerCarouselView()
        v.onBannerClick = { item in
            guard let url = URL(string: item.url) else { return }
            NSWorkspace.shared.open(url)
        }
        return v
    }()

    private lazy var pageControl: PageIndicator = {
        return PageIndicator()
    }()

    // Function area

    private lazy var functionStackView: NSStackView = {
        let sv = NSStackView()
        sv.orientation = .horizontal
        sv.distribution = .fillEqually
        sv.spacing = 0
        return sv
    }()

    // Queue

    private lazy var queueSectionHeader: Label = {
        let tf = Label(labelWithString: NSLocalizedString("追番队列", comment: ""))
        tf.font = .ddp_large(weight: .bold)
        tf.textColor = .textColor
        return tf
    }()

    private lazy var queueLayout: WaterfallLayout = {
        let layout = WaterfallLayout()
        layout.columnCount = 2
        layout.delegate = self
        return layout
    }()

    private lazy var queueCollectionView: CollectionView = {
        let cv = CollectionView()
        cv.collectionViewLayout = queueLayout
        cv.registerItem(class: QueueItem.self)
        cv.dataSource = self
        cv.delegate = self
        cv.backgroundColors = [.clear]
        cv.isSelectable = true
        return cv
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("主页", comment: "")

        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentView.addSubview(bannerCarrier)
        contentView.addSubview(pageControl)
        contentView.addSubview(functionStackView)
        contentView.addSubview(queueSectionHeader)
        contentView.addSubview(queueCollectionView)

        layoutSubviews()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(loginStateChanged),
            name: .AnixUserLoginStateDidChange,
            object: nil
        )

        startRefresh()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        let cvBounds = scrollView.contentView.bounds
        var newFrame = contentView.frame
        let widthChanged = newFrame.width != cvBounds.width
        if widthChanged {
            newFrame.size.width = cvBounds.width
            contentView.frame = newFrame
            queueCollectionView.layoutSubtreeIfNeeded()
        }
        let contentHeight = calculateContentHeight()
        newFrame.size.height = max(contentHeight, cvBounds.height)
        if !contentView.frame.equalTo(newFrame) {
            contentView.frame = newFrame
        }
    }

    private func calculateContentHeight() -> CGFloat {
        let queueCount = dataSource?.bangumiQueueIntroList.count ?? 0
        let queueAreaHeight: CGFloat
        if queueCount > 0 {
            queueAreaHeight = 36 + 16 + 8 + queueLayout.collectionViewContentSize.height
        } else {
            queueAreaHeight = 0
        }
        return bannerHeight + functionHeight + queueAreaHeight
    }

    private func reloadQueueData() {
        let queueCount = dataSource?.bangumiQueueIntroList.count ?? 0
        queueSectionHeader.isHidden = queueCount == 0
        queueCollectionView.isHidden = queueCount == 0
        queueCollectionView.reloadData()
        queueCollectionView.layoutSubtreeIfNeeded()
        viewDidLayout()
        let topY = max(contentView.bounds.height - scrollView.contentView.bounds.height, 0)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: topY))
    }

    // MARK: - Private

    private let bannerHeight: CGFloat = 200
    private let functionHeight: CGFloat = 130

    private func layoutSubviews() {
        bannerCarrier.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(bannerHeight)
        }

        pageControl.snp.makeConstraints { make in
            make.bottom.equalTo(bannerCarrier).offset(-8)
            make.centerX.equalToSuperview()
        }

        functionStackView.snp.makeConstraints { make in
            make.top.equalTo(bannerCarrier.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(functionHeight)
        }

        queueSectionHeader.snp.makeConstraints { make in
            make.top.equalTo(functionStackView.snp.bottom).offset(16)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
        }

        queueCollectionView.snp.makeConstraints { make in
            make.top.equalTo(queueSectionHeader.snp.bottom).offset(8)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    @objc private func startRefresh() {
        HomePageNetworkHandle.homePage { [weak self] homePage, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                if let error = error {
                    self.view.show(error: error)
                } else {
                    self.dataSource = homePage
                }
            }
        }
    }

    @objc private func loginStateChanged() {
        startRefresh()
        reloadFunctionItems()
    }

    // MARK: - Data updates

    private func updateBanner() {
        guard let banners = dataSource?.banners else { return }
        bannerCarrier.banners = banners
        pageControl.numberOfPages = banners.count
        pageControl.currentPage = 0
        bannerCarrier.onPageChanged = { [weak self] page in
            self?.pageControl.currentPage = page
        }
    }

    private func reloadFunctionItems() {
        functionStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        addFunctionButton(
            imageName: "calendar",
            name: NSLocalizedString("新番时间表", comment: "")
        ) { [weak self] in
            guard let self = self else { return }
            let vc = TimelineViewController()
            vc.dataSource = self.dataSource?.shinBangumiList
            vc.refreshDataCallBack = { [weak self] in
                self?.startRefresh()
            }
            self.navigator?.pushViewController(vc)
        }

        if Preferences.shared.loginInfo != nil {
            addFunctionButton(
                imageName: "heart.fill",
                name: NSLocalizedString("我的关注", comment: "")
            ) { [weak self] in
                guard let self = self else { return }
                let vc = FavoriteViewController()
                self.navigator?.pushViewController(vc)
            }
        }
    }

    private func addFunctionButton(imageName: String, name: String, action: @escaping () -> Void) {
        let container = NSView()

        let iconView = ImageView()
        iconView.image = NSImage(systemSymbolName: imageName, accessibilityDescription: nil)
        iconView.contentTintColor = .mainColor
        iconView.setScaling(.aspectFit)

        let label = Label(labelWithString: name)
        label.font = .ddp_small()
        label.alignment = .center

        container.addSubview(iconView)
        container.addSubview(label)

        iconView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(60)
        }

        label.snp.makeConstraints { make in
            make.top.equalTo(iconView.snp.bottom).offset(8)
            make.centerX.equalToSuperview()
        }

        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.cellHighlightColor.cgColor
        container.layer?.cornerRadius = 8

        let clickRecognizer = NSClickGestureRecognizer(target: self, action: #selector(functionButtonClicked(_:)))
        container.addGestureRecognizer(clickRecognizer)

        // Store the action using associated object or a simple array
        functionActions.append(action)

        functionStackView.addArrangedSubview(container)
    }

    private var functionActions: [() -> Void] = []

    @objc private func functionButtonClicked(_ gesture: NSClickGestureRecognizer) {
        guard let container = gesture.view,
              let index = functionStackView.arrangedSubviews.firstIndex(of: container),
              index < functionActions.count else { return }
        functionActions[index]()
    }
}

// MARK: - BannerCarouselView

private class BannerCarouselView: BaseView {

    var onBannerClick: ((BannerPageItem) -> Void)?
    var onPageChanged: ((Int) -> Void)?

    var banners: [BannerPageItem] = [] {
        didSet {
            rebuildImageViews()
            currentIndex = 0
            updateScrollPosition()
            startAutoScroll()
        }
    }

    private let sectionCount = 100
    private var currentIndex = 0 {
        didSet { updateLabelsForCurrentBanner() }
    }
    private var autoScrollTimer: Timer?
    private var imageViews: [ImageView] = []
    private let wheelScrollView = ScrollView<NSStackView>()
    private let stackView = NSStackView()

    private lazy var titleLabel: Label = {
        let tf = Label(labelWithString: "")
        tf.font = .ddp_large(weight: .bold)
        tf.textColor = .white
        tf.alignment = .left
        tf.cell?.wraps = true
        tf.cell?.isScrollable = false
        tf.maximumNumberOfLines = 2
        return tf
    }()

    private lazy var descLabel: Label = {
        let tf = Label(labelWithString: "")
        tf.font = .ddp_small()
        tf.textColor = .white
        tf.alignment = .left
        tf.cell?.wraps = true
        tf.cell?.isScrollable = false
        tf.maximumNumberOfLines = 3
        return tf
    }()

    private lazy var leftArrowView: NSView = {
        let view = makeArrowView(symbolName: "chevron.left")
        let click = NSClickGestureRecognizer(target: self, action: #selector(scrollToPrev))
        view.addGestureRecognizer(click)
        return view
    }()

    private lazy var rightArrowView: NSView = {
        let view = makeArrowView(symbolName: "chevron.right")
        let click = NSClickGestureRecognizer(target: self, action: #selector(scrollToNext))
        view.addGestureRecognizer(click)
        return view
    }()

    private func makeArrowView(symbolName: String) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.3).cgColor
        view.layer?.cornerRadius = 20
        view.alphaValue = 0

        let iv = ImageView()
        iv.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        iv.contentTintColor = .white
        iv.setScaling(.aspectFit)
        view.addSubview(iv)

        iv.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(20)
        }

        return view
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    deinit {
        autoScrollTimer?.invalidate()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow, .enabledDuringMouseDrag], owner: self, userInfo: nil)
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        stopAutoScroll()
        updateArrowVisibility(visible: true)
    }

    override func mouseExited(with event: NSEvent) {
        startAutoScroll()
        updateArrowVisibility(visible: false)
    }

    private func updateArrowVisibility(visible: Bool) {
        guard banners.count > 1 else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            leftArrowView.animator().alphaValue = visible ? 1 : 0
            rightArrowView.animator().alphaValue = visible ? 1 : 0
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard !banners.isEmpty else { return }
        onBannerClick?(banners[currentIndex])
    }

    // MARK: - Private

    private func setupUI() {
        layer?.backgroundColor = NSColor.placeholderColor.cgColor

        wheelScrollView.hasVerticalScroller = false
        wheelScrollView.hasHorizontalScroller = false
        wheelScrollView.borderType = .noBorder
        wheelScrollView.drawsBackground = false
        wheelScrollView.horizontalScrollElasticity = .none

        stackView.orientation = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 0

        wheelScrollView.containerView = stackView

        addSubview(wheelScrollView)
        addSubview(titleLabel)
        addSubview(descLabel)

        wheelScrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(leftArrowView)
        addSubview(rightArrowView)

        leftArrowView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(40)
        }

        rightArrowView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(40)
        }

        titleLabel.snp.makeConstraints { make in
            make.bottom.equalTo(descLabel.snp.top).offset(-4)
            make.leading.equalToSuperview().offset(16)
            make.trailing.lessThanOrEqualToSuperview().offset(-16)
        }

        descLabel.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-40)
            make.leading.equalToSuperview().offset(16)
            make.trailing.lessThanOrEqualToSuperview().offset(-16)
        }

        [titleLabel, descLabel].forEach { label in
            label.wantsLayer = true
            label.layer?.shadowColor = NSColor.black.cgColor
            label.layer?.shadowOffset = .init(width: 0, height: 1)
            label.layer?.shadowRadius = 2
            label.layer?.shadowOpacity = 0.6
        }
    }

    private func rebuildImageViews() {
        imageViews.removeAll()
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for banner in banners {
            let iv = makeBannerImageView(for: banner)
            imageViews.append(iv)
            stackView.addArrangedSubview(iv)
        }

        if !banners.isEmpty {
            let repeatedCount = sectionCount * banners.count
            for i in 0..<repeatedCount {
                if i < banners.count {
                    continue
                }
                let banner = banners[i % banners.count]
                let iv = makeBannerImageView(for: banner)
                imageViews.append(iv)
                stackView.addArrangedSubview(iv)
            }
        }

        needsLayout = true
    }

    private func makeBannerImageView(for banner: BannerPageItem) -> ImageView {
        let iv = ImageView()
        iv.setScaling(.aspectFill)
        if let url = URL(string: banner.imageUrl) {
            iv.kf.setImage(with: url)
        }
        return iv
    }

    private func updateLabelsForCurrentBanner() {
        guard !banners.isEmpty, currentIndex < banners.count else { return }
        let banner = banners[currentIndex]
        titleLabel.stringValue = banner.title
        descLabel.stringValue = banner.description
    }

    override func layout() {
        super.layout()
        let isResizing = bounds.width != imageViews.first?.frame.width
        if isResizing {
            stopAutoScroll()
        }
        let itemWidth = bounds.width
        let itemHeight = bounds.height
        for (i, iv) in imageViews.enumerated() {
            iv.frame = NSRect(x: CGFloat(i) * itemWidth, y: 0, width: itemWidth, height: itemHeight)
        }
        stackView.frame = NSRect(x: 0, y: 0, width: CGFloat(imageViews.count) * itemWidth, height: itemHeight)
        updateScrollPosition()
        if isResizing {
            startAutoScroll()
        }
    }

    private func updateScrollPosition() {
        guard !banners.isEmpty else { return }
        let mid = sectionCount / 2
        let targetIndex = mid * banners.count + currentIndex
        let x = CGFloat(targetIndex) * bounds.width
        wheelScrollView.contentView.scroll(to: NSPoint(x: x, y: 0))
        NotificationCenter.default.post(name: NSView.boundsDidChangeNotification, object: wheelScrollView.contentView)
    }

    private func startAutoScroll() {
        stopAutoScroll()
        guard banners.count > 1 else { return }
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.scrollToNext()
        }
    }

    private func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
    }

    @objc private func scrollToNext() {
        guard banners.count > 1 else { return }
        let nextIndex = (currentIndex + 1) % banners.count
        currentIndex = nextIndex
        scrollToCurrentIndex()
        onPageChanged?(currentIndex)
    }

    @objc private func scrollToPrev() {
        guard banners.count > 1 else { return }
        let prevIndex = (currentIndex - 1 + banners.count) % banners.count
        currentIndex = prevIndex
        scrollToCurrentIndex()
        onPageChanged?(currentIndex)
    }

    private func scrollToCurrentIndex() {
        let mid = sectionCount / 2
        let targetIndex = mid * banners.count + currentIndex
        let targetX = CGFloat(targetIndex) * bounds.width
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            wheelScrollView.contentView.animator().setBoundsOrigin(NSPoint(x: targetX, y: 0))
        }
    }
}

// MARK: - PageIndicator

private class PageIndicator: BaseView {

    var numberOfPages: Int = 0 {
        didSet { rebuildDots() }
    }

    var currentPage: Int = 0 {
        didSet { updateCurrentDot() }
    }

    private let dotSize: CGFloat = 8
    private let dotSpacing: CGFloat = 8
    private var dotViews: [NSView] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func rebuildDots() {
        dotViews.forEach { $0.removeFromSuperview() }
        dotViews.removeAll()

        guard numberOfPages > 1 else { return }

        for i in 0..<numberOfPages {
            let dot = NSView()
            dot.wantsLayer = true
            dot.layer?.cornerRadius = dotSize / 2
            dot.layer?.backgroundColor = (i == currentPage ? NSColor.mainColor : NSColor.lightGray).cgColor
            addSubview(dot)

            let x = CGFloat(i) * (dotSize + dotSpacing) - CGFloat(numberOfPages) * (dotSize + dotSpacing) / 2 + dotSize / 2
            dot.frame = NSRect(x: x, y: 0, width: dotSize, height: dotSize)
            dot.autoresizingMask = [.minXMargin, .maxXMargin]

            dotViews.append(dot)
        }

        needsLayout = true
    }

    override var intrinsicContentSize: NSSize {
        let width = CGFloat(numberOfPages) * (dotSize + dotSpacing) - dotSpacing
        return NSSize(width: max(width, 0), height: dotSize)
    }

    private func updateCurrentDot() {
        for (i, dot) in dotViews.enumerated() {
            dot.layer?.backgroundColor = (i == currentPage ? NSColor.mainColor : NSColor.lightGray).cgColor
        }
    }
}


// MARK: - NSCollectionViewDataSource

extension HomePageViewController: NSCollectionViewDataSource {

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataSource?.bangumiQueueIntroList.count ?? 0
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.dequeueItem(class: QueueItem.self, for: indexPath)
        if let queueItems = dataSource?.bangumiQueueIntroList, indexPath.item < queueItems.count {
            item.configure(with: queueItems[indexPath.item])
        }
        return item
    }
}

// MARK: - NSCollectionViewDelegate

extension HomePageViewController: NSCollectionViewDelegate {

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first,
              let items = dataSource?.bangumiQueueIntroList,
              indexPath.item < items.count else { return }
        collectionView.deselectItems(at: indexPaths)
        let data = items[indexPath.item]
        let vc = BangumiDetailViewController(animateId: data.animeId)
        navigator?.pushViewController(vc)
    }
}

// MARK: - WaterfallLayoutDelegate

extension HomePageViewController: WaterfallLayoutDelegate {

    func waterfallLayout(_ layout: WaterfallLayout, heightForItemAt indexPath: IndexPath, itemWidth: CGFloat) -> CGFloat {
        guard let items = dataSource?.bangumiQueueIntroList,
              indexPath.item < items.count else { return itemWidth * 1.6 }
        return QueueItem.estimatedHeight(for: items[indexPath.item], width: itemWidth)
    }
}

// MARK: - HomePageFunctionItemType

enum HomePageFunctionItemType {
    case timeLine
    case favorite
}
