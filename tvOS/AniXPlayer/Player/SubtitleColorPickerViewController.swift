//
//  SubtitleColorPickerViewController.swift
//  AniXPlayer
//
//  tvOS 字幕颜色选择器 — 包装 ColorPickerView 用于 navigation push
//

import UIKit
import SnapKit

class SubtitleColorPickerViewController: ViewController {

    /// 可选颜色列表
    var colors: [ANXColor] {
        get { colorPickerView.colors }
        set { colorPickerView.colors = newValue }
    }

    /// 当前选中颜色，nil 表示"默认"
    var selectedColor: ANXColor? {
        get { colorPickerView.selectedColor }
        set { colorPickerView.selectedColor = newValue }
    }

    /// 是否允许选择 nil（默认/重置）
    var allowsNilSelection: Bool {
        get { colorPickerView.allowsNilSelection }
        set { colorPickerView.allowsNilSelection = newValue }
    }

    /// 选中回调
    var onSelect: ((ANXColor?) -> Void)?

    private lazy var colorPickerView: ColorPickerView = {
        let view = ColorPickerView()
        view.onSelect = { [weak self] color in
            self?.onSelect?(color)
        }
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(colorPickerView)
        colorPickerView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(40)
            make.leading.trailing.equalToSuperview().inset(60)
            make.bottom.lessThanOrEqualToSuperview()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        defaultFocusView = colorPickerView
    }
}
