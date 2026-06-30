//
//  TimelineViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/29.
//

import Cocoa
import SnapKit
import Kingfisher

class TimelineViewController: ViewController, NSCollectionViewDataSource, NSCollectionViewDelegateFlowLayout {

    private var currentList: [BangumiIntro] = []

    private var allData: [BangumiIntro] = [] {
        didSet {
            filterBySelectedDay()
        }
    }

    var refreshDataCallBack: (() -> Void)?

    var dataSource: [BangumiIntro]? {
        didSet {
            guard let dataSource = self.dataSource else { return }
            allData = dataSource

            var pageDays = Set<Int>()
            for info in dataSource {
                pageDays.insert(info.airDay)
            }
            let sortedDays = pageDays.sorted()

            let titles = sortedDays.map { day -> String in
                switch day {
                case 0: return "周日"
                default: return "周" + NumberUtils.numberToChinese(day)
                }
            }

            weekdays = sortedDays
            segmentBar.titles = titles

            // 定位到今天
            let today = Calendar.current.component(.weekday, from: Date()) - 1
            let index = sortedDays.firstIndex(of: today) ?? 0
            segmentBar.selectedIndex = index
            selectedDay = sortedDays.isEmpty ? 0 : sortedDays[index]
        }
    }

    private var weekdays: [Int] = []
    private var selectedDay: Int = 0 {
        didSet {
            filterBySelectedDay()
        }
    }

    private lazy var segmentBar: TimelineSegmentBar = {
        let bar = TimelineSegmentBar()
        bar.onSelected = { [weak self] index in
            guard let self = self, index < self.weekdays.count else { return }
            self.selectedDay = self.weekdays[index]
            self.segmentBar.selectedIndex = index
        }
        return bar
    }()

    private lazy var collectionView: CollectionView = {
        let cv = CollectionView()
        cv.collectionViewLayout = NSCollectionViewFlowLayout()
        cv.dataSource = self
        cv.delegate = self
        cv.backgroundColors = [.backgroundColor]
        cv.isSelectable = true
        cv.frame = NSRect(x: 0, y: 0, width: 600, height: 400)
        cv.registerItem(class: TimelineItem.self)
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

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("新番时间表", comment: "")

        view.addSubview(segmentBar)
        view.addSubview(scrollView)

        segmentBar.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(40)
        }

        scrollView.snp.makeConstraints { make in
            make.top.equalTo(segmentBar.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        updateCollectionViewFrame()
    }

    // MARK: - Private

    private func filterBySelectedDay() {
        currentList = allData.filter { $0.airDay == selectedDay }
        collectionView.reloadData()
        updateCollectionViewFrame()
    }

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

    // MARK: - NSCollectionViewDataSource

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return currentList.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.dequeueItem(class: TimelineItem.self, for: indexPath)
        let model = currentList[indexPath.item]
        item.configure(with: model)
        item.onFavoriteToggle = { [weak self] animeId, isLike in
            FavoriteNetworkHandle.changeFavorite(animateId: animeId, isLike: isLike) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.view.show(error: error)
                    } else {
                        self?.refreshDataCallBack?()
                    }
                }
            }
        }
        return item
    }

    // MARK: - NSCollectionViewDelegateFlowLayout

    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
        let width = min(collectionView.bounds.width, 560)
        return NSSize(width: width, height: 110)
    }

    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }

    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        collectionView.deselectItems(at: indexPaths)
        guard let indexPath = indexPaths.first,
              indexPath.item < currentList.count else { return }
        let vc = BangumiDetailViewController(animateId: currentList[indexPath.item].animeId)
        navigator?.pushViewController(vc)
    }
}

// MARK: - TimelineItem

class TimelineItem: CollectionViewItem {

    var onFavoriteToggle: ((Int, Bool) -> Void)?

    private var animeId: Int = 0
    private var isFavorited: Bool = false

    private lazy var coverImageView: ImageView = {
        let iv = ImageView()
        iv.setScaling(.scaleToFill)
        iv.wantsLayer = true
        iv.layer?.masksToBounds = true
        iv.layer?.cornerRadius = 4
        return iv
    }()

    private lazy var titleLabel: Label = {
        let tf = Label(labelWithString: "")
        tf.font = .ddp_normal()
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

    private lazy var ratingFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 1
        f.roundingMode = .halfEven
        return f
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
        view.addSubview(favoriteButton)

        coverImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(15)
            make.centerY.equalToSuperview()
            make.width.equalTo(80)
            make.height.equalTo(100)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(coverImageView.snp.trailing).offset(12)
            make.top.equalTo(coverImageView.snp.top).offset(4)
            make.trailing.equalTo(favoriteButton.snp.leading).offset(-8)
        }

        ratingLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(6)
        }

        statusLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(ratingLabel.snp.bottom).offset(4)
        }

        favoriteButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-15)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(24)
        }
    }

    func configure(with item: BangumiIntro) {
        animeId = item.animeId
        isFavorited = item.isFavorited
        titleLabel.stringValue = item.animeTitle

        if let url = URL(string: item.imageUrl) {
            coverImageView.kf.setImage(with: url)
        }

        let rating = item.rating
        ratingLabel.stringValue = ratingFormatter.string(from: NSNumber(value: rating)) ?? "\(rating)"
        ratingLabel.isHidden = rating <= 0

        statusLabel.stringValue = item.isOnAir ? NSLocalizedString("连载中", comment: "") : NSLocalizedString("已完结", comment: "")

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
}
