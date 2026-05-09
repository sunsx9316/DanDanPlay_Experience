//
//  ColorManagementViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/5/10.
//

import UIKit
import SnapKit
import Colorful

// MARK: - ColorCell

private class ColorCell: UICollectionViewCell {

    private lazy var colorView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 4
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
        return view
    }()

    private lazy var checkmarkLabel: UILabel = {
        let label = UILabel()
        label.text = "✓"
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = UIColor(white: 0, alpha: 0.5)
        label.layer.cornerRadius = 7
        label.clipsToBounds = true
        label.isHidden = true
        return label
    }()

    var showCheckmark: Bool = false {
        didSet {
            if showCheckmark {
                colorView.layer.borderWidth = 2
                colorView.layer.borderColor = UIColor.white.cgColor
                checkmarkLabel.isHidden = false
            } else {
                colorView.layer.borderWidth = 1
                colorView.layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
                checkmarkLabel.isHidden = true
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(colorView)
        contentView.addSubview(checkmarkLabel)
        colorView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(4)
        }
        checkmarkLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(2)
            make.bottom.equalToSuperview().offset(2)
            make.width.height.equalTo(14)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setColor(_ color: UIColor) {
        colorView.backgroundColor = color
    }
}

// MARK: - AddColorCell

private class AddColorCell: UICollectionViewCell {

    private lazy var label: UILabel = {
        let label = UILabel()
        label.text = "+"
        label.font = .systemFont(ofSize: 22, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 4
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
        contentView.addSubview(label)
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - ColorManagementViewController

class ColorManagementViewController: ViewController {

    private static let maxColorCount = 10

    var onSave: (([ColorItem]) -> Void)?

    private var items: [ColorItem]

    private weak var selectedItem: ColorItem?

    private lazy var collectionView: CollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 36, height: 36)
        layout.minimumLineSpacing = 6
        layout.sectionInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        let collectionView = CollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.registerClassCell(class: ColorCell.self)
        collectionView.registerClassCell(class: AddColorCell.self)
        collectionView.showsVerticalScrollIndicator = false
        return collectionView
    }()

    private lazy var colorPicker: ColorPicker = {
        let picker = ColorPicker()
        picker.addTarget(self, action: #selector(onColorPickChange(_:)), for: .valueChanged)
        return picker
    }()

    private lazy var dismissItem: UIBarButtonItem = {
        let item = UIBarButtonItem(title: NSLocalizedString("取消", comment: ""),
                                   style: .plain,
                                   target: self,
                                   action: #selector(onTouchDismiss(_:)))
        item.setTitleTextAttributes([.font: UIFont.ddp_large,
                                     .foregroundColor: UIColor.navigationTitleColor], for: .normal)
        return item
    }()

    init(items: [ColorItem], selectedItem: ColorItem? = nil) {
        self.items = items
        self.selectedItem = selectedItem
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = UIColor(white: 0.15, alpha: 1)
        self.title = NSLocalizedString("弹幕颜色管理", comment: "")

        let deleteItem = UIBarButtonItem(title: "-",
                                         style: .plain,
                                         target: self,
                                         action: #selector(onTouchDelete(_:)))
        deleteItem.setTitleTextAttributes([.font: UIFont.ddp_large,
                                           .foregroundColor: UIColor.navigationTitleColor], for: .normal)

        let resetItem = UIBarButtonItem(title: NSLocalizedString("恢复默认", comment: ""),
                                         style: .plain,
                                         target: self,
                                         action: #selector(onTouchReset(_:)))
        resetItem.setTitleTextAttributes([.font: UIFont.ddp_large,
                                           .foregroundColor: UIColor.navigationTitleColor], for: .normal)

        let saveItem = UIBarButtonItem(title: NSLocalizedString("保存", comment: ""),
                                        style: .plain,
                                        target: self,
                                        action: #selector(onTouchSave(_:)))
        saveItem.setTitleTextAttributes([.font: UIFont.ddp_large,
                                          .foregroundColor: UIColor.navigationTitleColor], for: .normal)

        self.navigationItem.leftBarButtonItem = self.dismissItem
        self.navigationItem.rightBarButtonItems = [saveItem, resetItem, deleteItem]

        self.view.addSubview(collectionView)
        self.view.addSubview(colorPicker)

        collectionView.snp.makeConstraints { make in
            make.top.bottom.equalTo(self.view.safeAreaLayoutGuide)
            make.leading.equalTo(self.view.safeAreaLayoutGuide).offset(8)
            make.width.equalTo(52)
        }

        colorPicker.snp.makeConstraints { make in
            make.top.bottom.equalTo(self.view.safeAreaLayoutGuide)
            make.leading.equalTo(collectionView.snp.trailing).offset(8)
            make.trailing.equalTo(self.view.safeAreaLayoutGuide).offset(-8)
        }

        if let item = selectedItem ?? items.first {
            selectItem(item)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.navigationItem.leftBarButtonItem = self.dismissItem
    }

    // MARK: - Private

    private func selectItem(_ item: ColorItem) {
        selectedItem = item
        colorPicker.set(color: item.color, colorSpace: .sRGB)
        collectionView.reloadData()
    }

    // MARK: - Actions

    @objc private func onTouchDismiss(_ item: UIBarButtonItem) {
        dismiss(animated: true)
    }

    @objc private func onColorPickChange(_ picker: ColorPicker) {
        selectedItem?.color = picker.color
        collectionView.reloadData()
    }

    @objc private func onTouchDelete(_ item: UIBarButtonItem) {
        guard let selectedItem = selectedItem, items.count > 1 else { return }
        items.removeAll { $0 === selectedItem }
        if let first = items.first {
            selectItem(first)
        }
    }

    @objc private func onTouchReset(_ item: UIBarButtonItem) {
        items = Preferences.defaultSendDanmakuColors.map { ColorItem(color: $0) }
        if let first = items.first {
            selectItem(first)
        }
    }

    @objc private func onTouchSave(_ item: UIBarButtonItem) {
        onSave?(items)
        dismiss(animated: true)
    }
}

// MARK: - UICollectionViewDelegate, UICollectionViewDataSource
extension ColorManagementViewController: UICollectionViewDelegate, UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if items.count < Self.maxColorCount {
            return items.count + 1
        }
        return items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.item < items.count {
            let cell = collectionView.dequeueCell(class: ColorCell.self, indexPath: indexPath)
            let item = items[indexPath.item]
            cell.setColor(item.color)
            cell.showCheckmark = item === self.selectedItem
            return cell
        } else {
            return collectionView.dequeueCell(class: AddColorCell.self, indexPath: indexPath)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.item < items.count {
            selectItem(items[indexPath.item])
        } else if items.count < Self.maxColorCount {
            let newItem = ColorItem(color: ANXColor(anxRgb: 0xFFFFFF))
            items.append(newItem)
            selectItem(newItem)
        }
    }
}
