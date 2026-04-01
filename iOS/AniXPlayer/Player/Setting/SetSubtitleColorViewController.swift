//
//  SetSubtitleColorViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/4/1.
//

import UIKit
import Colorful

class SetSubtitleColorViewController: ViewController {

    private let mediaModel: PlayerMediaModel
    
    var dismissCallBack: (() -> Void)?

    init(mediaModel: PlayerMediaModel) {
        self.mediaModel = mediaModel
        super.init(nibName: nil, bundle: nil)
    }
    
    deinit {
        self.dismissCallBack?()
    }

    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private lazy var colorPicker: ColorPicker = {
        let picker = ColorPicker()
        picker.addTarget(self, action: #selector(onColorPickChange(_:)), for: .valueChanged)
        if let color = Preferences.shared.subtitleColor {
            picker.set(color: color, colorSpace: .sRGB)
        } else {
            picker.set(color: .white, colorSpace: .sRGB)
        }
        return picker
    }()

    private lazy var colorPreview: UIView = {
        let view = UIView()
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.white.cgColor
        view.backgroundColor = Preferences.shared.subtitleColor ?? .white
        view.layer.cornerRadius = 4
        return view
    }()

    private lazy var colorPreviewTitleLabel: Label = {
        let label = Label()
        label.text = NSLocalizedString("颜色预览：", comment: "")
        return label
    }()

    private lazy var resetButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(NSLocalizedString("恢复默认", comment: ""), for: .normal)
        button.setTitleColor(.navigationTitleColor, for: .normal)
        button.addTarget(self, action: #selector(onTouchResetButton(_:)), for: .touchUpInside)
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("字幕颜色", comment: "")

        let closeButton = UIBarButtonItem(title: NSLocalizedString("关闭", comment: ""), style: .plain, target: self, action: #selector(onTouchCloseButton(_:)))
        self.navigationItem.rightBarButtonItem = closeButton

        self.view.addSubview(self.colorPreviewTitleLabel)
        self.view.addSubview(self.colorPreview)
        self.view.addSubview(self.colorPicker)
        self.view.addSubview(self.resetButton)

        self.colorPreviewTitleLabel.snp.makeConstraints { make in
            make.top.leading.equalTo(self.view.safeAreaLayoutGuide).offset(20)
        }

        self.colorPreview.snp.makeConstraints { make in
            make.leading.equalTo(self.colorPreviewTitleLabel.snp.trailing).offset(8)
            make.centerY.equalTo(self.colorPreviewTitleLabel)
            make.width.height.equalTo(40)
        }

        self.resetButton.snp.makeConstraints { make in
            make.trailing.equalTo(self.view.safeAreaLayoutGuide).offset(-20)
            make.centerY.equalTo(self.colorPreviewTitleLabel)
        }

        self.colorPicker.snp.makeConstraints { make in
            make.leading.equalTo(self.colorPreviewTitleLabel)
            make.top.equalTo(self.colorPreviewTitleLabel.snp.bottom).offset(20)
            make.trailing.equalTo(self.view.safeAreaLayoutGuide).offset(-20)
            make.height.equalToSuperview().multipliedBy(0.5)
        }
    }

    @objc private func onTouchCloseButton(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true)
    }

    @objc private func onColorPickChange(_ picker: ColorPicker) {
        self.colorPreview.backgroundColor = picker.color
        self.mediaModel.onChangeSubtitleColor(picker.color)
    }

    @objc private func onTouchResetButton(_ button: UIButton) {
        self.mediaModel.onChangeSubtitleColor(nil)
        self.colorPreview.backgroundColor = .white
        self.dismiss(animated: true)
    }
}
