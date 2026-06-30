//
//  BangumiDetailViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/29.
//

import Cocoa
import SnapKit
import Kingfisher

class BangumiDetailViewController: ViewController, NSCollectionViewDataSource, NSCollectionViewDelegateFlowLayout {

    private let animateId: Int

    private var detail: BangumiDetail? {
        didSet {
            collectionView.reloadData()
            updateCollectionViewFrame()
        }
    }

    private enum SectionType: CaseIterable {
        case info
        case episodes
        case relateds
        case similars
    }

    private var sections: [SectionType] = SectionType.allCases

    private lazy var collectionView: CollectionView = {
        let cv = CollectionView()
        cv.collectionViewLayout = NSCollectionViewFlowLayout()
        cv.dataSource = self
        cv.delegate = self
        cv.backgroundColors = [.backgroundColor]
        cv.isSelectable = true
        cv.frame = NSRect(x: 0, y: 0, width: 600, height: 400)
        cv.registerItem(class: DetailHeaderItem.self)
        cv.registerItem(class: DetailEpisodeRowItem.self)
        cv.registerItem(class: DetailRelatedItem.self)
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

    init(animateId: Int) {
        self.animateId = animateId
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        startRefresh()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        updateCollectionViewFrame()
    }

    // MARK: - Private

    private var lastCollectionViewWidth: CGFloat = 0

    private func updateCollectionViewFrame() {
        let newWidth = scrollView.contentView.bounds.width
        let contentSize = collectionView.collectionViewLayout?.collectionViewContentSize ?? .zero
        collectionView.frame = NSRect(
            x: 0,
            y: 0,
            width: newWidth,
            height: max(contentSize.height, scrollView.contentView.bounds.height)
        )
        if lastCollectionViewWidth != newWidth {
            lastCollectionViewWidth = newWidth
            collectionView.collectionViewLayout?.invalidateLayout()
        }
    }

    private func startRefresh() {
        BangumiNetworkHandle.detail(animateId: animateId) { [weak self] rsp, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let error = error {
                    self.view.show(error: error)
                } else if let detail = rsp?.bangumi {
                    self.title = detail.animeTitle
                    // Recompute visible sections
                    var visible: [SectionType] = [.info, .episodes]
                    if !detail.relateds.isEmpty { visible.append(.relateds) }
                    if !detail.similars.isEmpty { visible.append(.similars) }
                    self.sections = visible
                    self.detail = detail
                }
            }
        }
    }

    private func pushDetail(animateId: Int) {
        let vc = BangumiDetailViewController(animateId: animateId)
        navigator?.pushViewController(vc)
    }

    // MARK: - NSCollectionViewDataSource

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return detail == nil ? 0 : sections.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let type = sections[indexPath.item]
        switch type {
        case .info:
            let item = collectionView.dequeueItem(class: DetailHeaderItem.self, for: indexPath)
            if let detail = detail {
                item.configure(with: detail)
                item.onFavoriteToggle = { [weak self] animeId, isLike in
                    FavoriteNetworkHandle.changeFavorite(animateId: animeId, isLike: isLike) { error in
                        DispatchQueue.main.async {
                            if let error = error {
                                self?.view.show(error: error)
                            } else {
                                self?.startRefresh()
                            }
                        }
                    }
                }
                item.onTapMetadata = { [weak self] in
                    guard let self = self, let detail = self.detail else { return }
                    let vc = BangumiDetailMetadataViewController()
                    vc.configure(metaData: detail.metadata, titles: detail.titles, onlineDatabases: detail.onlineDatabases)
                    self.navigator?.pushViewController(vc)
                }
            }
            return item
        case .episodes:
            let item = collectionView.dequeueItem(class: DetailEpisodeRowItem.self, for: indexPath)
            item.onTap = { [weak self] in
                guard let self = self, let detail = self.detail else { return }
                let vc = BangumiDetailEpisodeViewController()
                vc.dataSource = detail.episodes
                self.navigator?.pushViewController(vc)
            }
            return item
        case .relateds, .similars:
            let item = collectionView.dequeueItem(class: DetailRelatedItem.self, for: indexPath)
            if let detail = detail {
                let data = type == .relateds ? detail.relateds : detail.similars
                let title = type == .relateds ? NSLocalizedString("关联作品", comment: "") : NSLocalizedString("相似作品", comment: "")
                item.configure(title: title, items: data)
                item.onSelectAnime = { [weak self] animeId in
                    self?.pushDetail(animateId: animeId)
                }
                item.onFavoriteToggle = { [weak self] animeId, isLike in
                    FavoriteNetworkHandle.changeFavorite(animateId: animeId, isLike: isLike) { error in
                        DispatchQueue.main.async {
                            if let error = error {
                                self?.view.show(error: error)
                            } else {
                                self?.startRefresh()
                            }
                        }
                    }
                }
            }
            return item
        }
    }

    // MARK: - NSCollectionViewDelegateFlowLayout

    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
        let width = collectionView.bounds.width
        let type = sections[indexPath.item]
        switch type {
        case .info:
            return NSSize(width: width, height: 170)
        case .episodes:
            return NSSize(width: width, height: 60)
        case .relateds, .similars:
            let list = type == .relateds ? (detail?.relateds ?? []) : (detail?.similars ?? [])
            guard !list.isEmpty else { return NSSize(width: width, height: 0.01) }
            let h = DetailRelatedItem.estimatedHeight(for: list, width: width)
            return NSSize(width: width, height: h)
        }
    }

    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }

    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
}

