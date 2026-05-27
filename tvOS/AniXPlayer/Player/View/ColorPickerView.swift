//
//  ColorPickerView.swift
//  AniXPlayer
//
//  tvOS 通用颜色选择器 View
//  弹幕颜色 / 字幕颜色 共用
//

import UIKit
import SnapKit

class ColorPickerView: UIView {

    // MARK: - Configuration

    var colors: [ANXColor] = [] {
        didSet { reloadData() }
    }

    var selectedColor: ANXColor? {
        didSet { collectionView.reloadData() }
    }

    var allowsNilSelection: Bool = false {
        didSet { reloadData() }
    }

    var itemSize: CGFloat = 48 {
        didSet {
            (collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.itemSize = CGSize(width: itemSize, height: itemSize)
        }
    }

    var spacing: CGFloat = 16 {
        didSet {
            if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
                layout.minimumInteritemSpacing = spacing
                layout.minimumLineSpacing = spacing
            }
        }
    }

    var onSelect: ((ANXColor?) -> Void)?

    // MARK: - UI

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: itemSize, height: itemSize)
        layout.minimumInteritemSpacing = spacing
        layout.minimumLineSpacing = spacing

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.clipsToBounds = false
        cv.delegate = self
        cv.dataSource = self
        cv.register(MainColorCell.self, forCellWithReuseIdentifier: MainColorCell.reuseIdentifier)
        return cv
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    // MARK: - Focus

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        return [collectionView]
    }

    // MARK: - Layout

    override var intrinsicContentSize: CGSize {
        let count = colorValues.count
        guard count > 0 else { return .zero }

        let width = bounds.width > 0 ? bounds.width : CGFloat(count) * itemSize + CGFloat(count - 1) * spacing
        let perRow = max(1, Int((width + spacing) / (itemSize + spacing)))
        let rows = (count + perRow - 1) / perRow
        let height = CGFloat(rows) * itemSize + CGFloat(max(0, rows - 1)) * spacing

        return CGSize(width: width, height: height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        invalidateIntrinsicContentSize()
    }

    // MARK: - Private

    private func reloadData() {
        collectionView.reloadData()
        invalidateIntrinsicContentSize()
    }

    private var colorValues: [ANXColor?] {
        if allowsNilSelection {
            return [nil] + colors.map { Optional($0) }
        }
        return colors.map { Optional($0) }
    }

    private func isSelectedColor(_ color: ANXColor?) -> Bool {
        switch (color, selectedColor) {
        case (nil, nil): return true
        case (nil, _), (_, nil): return false
        case let (c?, s?): return c.anxRgbValue == s.anxRgbValue
        }
    }
}

// MARK: - UICollectionViewDataSource

extension ColorPickerView: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return colorValues.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MainColorCell.reuseIdentifier, for: indexPath) as! MainColorCell
        let color = colorValues[indexPath.item]
        cell.configure(with: color ?? .white, isSelected: isSelectedColor(color), isDefault: color == nil)
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension ColorPickerView: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let color = colorValues[indexPath.item]
        selectedColor = color
        onSelect?(color)
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension ColorPickerView: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let isDefaultCell = allowsNilSelection && indexPath.item == 0
        if isDefaultCell {
            return CGSize(width: 80, height: itemSize)
        }
        return CGSize(width: itemSize, height: itemSize)
    }
}
