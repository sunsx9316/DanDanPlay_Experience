//
//  FavoriteViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/29.
//

import Cocoa
import SnapKit

class FavoriteViewController: ViewController, NSCollectionViewDataSource, NSCollectionViewDelegate, WaterfallLayoutDelegate {

    private var dataList: [UserFavoriteItem] = [] {
        didSet {
            waterfallLayout.invalidateLayout()
            collectionView.reloadData()
            updateCollectionFrame()
        }
    }

    private lazy var waterfallLayout: WaterfallLayout = {
        let layout = WaterfallLayout()
        layout.columnCount = 2
        layout.delegate = self
        return layout
    }()

    private lazy var collectionView: CollectionView = {
        let cv = CollectionView()
        cv.collectionViewLayout = waterfallLayout
        cv.dataSource = self
        cv.delegate = self
        cv.backgroundColors = [.backgroundColor]
        cv.isSelectable = true
        cv.frame = NSRect(x: 0, y: 0, width: 600, height: 400)
        cv.registerItem(class: FavoriteCollectionViewCell.self)
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
        scrollView.snp.makeConstraints { make in make.edges.equalToSuperview() }
        loginPromptLabel.snp.makeConstraints { make in make.center.equalToSuperview() }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let isLoggedIn = await SessionStore.shared.isLoggedIn()
            self.loginPromptLabel.isHidden = isLoggedIn
            self.scrollView.isHidden = !isLoggedIn

            guard isLoggedIn,
                  await LoginGate.shared.ensureAccessToken(presenting: self.view.window) else {
                return
            }
            self.fetchData()
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        updateCollectionFrame()
    }

    // MARK: - Private

    private func updateCollectionFrame() {
        let w = scrollView.contentView.bounds.width
        guard w > 0 else { return }
        collectionView.frame.size.width = w
        collectionView.layoutSubtreeIfNeeded()
        let h = waterfallLayout.collectionViewContentSize.height
        collectionView.frame.size.height = max(h, scrollView.contentView.bounds.height)
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
        dataList.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.dequeueItem(class: FavoriteCollectionViewCell.self, for: indexPath)
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

    // MARK: - NSCollectionViewDelegate

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        collectionView.deselectItems(at: indexPaths)
        guard let indexPath = indexPaths.first, indexPath.item < dataList.count else { return }
        navigator?.pushViewController(BangumiDetailViewController(animateId: dataList[indexPath.item].animeId))
    }

    // MARK: - WaterfallLayoutDelegate

    func waterfallLayout(_ layout: WaterfallLayout, heightForItemAt indexPath: IndexPath, itemWidth: CGFloat) -> CGFloat {
        guard indexPath.item < dataList.count else { return itemWidth * 1.6 }
        let item = dataList[indexPath.item]
        let ih = itemWidth * 1.4
        let th = item.animeTitle.boundingRect(
            with: NSSize(width: itemWidth - 16, height: 40),
            options: .usesLineFragmentOrigin,
            attributes: [.font: NSFont.ddp_normal()]
        ).height.rounded(.up)
        var extra: CGFloat = 0
        if item.lastWatchTime != nil { extra += 20 }
        return 4 + ih + 4 + th + 4 + 20 + 4 + extra + 8
    }
}