// MARK: - DetailHeaderItem (Info row)

class DetailHeaderItem: CollectionViewItem {

    var onFavoriteToggle: ((Int, Bool) -> Void)?
    var onTapMetadata: (() -> Void)?

    private var animeId: Int = 0
    private var isFavorited: Bool = false

    private lazy var coverImageView: ImageView = {
        let iv = ImageView()
        iv.setScaling(.proportionallyDown)
        iv.wantsLayer = true
        iv.layer?.masksToBounds = true
        iv.layer?.cornerRadius = 4
        return iv
    }()

    private lazy var titleLabel: Label = {
        let tf = Label(labelWithString: "")
        tf.font = .ddp_large(weight: .bold)
        tf.textColor = .textColor
        tf.lineBreakMode = .byTruncatingTail
        return tf
    }()

    private lazy var ratingLabel: Label = {
        let tf = Label(labelWithString: "")
        tf.font = .ddp_normal(weight: .bold)
        tf.textColor = .mainColor
        return tf
    }()

    private lazy var statusLabel: Label = {
        let tf = Label(labelWithString: "")
        tf.font = .ddp_small()
        tf.textColor = .subtitleTextColor
        return tf
    }()

    private lazy var tagsLabel: Label = {
        let tf = Label(labelWithString: "")
        tf.font = .ddp_small()
        tf.textColor = .subtitleTextColor
        tf.lineBreakMode = .byTruncatingTail
        return tf
    }()

    private lazy var favoriteButton: Button = {
        let btn = Button(
            image: NSImage.safeSystemSymbol("heart"),
            target: self,
            action: #selector(favoriteClicked)
        )
        btn.bezelStyle = .inline
        btn.isBordered = false
        btn.contentTintColor = .mainColor
        return btn
    }()

    private lazy var metadataArrow: Button = {
        let btn = Button(
            image: NSImage.safeSystemSymbol("chevron.right"),
            target: self,
            action: #selector(metadataClicked)
        )
        btn.bezelStyle = .inline
        btn.isBordered = false
        btn.contentTintColor = .subtitleTextColor
        return btn
    }()

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.backgroundColor.cgColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(coverImageView)
        view.addSubview(titleLabel)
        view.addSubview(ratingLabel)
        view.addSubview(statusLabel)
        view.addSubview(tagsLabel)
        view.addSubview(favoriteButton)
        view.addSubview(metadataArrow)

        coverImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalToSuperview().offset(15)
            make.width.equalTo(100)
            make.height.equalTo(120)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(coverImageView.snp.trailing).offset(15)
            make.top.equalTo(coverImageView.snp.top).offset(4)
            make.trailing.equalTo(favoriteButton.snp.leading).offset(-8)
        }

        ratingLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
        }

        statusLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(ratingLabel.snp.bottom).offset(4)
        }

        tagsLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(statusLabel.snp.bottom).offset(4)
            make.trailing.equalToSuperview().offset(-80)
        }

        favoriteButton.snp.makeConstraints { make in
            make.trailing.equalTo(metadataArrow.snp.leading).offset(-8)
            make.centerY.equalTo(titleLabel)
            make.width.height.equalTo(24)
        }

        metadataArrow.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-15)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }
    }

    func configure(with item: BangumiDetail) {
        animeId = item.animeId
        isFavorited = item.isFavorited
        titleLabel.stringValue = item.animeTitle

        if let url = URL(string: item.imageUrl) {
            coverImageView.kf.setImage(with: url)
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        ratingLabel.stringValue = formatter.string(from: NSNumber(value: item.rating)) ?? "\(item.rating)"

        statusLabel.stringValue = item.isOnAir ? NSLocalizedString("连载中", comment: "") : NSLocalizedString("已完结", comment: "")

        let tagText = item.tags.sorted(by: { $0.count > $1.count }).prefix(5).map { $0.name }.joined(separator: ", ")
        tagsLabel.stringValue = tagText

        let symbolName = item.isFavorited ? "heart.fill" : "heart"
        favoriteButton.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
    }

    @objc private func favoriteClicked() {
        let newState = !isFavorited
        isFavorited = newState
        let symbolName = newState ? "heart.fill" : "heart"
        favoriteButton.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        onFavoriteToggle?(animeId, newState)
    }

    @objc private func metadataClicked() {
        onTapMetadata?()
    }
}

