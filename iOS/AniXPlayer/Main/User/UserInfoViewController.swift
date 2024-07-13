//
//  UserInfoViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/13.
//

import UIKit
import SnapKit
import SVGKit
import SDWebImage

class UserInfoViewController: ViewController {
    
    // 滚动视图
    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        return scrollView
    }()
    
    // 用户头像
    private lazy var userAvatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = 50
        imageView.clipsToBounds = true
        imageView.layer.borderWidth = 2
        imageView.layer.borderColor = UIColor.mainColor.cgColor
        return imageView
    }()
    
    // 用户名
    private lazy var usernameLabel: UILabel = {
        let label = Label()
        label.text = "用户名"
        label.font = UIFont.systemFont(ofSize: 20)
        label.numberOfLines = 0
        return label
    }()
    
    // 会员过期时间
    private lazy var membershipExpiryLabel: UILabel = {
        let label = Label()
        label.font = UIFont.systemFont(ofSize: 16)
        return label
    }()
    
    // 资源监视器权益过期时间
    private lazy var resourceMonitorExpiryLabel: UILabel = {
        let label = Label()
        label.font = UIFont.systemFont(ofSize: 16)
        return label
    }()
    
    private lazy var logoutButton: UIButton = {
        let button = Button(type: .custom)
        button.backgroundColor = .mainColor
        button.setTitle(NSLocalizedString("退出登录", comment: ""), for: .normal)
        button.setBackgroundImage(UIImage(color: .mainColor), for: .normal)
        button.setBackgroundImage(UIImage(color: .mainColor.withAlphaComponent(0.6)), for: .normal)
        button.addTarget(self, action: #selector(logoutButtonTapped), for: .touchUpInside)
        button.layer.cornerRadius = 4
        button.layer.masksToBounds = true
        return button
    }()
    
    // 信息栈视图
    private lazy var infoStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .leading
        stackView.spacing = 10
        
        let ges = UITapGestureRecognizer(target: self, action: #selector(tapUserInfoView))
        stackView.addGestureRecognizer(ges)
        
        return stackView
    }()
    
    private lazy var dateFormatter: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYYY-MM-dd"
        return dateFormatter
    }()
    
    @objc private func tapUserInfoView() {
        let isLogin = Preferences.shared.loginInfo != nil
        if !isLogin {
            let vc = LoginViewController()
            vc.didLoginCallBack = { [weak self] vc, info in
                guard let self = self else { return }
                
                vc.navigationController?.popViewController(animated: true)
                
                self.view.showHUD(NSLocalizedString("登录成功！", comment: ""))
                
                Preferences.shared.loginInfo = info
                
                self.reloadUserInfo()
            }
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addSubview(scrollView)
        
        scrollView.addSubview(userAvatarImageView)
        scrollView.addSubview(infoStackView)
        scrollView.addSubview(logoutButton)
        
        infoStackView.addArrangedSubview(usernameLabel)
        infoStackView.addArrangedSubview(membershipExpiryLabel)
        infoStackView.addArrangedSubview(resourceMonitorExpiryLabel)
        
        setupConstraints()
        reloadUserInfo()
    }
    
    private func setupConstraints() {
        scrollView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        
        userAvatarImageView.snp.makeConstraints { (make) in
            make.top.equalTo(scrollView.snp.top).offset(20)
            make.leading.equalTo(scrollView).offset(20)
            make.width.height.equalTo(100)
        }
        
        infoStackView.snp.makeConstraints { (make) in
            make.top.equalTo(userAvatarImageView)
            make.leading.equalTo(userAvatarImageView.snp.trailing).offset(20)
            make.trailing.equalTo(scrollView).offset(-20)
        }
        
        logoutButton.snp.makeConstraints { make in
            make.top.equalTo(userAvatarImageView.snp.bottom).offset(20)
            make.leading.equalTo(self.view).offset(20)
            make.trailing.equalTo(self.view).offset(-20)
            make.height.equalTo(44)
            make.bottom.equalTo(-10)
        }
                
    }
    
    private func reloadUserInfo() {
        
        var placeHolderImg: UIImage?
        if let svgImage = SVGKImage(named: "User.svg", withCacheKey: "User.svg") {
            svgImage.size = CGSize(width: 100, height:100)
            placeHolderImg = svgImage.uiImage.byInsetEdge(UIEdgeInsets(top: -20, left: -20, bottom: -20, right: -20), with: nil)
        }
        
        if let userInfo = Preferences.shared.loginInfo {
            self.userAvatarImageView.sd_setImage(with: URL(string: userInfo.profileImage), placeholderImage: placeHolderImg)
            self.usernameLabel.text = userInfo.screenName
            if let date = userInfo.privileges?.member {
                self.membershipExpiryLabel.text = NSLocalizedString("会员过期时间: ", comment: "") + dateFormatter.string(from: date)
            } else {
                self.membershipExpiryLabel.text = nil
            }
            
            if let date = userInfo.privileges?.resmonitor {
                self.resourceMonitorExpiryLabel.text = NSLocalizedString("资源监视器权益过期时间: ", comment: "") + dateFormatter.string(from: date)
            } else {
                self.resourceMonitorExpiryLabel.text = nil
            }
            
            logoutButton.isHidden = false
            
        } else {
            self.userAvatarImageView.image = placeHolderImg
            self.usernameLabel.text = NSLocalizedString("点击登录", comment: "")
            self.membershipExpiryLabel.text = nil
            self.resourceMonitorExpiryLabel.text = nil
            logoutButton.isHidden = true
        }
        
    }

    @objc private func logoutButtonTapped() {
        Preferences.shared.loginInfo = nil
        self.reloadUserInfo()
    }
    
}
