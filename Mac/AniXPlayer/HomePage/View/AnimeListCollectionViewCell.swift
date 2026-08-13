//
//  AnimeListCollectionViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/7/10.
//

import Cocoa
import SnapKit
import Kingfisher

// MARK: - Protocol

protocol AnimeListItem {
    var animeId: Int { get }
    var animeTitle: String { get }
    var imageUrl: String { get }
    var rating: Double { get }
    var typeDescription: String { get }
    var isOnAir: Bool { get }
    var isFavorited: Bool { get }
}

// MARK: - AnimeListCollectionViewCell

/// 上图下文布局基类：海报（撑满宽度，1.4:1）+ 下方 infoStackView
/// 子类覆写 viewDidLoad 向 infoStackView 插入额外视图即可
class AnimeListCollectionViewCell: CollectionViewItem {

    // MARK: Subviews

    private lazy var posterContainer: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.shadowColor = NSColor.black.cgColor
        view.layer?.shadowOffset = NSSize(width: 0, height: 2)
        view.layer?.shadowRadius = 4
        view.layer?.shadowOpacity = 0.15
        return view
    }()

    lazy var imgView: ImageView = {
        let iv = ImageView()
        iv.setScaling(.aspectFill)
        iv.wantsLayer = true
        iv.layer?.cornerRadius = 6
        iv.layer?.masksToBounds = true
        return iv
    }()

    private lazy var ratingBadge: Label = {
        let label = Label(labelWithString: "")
        label.font = .ddp_small(weight: .bold)
        label.textColor = .white
        label.alignment = .center
        label.wantsLayer = true
        label.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.5).cgColor
        label.layer?.cornerRadius = 4
        label.layer?.masksToBounds = true
        return label
    }()

    lazy var titleLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .ddp_normal()
        label.textColor = .textColor
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 2
        return label
    }()

    lazy var favoritedButton: Button = {
        let btn = Button()
        btn.bezelStyle = .inline
        btn.isBordered = false
        return btn
    }()

    lazy var isOnAirLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .ddp_small()
        return label
    }()

    lazy var typeLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .ddp_small()
        label.wantsLayer = true
        label.layer?.cornerRadius = 4
        label.layer?.masksToBounds = true
        label.layer?.borderWidth = 0.5
        return label
    }()

    /// 子类可向此 StackView 插入额外视图
    lazy var infoStackView: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 4
        stack.alignment = .leading
        return stack
    }()

    private lazy var topRowStack: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        return stack
    }()

    var item: AnimeListItem?

    var onFavoriteToggle: ((Int, Bool) -> Void)?

    // MARK: Update

    func update(item: AnimeListItem, ratingNumberFormatter: NumberFormatter) {
        self.item = item

        if !item.imageUrl.isEmpty {
            self.imgView.kf.setImage(with: URL(string: item.imageUrl))
        }

        self.titleLabel.text = item.animeTitle

        if let ratingText = ratingNumberFormatter.string(from: NSNumber(value: item.rating)) {
            ratingBadge.text = "⭐ " + ratingText
            ratingBadge.isHidden = false
        } else {
            ratingBadge.isHidden = true
        }

        if item.isOnAir {
            self.isOnAirLabel.text = NSLocalizedString("连载中", comment: "")
            self.isOnAirLabel.textColor = .mainColor
        } else {
            self.isOnAirLabel.text = NSLocalizedString("已完结", comment: "")
            self.isOnAirLabel.textColor = .subtitleTextColor
        }

        if !item.typeDescription.isEmpty {
            self.typeLabel.text = " " + item.typeDescription + " "
            self.typeLabel.textColor = .mainColor
            self.typeLabel.wantsLayer = true
            self.typeLabel.layer?.backgroundColor = NSColor.mainColor.withAlphaComponent(0.12).cgColor
            self.typeLabel.layer?.borderColor = NSColor.mainColor.withAlphaComponent(0.25).cgColor
            self.typeLabel.isHidden = false
        } else {
            self.typeLabel.isHidden = true
        }

        changeFavoritedStatus(isFavorited: item.isFavorited)
    }

    func changeFavoritedStatus(isFavorited: Bool) {
        let symbolName = isFavorited ? "heart.fill" : "heart"
        favoritedButton.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        favoritedButton.contentTintColor = .mainColor
    }

    // MARK: Init

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // poster container
        posterContainer.addSubview(imgView)
        posterContainer.addSubview(ratingBadge)
        imgView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        posterContainer.snp.makeConstraints { make in
            make.height.equalTo(posterContainer.snp.width).multipliedBy(1.4)
        }
        ratingBadge.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(4)
            make.bottom.equalToSuperview().offset(-4)
        }

        // top row
        topRowStack.addArrangedSubview(titleLabel)
        topRowStack.addArrangedSubview(favoritedButton)

        // info stack
        infoStackView.addArrangedSubview(topRowStack)
        infoStackView.addArrangedSubview(isOnAirLabel)
        infoStackView.addArrangedSubview(typeLabel)

        // root stack
        let rootStack = NSStackView(views: [posterContainer, infoStackView])
        rootStack.orientation = .vertical
        rootStack.spacing = 8
        rootStack.alignment = .leading

        view.addSubview(rootStack)

        rootStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        favoritedButton.addTarget(self, action: #selector(onTouchLikeButton(_:)))
    }

    // MARK: Actions

    @objc private func onTouchLikeButton(_ sender: Button) {
        let isFavorited = self.item?.isFavorited == true
        let newState = !isFavorited
        if let animeId = self.item?.animeId {
            self.onFavoriteToggle?(animeId, newState)
        }
        changeFavoritedStatus(isFavorited: newState)
    }
}
