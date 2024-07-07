//
//  HomePageBannerTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/6.
//

import UIKit
import SnapKit
import FSPagerView

extension HomePageBannerTableViewCell: FSPagerViewDataSource {
    
    func numberOfItems(in pagerView: FSPagerView) -> Int {
        return self.banners?.count ?? 0
    }
    
    func pagerView(_ pagerView: FSPagerView, cellForItemAt index: Int) -> FSPagerViewCell {
        if let cell = pagerView.dequeueReusableCell(withReuseIdentifier: "HomePageBannerItemCell", at: index) as? HomePageBannerItemCell {
            cell.item = self.banners?[index]
            return cell
        }
        
        assert(false, "未匹配cell")
        return FSPagerViewCell()
    }
}

extension HomePageBannerTableViewCell: FSPagerViewDelegate {
    
    func pagerViewDidScroll(_ pagerView: FSPagerView) {
        if self.pageControl.currentPage != pagerView.currentIndex {
            self.pageControl.currentPage = pagerView.currentIndex
        }
    }
    
    func pagerView(_ pagerView: FSPagerView, didSelectItemAt index: Int) {
        if let item = self.banners?[index], let url = URL(string: item.url) {
            UIApplication.shared.open(url)
        }
    }
}

class HomePageBannerTableViewCell: TableViewCell {
    
    private lazy var pagerView: FSPagerView = {
        let pagerView = FSPagerView(frame: self.contentView.bounds)
        pagerView.dataSource = self
        pagerView.delegate = self
        pagerView.register(HomePageBannerItemCell.getNib(), forCellWithReuseIdentifier: "HomePageBannerItemCell")
        pagerView.isInfinite = true
        pagerView.automaticSlidingInterval = 8.0
        pagerView.transformer = FSPagerViewTransformer(type: .linear)
        return pagerView
    }()
    
    private lazy var pageControl: UIPageControl = {
        let pageControl = UIPageControl()
        pageControl.hidesForSinglePage = true
        pageControl.isUserInteractionEnabled = false
        return pageControl
    }()
    
    var banners: [BannerPageItem]? {
        didSet {
            self.pagerView.reloadData()
            self.pageControl.numberOfPages = self.banners?.count ?? 0
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupInit()
    }
    
    // MARK: Private
    
    private func setupInit() {
        self.contentView.addSubview(self.pagerView)
        self.contentView.addSubview(self.pageControl)
        
        self.pagerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        self.pageControl.snp.makeConstraints { make in
            make.bottom.equalTo(-0)
            make.centerX.equalToSuperview()
        }
    }
    
}