// MARK: - DetailEpisodeRowItem

class DetailEpisodeRowItem: CollectionViewItem {

    var onTap: (() -> Void)?

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.backgroundColor.cgColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let titleLabel = Label(labelWithString: NSLocalizedString("分集详情", comment: ""))
        titleLabel.font = .ddp_normal()
        titleLabel.textColor = .textColor

        let subtitleLabel = Label(labelWithString: NSLocalizedString("分集信息、观看信息等", comment: ""))
        subtitleLabel.font = .ddp_small()
        subtitleLabel.textColor = .subtitleTextColor

        let arrowImageView = ImageView()
        arrowImageView.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)
        arrowImageView.contentTintColor = .subtitleTextColor

        let separator = NSView()
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.separatorColor.cgColor

        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(arrowImageView)
        view.addSubview(separator)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalToSuperview().offset(12)
            make.trailing.equalTo(arrowImageView.snp.leading).offset(-8)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
        }

        arrowImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-15)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }

        separator.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
            make.height.equalTo(1)
        }

        let clickRecognizer = NSClickGestureRecognizer(target: self, action: #selector(itemClicked))
        view.addGestureRecognizer(clickRecognizer)
    }

    @objc private func itemClicked() {
        onTap?()
    }
}

// MARK: - DetailRelatedItem

class DetailRelatedItem: CollectionViewItem, NSCollectionViewDataSource, NSCollectionViewDelegate, WaterfallLayoutDelegate {

    var onSelectAnime: ((Int) -> Void)?
    var onFavoriteToggle: ((Int, Bool) -> Void)?

    private var items: [BangumiIntro] = []

    private lazy var titleLabel: Label = {
        let tf = Label(labelWithString: "")
        tf.font = .ddp_normal(weight: .bold)
        tf.textColor = .textColor
        return tf
    }()

    private lazy var waterfallLayout: WaterfallLayout = {
        let layout = WaterfallLayout()
        layout.columnCount = 2
        layout.delegate = self
        return layout
    }()

    private lazy var innerCollectionView: CollectionView = {
        let cv = CollectionView()
        cv.collectionViewLayout = waterfallLayout
        cv.dataSource = self
        cv.delegate = self
        cv.backgroundColors = [.backgroundColor]
        cv.isSelectable = true
        cv.frame = NSRect(x: 0, y: 0, width: 600, height: 180)
        cv.registerItem(class: RelatedAnimeItem.self)
        return cv
    }()

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(titleLabel)
        view.addSubview(innerCollectionView)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalToSuperview().offset(8)
            make.trailing.equalToSuperview().offset(-20)
        }

        innerCollectionView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
        }
    }

    func configure(title: String, items: [BangumiIntro]) {
        titleLabel.stringValue = title
        self.items = items
        innerCollectionView.reloadData()
        innerCollectionView.layoutSubtreeIfNeeded()
        let contentSize = waterfallLayout.collectionViewContentSize
        innerCollectionView.frame.size = NSSize(
            width: view.bounds.width,
            height: max(contentSize.height, 180)
        )
    }

    static func estimatedHeight(for items: [BangumiIntro], width: CGFloat) -> CGFloat {
        guard !items.isEmpty else { return 0 }

        let layout = WaterfallLayout()
        layout.columnCount = 2
        let availableWidth = width - layout.sectionInset.left - layout.sectionInset.right
        let itemWidth = (availableWidth - layout.itemPadding * CGFloat(layout.columnCount - 1)) / CGFloat(layout.columnCount)

        var columnHeights = Array(repeating: layout.sectionInset.top, count: layout.columnCount)
        for item in items {
            let column = columnHeights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            let height = RelatedAnimeItem.estimatedHeight(for: item, width: itemWidth)
            columnHeights[column] = columnHeights[column] + height + layout.itemPadding
        }
        let waterfallHeight = (columnHeights.max() ?? layout.sectionInset.top) + layout.sectionInset.bottom
        return 18 + 8 + waterfallHeight
    }

    // MARK: - NSCollectionViewDataSource

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.dequeueItem(class: RelatedAnimeItem.self, for: indexPath)
        let model = items[indexPath.item]
        item.configure(with: model)
        item.onFavoriteToggle = { [weak self] animeId, isLike in
            self?.onFavoriteToggle?(animeId, isLike)
        }
        return item
    }

    // MARK: - NSCollectionViewDelegate

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        collectionView.deselectItems(at: indexPaths)
        guard let indexPath = indexPaths.first,
              indexPath.item < items.count else { return }
        onSelectAnime?(items[indexPath.item].animeId)
    }

    // MARK: - WaterfallLayoutDelegate

    func waterfallLayout(_ layout: WaterfallLayout, heightForItemAt indexPath: IndexPath, itemWidth: CGFloat) -> CGFloat {
        guard indexPath.item < items.count else { return itemWidth * 1.6 }
        return RelatedAnimeItem.estimatedHeight(for: items[indexPath.item], width: itemWidth)
    }
}

