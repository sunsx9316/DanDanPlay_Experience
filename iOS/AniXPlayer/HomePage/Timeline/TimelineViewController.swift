//
//  TimelineViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/7.
//

import UIKit
import SnapKit

extension TimelineViewController: UIPageViewControllerDataSource {

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let vc = viewController as? TimelineItemViewController,
              let index = childVCs.firstIndex(of: vc),
              index > 0 else { return nil }
        return childVCs[index - 1]
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let vc = viewController as? TimelineItemViewController,
              let index = childVCs.firstIndex(of: vc),
              index < childVCs.count - 1 else { return nil }
        return childVCs[index + 1]
    }
}

extension TimelineViewController: UIPageViewControllerDelegate {

    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard completed,
              let vc = pageViewController.viewControllers?.first as? TimelineItemViewController,
              let index = childVCs.firstIndex(of: vc) else { return }
        segmentBar.selectedIndex = index
    }
}

class TimelineViewController: ViewController {

    private lazy var pageDataSourceIndex = [Int]()

    private lazy var pageDataSource: [Int: [BangumiIntro]] = [:]

    private var childVCs: [TimelineItemViewController] = []

    private lazy var segmentBar: TimelineSegmentBar = {
        let bar = TimelineSegmentBar()
        bar.onSelected = { [weak self] index in
            self?.scrollToPage(index)
        }
        return bar
    }()

    private lazy var pageViewController: UIPageViewController = {
        let pvc = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        pvc.dataSource = self
        pvc.delegate = self
        return pvc
    }()

    var refreshDataCallBack: (() -> Void)?

    var dataSource: [BangumiIntro]? {
        didSet {
            guard let dataSource = self.dataSource else { return }

            var pageDataSource = [Int: [BangumiIntro]]()

            for info in dataSource {
                if pageDataSource[info.airDay] == nil {
                    pageDataSource[info.airDay] = [BangumiIntro]()
                }
                pageDataSource[info.airDay]?.append(info)
            }

            self.pageDataSourceIndex = pageDataSource.keys.sorted()

            let titles = self.pageDataSourceIndex.compactMap { day -> String in
                switch day {
                case 0: return "周日"
                default: return "周" + NumberUtils.numberToChinese(day)
                }
            }

            self.pageDataSource = pageDataSource
            self.segmentBar.titles = titles

            // 重建子 VC 列表
            self.childVCs = self.pageDataSourceIndex.map { day in
                let vc = TimelineItemViewController(scrollDirection: .vertical, dataSources: pageDataSource[day])
                vc.refreshDataCallBack = { [weak self] in
                    self?.refreshDataCallBack?()
                }
                return vc
            }

            // 定位到今天
            let weekDay = NSDate().weekday - 1
            let index = self.pageDataSourceIndex.firstIndex(of: weekDay) ?? 0
            self.segmentBar.selectedIndex = index
            if !self.childVCs.isEmpty {
                self.pageViewController.setViewControllers([self.childVCs[index]], direction: .forward, animated: false)
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("新番时间表", comment: "")

        addChild(pageViewController)
        view.addSubview(segmentBar)
        view.addSubview(pageViewController.view)
        pageViewController.didMove(toParent: self)

        segmentBar.snp.makeConstraints { make in
            make.top.equalTo(self.view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(40)
        }

        pageViewController.view.snp.makeConstraints { make in
            make.top.equalTo(segmentBar.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    // MARK: - Private

    private func scrollToPage(_ index: Int) {
        guard index < childVCs.count, segmentBar.selectedIndex != index else { return }
        let direction: UIPageViewController.NavigationDirection = index > segmentBar.selectedIndex ? .forward : .reverse
        pageViewController.setViewControllers([childVCs[index]], direction: direction, animated: true)
        segmentBar.selectedIndex = index
    }
}
