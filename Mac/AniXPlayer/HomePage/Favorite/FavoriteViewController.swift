//
//  FavoriteViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/29.
//

import Cocoa
import SnapKit
import Kingfisher

class FavoriteViewController: ViewController, NSCollectionViewDataSource, NSCollectionViewDelegateFlowLayout {

    private var dataList: [UserFavoriteItem] = [] {
        didSet {
            collectionView.reloadData()
            updateCollectionViewFrame()
        }
    }

    private lazy var collectionView: CollectionView = {
        let cv = CollectionView()
        cv.collectionViewLayout = NSCollectionViewFlowLayout()
        cv.dataSource = self
        cv.delegate = self
        cv.backgroundColors = [.backgroundColor]
        cv.isSelectable = true
        cv.frame = NSRect(x: 0, y: 0, width: 600, height: 400)
        cv.registerItem(class: FavoriteItem.self)
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

    private lazy var loginPromptLabel: Label = {
        let tf = Label(labelWithString: NSLocalizedString("请先登录以查看关注", comment: ""))
        tf.font = .ddp_normal()
        tf.textColor = .subtitleTextColor
        tf.alignment = .center
        tf.isHidden = true
        return tf
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("我的关注", comment: "")

        view.addSubview(scrollView)
        view.addSubview(loginPromptLabel)

        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        loginPromptLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        if Preferences.shared.loginInfo == nil {
            loginPromptLabel.isHidden = false
            scrollView.isHidden = true
        } else {
            loginPromptLabel.isHidden = true
            scrollView.isHidden = false
            fetchData()
        }
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

    private func fetchData() {
        FavoriteNetworkHandle.getFavoriteList { [weak self] rsp, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let error = error {
                    self.view.show(error: error)
                } else if let list = rsp?.favorites {
                    self.dataList = list
                }
            }
        }
    }

    // MARK: - NSCollectionViewDataSource

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataList.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.dequeueItem(class: FavoriteItem.self, for: indexPath)
        let model = dataList[indexPath.item]
        item.configure(with: model)
        item.onFavoriteToggle = { [weak self] animeId, isLike in
            FavoriteNetworkHandle.changeFavorite(animateId: animeId, isLike: isLike) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.view.show(error: error)
                    } else {
                        self?.fetchData()
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
              indexPath.item < dataList.count else { return }
        let vc = BangumiDetailViewController(animateId: dataList[indexPath.item].animeId)
        navigator?.pushViewController(vc)
    }
}

// MARK: - FavoriteItem

class FavoriteItem: CollectionViewItem {

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

    private lazy var lastWatchLabel: Label = {
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
        view.addSubview(lastWatchLabel)
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

        lastWatchLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(statusLabel.snp.bottom).offset(4)
        }

        favoriteButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-15)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(24)
        }
    }

    func configure(with item: UserFavoriteItem) {
        animeId = item.animeId
        isFavorited = item.favoriteStatus == .favorited
        titleLabel.text = item.animeTitle

        if let url = URL(string: item.imageUrl) {
            coverImageView.kf.setImage(with: url)
        }

        let rating = item.rating
        ratingLabel.text = ratingFormatter.string(from: NSNumber(value: rating)) ?? "\(rating)"
        ratingLabel.isHidden = rating <= 0

        statusLabel.text = item.isOnAir ? NSLocalizedString("连载中", comment: "") : NSLocalizedString("已完结", comment: "")

        if let lastWatch = item.lastWatchTime {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            lastWatchLabel.text = String(format: NSLocalizedString("上次观看: %@", comment: ""), formatter.string(from: lastWatch))
            lastWatchLabel.isHidden = false
        } else {
            lastWatchLabel.isHidden = true
        }

        let symbolName = isFavorited ? "heart.fill" : "heart"
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
