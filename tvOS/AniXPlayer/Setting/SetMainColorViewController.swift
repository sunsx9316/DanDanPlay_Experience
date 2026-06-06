//
//  SetMainColorViewController.swift
//  AniXPlayer
//
//  tvOS 主题色选择 — 颜色网格 + 焦点导航
//

import UIKit
import SnapKit

class SetMainColorViewController: ViewController {

    private static let presetColors: [ANXColor] = [
        ANXColor(anxRgb: 0x14B409), // 默认绿
        ANXColor(anxRgb: 0xFF6B6B), // 红
        ANXColor(anxRgb: 0xFFA500), // 橙
        ANXColor(anxRgb: 0xFFD700), // 金
        ANXColor(anxRgb: 0x4ECDC4), // 青
        ANXColor(anxRgb: 0x45B7D1), // 蓝
        ANXColor(anxRgb: 0x96CEB4), // 浅绿
        ANXColor(anxRgb: 0xFFEAA7), // 浅黄
        ANXColor(anxRgb: 0xDDA0DD), // 紫
        ANXColor(anxRgb: 0xF78FB3), // 粉
        ANXColor(anxRgb: 0x3DC1D3), // 蓝绿
        ANXColor(anxRgb: 0xE66767), // 暗红
    ]

    private lazy var collectionView: CollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 100, height: 100)
        layout.minimumInteritemSpacing = 20
        layout.minimumLineSpacing = 20
        layout.sectionInset = UIEdgeInsets(top: 40, left: 60, bottom: 40, right: 60)

        let cv = CollectionView(frame: .zero, collectionViewLayout: layout)
        cv.delegate = self
        cv.dataSource = self
        cv.registerClassCell(class: MainColorCell.self)
        return cv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = NSLocalizedString("设置主题色", comment: "")

        self.view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // 标记当前选中的颜色
        let currentColor = Preferences.shared.mainColor
        if Self.presetColors.firstIndex(where: { $0.anxRgbValue == currentColor.anxRgbValue }) != nil {
            DispatchQueue.main.async {
                self.collectionView.reloadData()
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.defaultFocusView = collectionView
    }

    private func selectColor(_ color: ANXColor) {
        Preferences.shared.mainColor = color
        self.navigationController?.popViewController(animated: true)
    }
}

extension SetMainColorViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return Self.presetColors.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueCell(class: MainColorCell.self, indexPath: indexPath)
        let color = Self.presetColors[indexPath.item]
        let isSelected = color.anxRgbValue == Preferences.shared.mainColor.anxRgbValue
        cell.configure(with: color, isSelected: isSelected)
        return cell
    }
}

extension SetMainColorViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let color = Self.presetColors[indexPath.item]
        selectColor(color)
    }
}
