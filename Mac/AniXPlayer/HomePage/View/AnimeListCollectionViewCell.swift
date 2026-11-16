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

    static let posterAspectRatio: CGFloat = 1.4

    /// 与下方 Auto Layout 约束使用同一套尺寸，避免布局高度和实际内容不一致。
    static func estimatedHeight(
        for item: AnimeListItem,
        width: CGFloat,
        titleLineLimit: Int = 2
    ) -> CGFloat {
        let titleHeight: CGFloat
        if titleLineLimit == 1 {
            titleHeight = 18
        } else {
            let titleWidth = max(1, width - 26)
            titleHeight = item.animeTitle.boundingRect(
                with: NSSize(width: titleWidth, height: 40),
                options: .usesLineFragmentOrigin,
                attributes: [.font: NSFont.ddp_normal()]
            ).height.rounded(.up)
        }
        let typeHeight: CGFloat = item.typeDescription.isEmpty ? 0 : 20
        return width * posterAspectRatio + 8 + max(titleHeight, 18) + 4 + 16 + typeHeight
    }

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
        // 海报统一填满固定比例的格子，避免不同尺寸的源图让网格看起来大小不一。
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
        label.alignment = .left
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 2
        label.cell?.wraps = true
        label.cell?.isScrollable = false
        label.cell?.truncatesLastVisibleLine = true
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    lazy var favoritedButton: Button = {
        let btn = Button()
        btn.bezelStyle = .inline
        btn.isBordered = false
        btn.imagePosition = .imageOnly
        btn.setContentHuggingPriority(.required, for: .horizontal)
        btn.setContentCompressionResistancePriority(.required, for: .horizontal)
        return btn
    }()

    lazy var isOnAirLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .ddp_small()
        label.alignment = .left
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

    private lazy var topRowView = NSView()

    var item: AnimeListItem?

    var onFavoriteToggle: ((Int, Bool) -> Void)?

    func setTitleLineLimit(_ lineLimit: Int) {
        let lines = max(1, lineLimit)
        titleLabel.maximumNumberOfLines = lines
        titleLabel.cell?.wraps = lines > 1
        titleLabel.cell?.isScrollable = false
        titleLabel.cell?.usesSingleLineMode = lines == 1
        titleLabel.cell?.truncatesLastVisibleLine = true
    }

    // MARK: Update

    func update(item: AnimeListItem, ratingNumberFormatter: NumberFormatter) {
        self.item = item

        if !item.imageUrl.isEmpty {
            self.imgView.kf.setImage(with: URL(string: item.imageUrl))
        }

        self.titleLabel.text = item.animeTitle
        self.titleLabel.toolTip = item.animeTitle

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
        let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        favoritedButton.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
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
            make.height.equalTo(posterContainer.snp.width).multipliedBy(Self.posterAspectRatio)
        }
        ratingBadge.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(4)
            make.bottom.equalToSuperview().offset(-4)
        }

        // top row：使用明确约束，不让 StackView 按标题长短改变文字和按钮的位置。
        topRowView.addSubview(titleLabel)
        topRowView.addSubview(favoritedButton)
        titleLabel.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.trailing.equalTo(favoritedButton.snp.leading).offset(-8)
        }
        favoritedButton.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.width.height.equalTo(18)
        }

        // info stack
        infoStackView.addArrangedSubview(topRowView)
        infoStackView.addArrangedSubview(isOnAirLabel)
        infoStackView.addArrangedSubview(typeLabel)
        topRowView.snp.makeConstraints { make in
            make.width.equalTo(infoStackView)
        }
        isOnAirLabel.snp.makeConstraints { make in
            make.width.equalTo(infoStackView)
        }

        // 海报和信息区直接撑满格子，避免嵌套 StackView 的 hugging 影响横向对齐。
        view.addSubview(posterContainer)
        view.addSubview(infoStackView)
        posterContainer.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        infoStackView.snp.makeConstraints { make in
            make.top.equalTo(posterContainer.snp.bottom).offset(8)
            make.leading.trailing.bottom.equalToSuperview()
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
