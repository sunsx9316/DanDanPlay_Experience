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
        self.mediaModel.onChangeSubtitleColor(self.pickColor)
        self.dismissCallBack?()
    }

    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private lazy var colorPicker: ColorPicker = {
        let picker = ColorPicker()
        picker.addTarget(self, action: #selector(onColorPickChange(_:)), for: .valueChanged)
        return picker
    }()

    private lazy var colorPreview: UIView = {
        let view = UIView()
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.white.cgColor
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
    
    private lazy var pickColor = Preferences.shared.subtitleColor

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("字幕颜色", comment: "")
        
        self.view.backgroundColor = .clear

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
        
        let pickColor = self.pickColor ?? .white
        self.colorPicker.set(color: pickColor, colorSpace: .sRGB)
        self.colorPreview.backgroundColor = pickColor
    }

    @objc private func onTouchCloseButton(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true)
    }

    @objc private func onColorPickChange(_ picker: ColorPicker) {
        self.colorPreview.backgroundColor = picker.color
        self.pickColor = picker.color
    }

    @objc private func onTouchResetButton(_ button: UIButton) {
        self.pickColor = nil
        self.colorPreview.backgroundColor = .white
        self.dismiss(animated: true)
    }
}
