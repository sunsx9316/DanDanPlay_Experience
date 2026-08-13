//
//  TagSearchResultViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/7/10.
//

import Cocoa
import SnapKit
import Kingfisher

class TagSearchResultViewController: ViewController, NSTableViewDataSource, NSTableViewDelegate {

    private let tagName: String

    private var items: [SearchBangumiDetails] = []

    private lazy var tableView: TableView = {
        let tv = TableView()
        tv.dataSource = self
        tv.delegate = self
        tv.backgroundColor = .backgroundColor
        tv.headerView = nil
        tv.registerClassCell(class: TagSearchResultTableViewCell.self)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("result"))
        column.width = 500
        tv.addTableColumn(column)

        return tv
    }()

    private lazy var scrollView: ScrollView<TableView> = {
        let sv = ScrollView<TableView>()
        sv.containerView = tableView
        sv.hasVerticalScroller = true
        sv.borderType = .noBorder
        sv.drawsBackground = false
        return sv
    }()

    init(tag: String) {
        self.tagName = tag
        super.init()
        self.title = tag
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

    // MARK: - Private

    private func startRefresh() {
        view.showLoading(statusText: "")

        SearchNetworkHandle.searchByTag(tagName) { [weak self] res, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.view.dismiss(delay: 0)

                if let error = error {
                    self.view.show(error: error)
                } else {
                    self.items = res?.bangumis ?? []
                    self.tableView.reloadData()
                }
            }
        }
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        return items.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.dequeueReusableCell(class: TagSearchResultTableViewCell.self)
        cell.configure(with: items[row])
        cell.onFavoriteToggle = { [weak self] animeId, isLike in
            FavoriteNetworkHandle.changeFavorite(animateId: animeId, isLike: isLike) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.view.show(error: error)
                    }
                }
            }
        }
        return cell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 110
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        guard row < items.count else { return false }
        let vc = BangumiDetailViewController(animateId: items[row].animeId)
        navigator?.pushViewController(vc)
        return false
    }
}

// MARK: - TagSearchResultTableViewCell

class TagSearchResultTableViewCell: NSTableCellView {

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
        return f
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        addSubview(coverImageView)
        addSubview(titleLabel)
        addSubview(ratingLabel)
        addSubview(statusLabel)
        addSubview(favoriteButton)

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

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with item: SearchBangumiDetails) {
        animeId = item.animeId
        isFavorited = item.isFavorited
        titleLabel.text = item.animeTitle

        if let url = URL(string: item.imageUrl) {
            coverImageView.kf.setImage(with: url)
        }

        let rating = item.rating
        ratingLabel.text = ratingFormatter.string(from: NSNumber(value: rating)) ?? "\(rating)"
        ratingLabel.isHidden = rating <= 0

        statusLabel.text = item.isOnAir ? NSLocalizedString("连载中", comment: "") : NSLocalizedString("已完结", comment: "")
        statusLabel.textColor = item.isOnAir ? .mainColor : .subtitleTextColor

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
