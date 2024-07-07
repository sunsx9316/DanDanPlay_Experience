//
//  TimelineViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/7.
//

import UIKit
import SnapKit
import JXCategoryView

extension TimelineViewController: JXCategoryListContainerViewDelegate {
    func number(ofListsInlistContainerView listContainerView: JXCategoryListContainerView!) -> Int {
        return self.pageDataSourceIndex.count
    }
    
    func listContainerView(_ listContainerView: JXCategoryListContainerView!, initListFor index: Int) -> (any JXCategoryListContentViewDelegate)! {
        let day = self.pageDataSourceIndex[index]
        let vc = TimelineItemViewController(scrollDirection: .vertical, dataSources: self.pageDataSource[day])
        return vc
    }
}

class TimelineViewController: ViewController {
    
    private lazy var pageDataSourceIndex = [Int]()
    
    private lazy var pageDataSource: [Int: [BangumiIntro]] = {
        var dataSource = [Int: [BangumiIntro]]()
        return dataSource
    }()

    private lazy var pageView: JXCategoryListContainerView = {
        let pageView = JXCategoryListContainerView(type: .scrollView, delegate: self)!
        return pageView
    }()
    
    private lazy var titleView: JXCategoryTitleView = {
        let titleView = JXCategoryTitleView()
        titleView.isTitleColorGradientEnabled = true
        titleView.titleColor = .textColor
        titleView.titleSelectedColor = .mainColor
        titleView.isTitleLabelZoomEnabled = true
        titleView.titleFont = .ddp_normal
        
        let lineView = JXCategoryIndicatorLineView()
        lineView.indicatorColor = .mainColor
        lineView.indicatorWidth = JXCategoryViewAutomaticDimension
        titleView.indicators = [lineView]
        return titleView
    }()
    
    var dataSource: [BangumiIntro]? {
        didSet {
            if let dataSource = self.dataSource {
                var pageDataSource = [Int: [BangumiIntro]]()
                
                /// 分类
                for info in dataSource {
                    if pageDataSource[info.airDay] == nil {
                        pageDataSource[info.airDay] = [BangumiIntro]()
                    }
                    
                    pageDataSource[info.airDay]?.append(info)
                }
                
                self.pageDataSourceIndex = pageDataSource.keys.sorted { idx1, idx2 in
                    return idx1 < idx2
                }
                
                self.pageDataSource = pageDataSource
                reloadUI()
            }
        }
    }
    
    private func reloadUI() {
        self.titleView.titles = self.pageDataSourceIndex.compactMap({ day in
            switch day {
            case 0:
                return "周日"
            default:
                return "周" + NumberUtils.numberToChinese(day)
            }
        })
        
        /// 定位到今天
        let weekDay = NSDate().weekday - 1
        if let idx = self.pageDataSourceIndex.firstIndex(of: weekDay) {
            self.titleView.selectItem(at: idx)
        }
        
        self.titleView.reloadData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("新番时间表", comment: "")
        
        self.view.addSubview(self.titleView)
        self.view.addSubview(self.pageView)
        
        self.titleView.listContainer = self.pageView
        
        self.titleView.snp.makeConstraints { make in
            make.top.equalTo(self.view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(40)
        }
        
        self.pageView.snp.makeConstraints { make in
            make.top.equalTo(self.titleView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
  
}
