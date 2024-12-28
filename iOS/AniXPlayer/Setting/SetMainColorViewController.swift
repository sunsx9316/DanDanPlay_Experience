//
//  SetMainColorViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/10/2.
//

import UIKit
import Colorful
import RxSwift

class SetMainColorViewController: ViewController {
    
    private lazy var pickColorView: ColorPicker = {
        var pickColorView = ColorPicker()
        pickColorView.addTarget(self, action: #selector(onColorPickChange(_:)), for: .valueChanged)
        if let color = self.model.mainColor {
            pickColorView.set(color: color, colorSpace: .sRGB)
        }
        return pickColorView
    }()

    
    private lazy var colorPreview: UIView = {
        let view = UIView()
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.white.cgColor
        view.backgroundColor = self.model.mainColor
        return view
    }()
    
    private lazy var colorPreviewTitleLabel: Label = {
        let label = Label()
        label.text = NSLocalizedString("颜色预览：", comment: "")
        return label
    }()
    
    private let model: GlobalSettingModel!
    
    private lazy var bag = DisposeBag()
    
    init(globalSettingModel: GlobalSettingModel) {
        self.model = globalSettingModel
        super.init(nibName: nil, bundle: nil)
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("设置主题色", comment: "")
        
        self.setupResetItem()
        
        self.view.addSubview(self.colorPreview)
        self.view.addSubview(self.colorPreviewTitleLabel)
        self.view.addSubview(self.pickColorView)
        
        self.colorPreviewTitleLabel.snp.makeConstraints { make in
            make.top.leading.equalTo(self.view.safeAreaLayoutGuide).offset(20)
        }
        
        self.colorPreview.snp.makeConstraints { make in
            make.leading.equalTo(self.colorPreviewTitleLabel.snp.trailing).offset(5)
            make.centerY.equalTo(self.colorPreviewTitleLabel)
            make.width.height.equalTo(40)
        }
        
        self.pickColorView.snp.makeConstraints { make in
            make.leading.equalTo(self.colorPreviewTitleLabel)
            make.top.equalTo(self.colorPreviewTitleLabel.snp.bottom).offset(5)
            make.trailing.equalTo(self.view.safeAreaLayoutGuide).offset(-20)
            make.height.equalToSuperview().multipliedBy(0.5)
        }
    }
    
    // MARK: Private Method
    private func setupResetItem() {
        let editItem = UIBarButtonItem(title: NSLocalizedString("恢复默认", comment: ""), target: self, action: #selector(onTouchResetItem(_:)))
        
        editItem.setTitleTextAttributes([.font : UIFont.ddp_large,
                                                   .foregroundColor : UIColor.navigationTitleColor], for: .normal)
        editItem.setTitleTextAttributes([.font : UIFont.ddp_large,
                                                   .foregroundColor : UIColor.black], for: .highlighted)
        
        let saveItem = UIBarButtonItem(title: NSLocalizedString("保存", comment: ""), target: self, action: #selector(onTouchSaveItem(_:)))
        
        saveItem.setTitleTextAttributes([.font : UIFont.ddp_large,
                                                   .foregroundColor : UIColor.navigationTitleColor], for: .normal)
        saveItem.setTitleTextAttributes([.font : UIFont.ddp_large,
                                                   .foregroundColor : UIColor.black], for: .highlighted)
        
        self.navigationItem.rightBarButtonItems = [editItem, saveItem]
    }
    
    @objc private func onTouchResetItem(_ item: UIBarButtonItem) {
        self.resetColor(UIColor.defaultMainColor)
        self.pickColorView.set(color: UIColor.defaultMainColor, colorSpace: .sRGB)
    }
    
    @objc private func onTouchSaveItem(_ item: UIBarButtonItem) {
        let vc = UIAlertController(title: NSLocalizedString("提示", comment: ""), message: NSLocalizedString("保存需要退出App，是否退出？", comment: ""), preferredStyle: .alert)

        vc.addAction(.init(title: NSLocalizedString("取消", comment: ""), style: .cancel, handler: { (_) in
            
        }))
        
        vc.addAction(.init(title: NSLocalizedString("确定", comment: ""), style: .destructive, handler: { (_) in
            self.model.onChangeMainColor(self.pickColorView.color)
            exit(0)
        }))
        self.present(vc, atItem: item)
    }
    
    private func resetColor(_ color: UIColor) {
        self.colorPreview.backgroundColor = color
    }
    
    @objc private func onColorPickChange(_ picker: ColorPicker) {
        self.resetColor(picker.color)
    }
}
