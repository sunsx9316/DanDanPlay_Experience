//
//  TimelineViewController.swift
//  AniXPlayer
//
//  tvOS 新番时间表 — 左侧星期 Tab + 右侧瀑布流
//

import UIKit
import SnapKit

class TimelineViewController: ViewController {

    private var groupedData: [Int: [BangumiIntro]] = [:]
    private var selectedDay: Int = 0 {
        didSet {
            updateTabAppearance()
            collectionView.reloadData()
            collectionView.setContentOffset(CGPoint(x: 0, y: -collectionView.adjustedContentInset.top), animated: false)
            // reloadData 后焦点可能漂移，拉回到选中 tab
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.selectedDay < self.tabButtons.count else { return }
                self.setNeedsFocusUpdate()
                self.updateFocusIfNeeded()
            }
        }
    }

    private var currentItems: [BangumiIntro] {
        return groupedData[selectedDay] ?? []
    }

    private let weekdays: [(String, String)] = [
        ("日", NSLocalizedString("周日", comment: "")),
        ("一", NSLocalizedString("周一", comment: "")),
        ("二", NSLocalizedString("周二", comment: "")),
        ("三", NSLocalizedString("周三", comment: "")),
        ("四", NSLocalizedString("周四", comment: "")),
        ("五", NSLocalizedString("周五", comment: "")),
        ("六", NSLocalizedString("周六", comment: "")),
    ]

    // MARK: - Rating

    private lazy var ratingNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.roundingMode = .halfEven
        return formatter
    }()

    // MARK: - Sidebar

    private lazy var sidebarView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.adaptiveBackground.withAlphaComponent(0.95)
        return view
    }()

    private lazy var tabStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4
        stack.distribution = .fillEqually
        stack.alignment = .fill
        return stack
    }()

    private var tabButtons: [Button] = []

    // MARK: - CollectionView

    private lazy var waterfallLayout: WaterfallLayout = {
        let layout = WaterfallLayout()
        layout.columnCount = 3
        layout.sectionInset = UIEdgeInsets(top: 0, left: 30, bottom: 60, right: 60)
        layout.itemPadding = 40
        layout.delegate = self
        return layout
    }()

    private lazy var collectionView: CollectionView = {
        let cv = CollectionView(frame: .zero, collectionViewLayout: waterfallLayout)
        cv.delegate = self
        cv.dataSource = self
        cv.registerClassCell(class: TimelineItemCollectionViewCell.self)
        return cv
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = NSLocalizedString("新番时间表", comment: "")

        view.addSubview(sidebarView)
        view.addSubview(collectionView)
        sidebarView.addSubview(tabStack)

        sidebarView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(8)
            make.leading.equalToSuperview().offset(60)
            make.bottom.equalToSuperview().offset(-20)
            make.width.equalTo(100)
        }

        tabStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(8)
        }

        collectionView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.equalTo(sidebarView.snp.trailing).offset(30)
            make.trailing.equalToSuperview().offset(-60)
        }

        setupTabs()
        loadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        if selectedDay < tabButtons.count {
            return [tabButtons[selectedDay], collectionView]
        }
        return [tabStack, collectionView]
    }

    // MARK: - Tabs

    private func setupTabs() {
        for (index, weekday) in weekdays.enumerated() {
            let btn = Button()
            btn.setTitle(weekday.0, for: .normal)
            btn.titleLabel?.font = .ddp_large(weight: .medium)
            btn.contentEdgeInsets = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
            btn.layer.cornerRadius = 8
            btn.layer.masksToBounds = true
            btn.tag = index
            btn.addTarget(self, action: #selector(tabTapped(_:)), for: .primaryActionTriggered)
            tabStack.addArrangedSubview(btn)
            tabButtons.append(btn)
        }
        updateTabAppearance()
    }

    @objc private func tabTapped(_ sender: Button) {
        selectedDay = sender.tag
    }

    private func updateTabAppearance() {
        for (index, btn) in tabButtons.enumerated() {
            if index == selectedDay {
                btn.setTitleColor(.adaptiveText, for: .normal)
                btn.backgroundColor = UIColor.mainColor.withAlphaComponent(0.25)
                btn.titleLabel?.font = .ddp_large(weight: .bold)
            } else {
                btn.setTitleColor(.secondaryLabel, for: .normal)
                btn.backgroundColor = .clear
                btn.titleLabel?.font = .ddp_large(weight: .medium)
            }
        }
    }

    // MARK: - Data

    private func loadData() {
        HomePageNetworkHandle.homePage() { [weak self] homepage, error in
            guard let self = self else { return }
            if let list = homepage?.shinBangumiList {
                self.groupData(list)
                DispatchQueue.main.async {
                    self.collectionView.reloadData()
                }
            }
        }
    }

    private func groupData(_ list: [BangumiIntro]) {
        groupedData.removeAll()
        for item in list {
            groupedData[item.airDay, default: []].append(item)
        }
    }
}

// MARK: - UICollectionViewDataSource

extension TimelineViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return currentItems.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueCell(class: TimelineItemCollectionViewCell.self, indexPath: indexPath)
        cell.update(item: currentItems[indexPath.item], ratingNumberFormatter: ratingNumberFormatter)
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension TimelineViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = currentItems[indexPath.item]
        let vc = BangumiDetailViewController(animateId: item.animeId)
        self.navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - WaterfallLayoutDelegate

extension TimelineViewController: WaterfallLayoutDelegate {

    func waterfallLayout(_ layout: WaterfallLayout, heightForItemAt indexPath: IndexPath, itemWidth: CGFloat) -> CGFloat {
        guard indexPath.item < currentItems.count else { return itemWidth * 0.65 }
        return AnimeListCollectionViewCell.estimatedHeight(for: currentItems[indexPath.item], width: itemWidth)
    }
}
