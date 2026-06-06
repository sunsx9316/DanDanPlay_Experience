//
//  HomePageBannerCell.swift
//  AniXPlayer
//
//  tvOS 首页 Banner — 水平滚动横幅 + 自动轮播
//

import UIKit
import SnapKit
import Kingfisher

class HomePageBannerCell: TableViewCell {

    static let reuseIdentifier = "HomePageBannerCell"

    var banners: [BannerPageItem] = [] {
        didSet {
            collectionView.reloadData()
            pageControl.numberOfPages = banners.count
            pageControl.isHidden = banners.count <= 1
            startAutoScrollIfNeeded()
        }
    }

    var onBannerSelected: ((BannerPageItem) -> Void)?

    private var autoScrollTimer: Timer?
    private var currentPage = 0

    override var canBecomeFocused: Bool { return false }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        return [collectionView]
    }

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.delegate = self
        cv.dataSource = self
        cv.registerClassCell(class: BannerItemCell.self)
        return cv
    }()

    private lazy var pageControl: UIPageControl = {
        let pc = UIPageControl()
        pc.currentPageIndicatorTintColor = .white
        pc.pageIndicatorTintColor = UIColor.white.withAlphaComponent(0.4)
        pc.isHidden = true
        return pc
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    deinit {
        autoScrollTimer?.invalidate()
    }

    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        selectionStyle = .none
        contentView.addSubview(collectionView)
        contentView.addSubview(pageControl)

        collectionView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(320)
        }

        pageControl.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }

    // MARK: - Auto Scroll

    private func startAutoScrollIfNeeded() {
        autoScrollTimer?.invalidate()
        guard banners.count > 1 else { return }
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.scrollToNextPage()
        }
    }

    private func scrollToNextPage() {
        guard banners.count > 1 else { return }
        let nextPage = (currentPage + 1) % banners.count
        let indexPath = IndexPath(item: nextPage, section: 0)
        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        currentPage = nextPage
        pageControl.currentPage = currentPage
    }
}

// MARK: - BannerItemCell

extension HomePageBannerCell {

    class BannerItemCell: CollectionViewCell {
        static let reuseIdentifier = "BannerItemCell"

        private lazy var imageView: UIImageView = {
            let iv = UIImageView()
            iv.contentMode = .scaleAspectFill
            iv.clipsToBounds = true
            iv.layer.cornerRadius = 12
            iv.adjustsImageWhenAncestorFocused = true
            return iv
        }()

        private lazy var titleLabel: UILabel = {
            let label = UILabel()
            label.font = .ddp_small(weight: .bold)
            label.textColor = .white
            label.numberOfLines = 2
            label.textAlignment = .left
            label.layer.shadowColor = UIColor.black.cgColor
            label.layer.shadowOffset = CGSize(width: 1, height: 1)
            label.layer.shadowOpacity = 0.8
            label.layer.shadowRadius = 3
            return label
        }()

        private lazy var descriptionLabel: UILabel = {
            let label = UILabel()
            label.font = .ddp_small()
            label.textColor = UIColor.white.withAlphaComponent(0.8)
            label.numberOfLines = 2
            label.textAlignment = .left
            label.layer.shadowColor = UIColor.black.cgColor
            label.layer.shadowOffset = CGSize(width: 1, height: 1)
            label.layer.shadowOpacity = 0.8
            label.layer.shadowRadius = 2
            return label
        }()

        override init(frame: CGRect) {
            super.init(frame: frame)
            contentView.addSubview(imageView)
            contentView.addSubview(titleLabel)
            contentView.addSubview(descriptionLabel)

            imageView.snp.makeConstraints { make in
                make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 60, bottom: 10, right: 60))
            }

            descriptionLabel.snp.makeConstraints { make in
                make.leading.equalTo(imageView).offset(20)
                make.trailing.equalTo(imageView).offset(-20)
                make.bottom.equalTo(imageView).offset(-20)
            }

            titleLabel.snp.makeConstraints { make in
                make.leading.equalTo(imageView).offset(20)
                make.trailing.equalTo(imageView).offset(-20)
                make.bottom.equalTo(descriptionLabel.snp.top).offset(-6)
            }
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
        }

        func configure(with banner: BannerPageItem) {
            titleLabel.text = banner.title
            descriptionLabel.text = banner.description
            descriptionLabel.isHidden = banner.description.isEmpty
            if let url = URL(string: banner.imageUrl) {
                imageView.kf.setImage(with: url, placeholder: UIImage.placeholder)
            }
        }
    }
}

// MARK: - UICollectionViewDataSource / Delegate

extension HomePageBannerCell: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return banners.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueCell(class: BannerItemCell.self, indexPath: indexPath)
        cell.configure(with: banners[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return collectionView.bounds.size
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        autoScrollTimer?.invalidate()
        onBannerSelected?(banners[indexPath.item])
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        currentPage = Int(round(scrollView.contentOffset.x / scrollView.bounds.width))
        pageControl.currentPage = currentPage
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        pageControl.currentPage = currentPage
    }
}
