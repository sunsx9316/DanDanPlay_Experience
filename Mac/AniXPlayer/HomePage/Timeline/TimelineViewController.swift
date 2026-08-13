//
//  TimelineViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/29.
//

import Cocoa
import SnapKit

/// 新番时间表壳 VC：segmentBar 切 tab，内嵌 7 个 TimelineDayViewController
class TimelineViewController: ViewController {
 
    var refreshDataCallBack: (() -> Void)?

    var dataSource: [BangumiIntro]? {
        didSet {
            guard let dataSource = self.dataSource else { return }
            buildDays(from: dataSource)
        }
    }

    // MARK: - Tabs

    private var weekdays: [Int] = []
    private var dayVCs: [Int: TimelineDayViewController] = [:]
    private var selectedDay: Int = 0 {
        didSet { showDay(selectedDay) }
    }

    private lazy var segmentBar: TimelineSegmentBar = {
        let bar = TimelineSegmentBar()
        bar.onSelected = { [weak self] index in
            guard let self = self, index < self.weekdays.count else { return }
            self.segmentBar.selectedIndex = index
            self.selectedDay = self.weekdays[index]
        }
        return bar
    }()

    private lazy var containerView: NSView = {
        let v = NSView()
        return v
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("新番时间表", comment: "")

        view.addSubview(segmentBar)
        view.addSubview(containerView)

        segmentBar.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(40)
        }
        containerView.snp.makeConstraints { make in
            make.top.equalTo(segmentBar.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    // MARK: - Build

    private func buildDays(from items: [BangumiIntro]) {
        var daySet = Set<Int>()
        for info in items { daySet.insert(info.airDay) }
        let sortedDays = daySet.sorted()
        weekdays = sortedDays

        segmentBar.titles = sortedDays.map { $0 == 0 ? "周日" : "周" + NumberUtils.numberToChinese($0) }

        // 移除旧子 VC
        for (_, vc) in dayVCs {
            vc.view.removeFromSuperview()
            vc.removeFromParent()
        }
        dayVCs.removeAll()

        // 按天分组
        var dayMap: [Int: [BangumiIntro]] = [:]
        for info in items {
            dayMap[info.airDay, default: []].append(info)
        }

        // 为每天创建子 VC
        for day in sortedDays {
            let vc = TimelineDayViewController()
            vc.items = dayMap[day] ?? []
            vc.onFavoriteToggle = { [weak self] animeId, isLike in
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

            addChild(vc)
            containerView.addSubview(vc.view)
            vc.view.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            vc.view.isHidden = true

            dayVCs[day] = vc
        }

        // 默认选中今天
        let today = Calendar.current.component(.weekday, from: Date()) - 1
        let index = sortedDays.firstIndex(of: today) ?? 0
        segmentBar.selectedIndex = index
        selectedDay = sortedDays.isEmpty ? 0 : sortedDays[index]
    }

    private func showDay(_ day: Int) {
        for (d, vc) in dayVCs {
            vc.view.isHidden = (d != day)
        }
    }
}
