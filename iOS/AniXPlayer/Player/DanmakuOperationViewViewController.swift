//
//  DanmakuOperationViewViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/8/17.
//

import UIKit
import SnapKit

class DanmakuOperationViewViewController: ViewController {
    
    private lazy var copyButton: Button = {
        var copyButton = Button()
        copyButton.titleLabel?.font = .ddp_normal
        copyButton.setTitle(NSLocalizedString("复制", comment: ""), for: .normal)
        copyButton.setTitleColor(.textColor, for: .normal)
        copyButton.addTarget(self, action: #selector(didTouchCopyButton), for: .touchUpInside)
        return copyButton
    }()
    
    private lazy var filterButton: Button = {
        var filterButton = Button()
        filterButton.titleLabel?.font = .ddp_normal
        filterButton.setTitle(NSLocalizedString("屏蔽", comment: ""), for: .normal)
        filterButton.setTitleColor(.textColor, for: .normal)
        filterButton.addTarget(self, action: #selector(didTouchFilterButton), for: .touchUpInside)
        return filterButton
    }()
    
    var onTouchCopyButtonCallBack: ((DanmakuOperationViewViewController) -> Void)?
    var onTouchFilterButtonCallBack: ((DanmakuOperationViewViewController) -> Void)?
    var dismissCallBack: ((DanmakuOperationViewViewController) -> Void)?
    
    deinit {
        self.dismissCallBack?(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        

        self.view.addSubview(self.copyButton)
        self.view.addSubview(self.filterButton)
        
        self.copyButton.snp.makeConstraints { make in
            make.top.equalTo(8)
            make.leading.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        
        self.filterButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.top.equalTo(self.copyButton)
            make.bottom.equalToSuperview()
            make.leading.equalTo(self.copyButton.snp.trailing)
            make.width.equalTo(self.copyButton)
        }
    }
    
    @objc private func didTouchCopyButton() {
        self.onTouchCopyButtonCallBack?(self)
    }

    @objc private func didTouchFilterButton() {
        self.onTouchFilterButtonCallBack?(self)
    }

}