// MARK: - RelatedAnimeItem

class RelatedAnimeItem: CollectionViewItem {

    var onFavoriteToggle: ((Int, Bool) -> Void)?

    private var animeId: Int = 0
    private var isFavorited: Bool = false

    private lazy var coverImageView: ImageView = {
        let iv = ImageView()
        iv.setScaling(.aspectFill)
        iv.wantsLayer = true
        iv.layer?.masksToBounds = true
        iv.layer?.cornerRadius = 4
        return iv
    }()

    private lazy var titleLabel: Label = {
        let tf = Label(labelWithString: "")
        tf.font = .ddp_small()
        tf.textColor = .textColor
        tf.lineBreakMode = .byTruncatingTail
        tf.maximumNumberOfLines = 2
        return tf
    }()

    private lazy var ratingLabel: Label = {
        let tf = Label(labelWithString: "")
        tf.font = .ddp_small(weight: .bold)
        tf.textColor = .mainColor
        return tf
    }()

    private lazy var favoriteButton: Button = {
        let btn = Button(
            image: NSImage.safeSystemSymbol("heart"),
            target: self,
            action: #selector(favoriteClicked)
        )
        btn.bezelStyle = .inline
        btn.isBordered = false
        btn.contentTintColor = .mainColor
        return btn
    }()

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(coverImageView)
        view.addSubview(titleLabel)
        view.addSubview(ratingLabel)
        view.addSubview(favoriteButton)

        coverImageView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(coverImageView.snp.width).multipliedBy(1.4)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(coverImageView.snp.bottom).offset(4)
            make.leading.equalToSuperview().offset(4)
            make.trailing.equalToSuperview().offset(-4)
        }

        ratingLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
            make.bottom.equalToSuperview().offset(-4)
        }

        favoriteButton.snp.makeConstraints { make in
            make.leading.equalTo(ratingLabel.snp.trailing).offset(4)
            make.centerY.equalTo(ratingLabel)
            make.width.height.equalTo(16)
        }
    }

    func configure(with item: BangumiIntro) {
        animeId = item.animeId
        isFavorited = item.isFavorited
        titleLabel.stringValue = item.animeTitle

        if let url = URL(string: item.imageUrl) {
            coverImageView.kf.setImage(with: url)
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        ratingLabel.stringValue = formatter.string(from: NSNumber(value: item.rating)) ?? "\(item.rating)"

        let symbolName = item.isFavorited ? "heart.fill" : "heart"
        favoriteButton.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
    }

    static func estimatedHeight(for item: BangumiIntro, width: CGFloat) -> CGFloat {
        let imageHeight = width * 1.4
        let titleHeight = item.animeTitle.boundingRect(
            with: NSSize(width: width - 8, height: 34),
            options: .usesLineFragmentOrigin,
            attributes: [.font: NSFont.ddp_small()]
        ).height.rounded(.up)
        return 4 + imageHeight + 4 + titleHeight + 2 + 16 + 4
    }

    @objc private func favoriteClicked() {
        let newState = !isFavorited
        isFavorited = newState
        let symbolName = newState ? "heart.fill" : "heart"
        favoriteButton.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        onFavoriteToggle?(animeId, newState)
    }
}
