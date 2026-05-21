//
//  PlayerLoadingView.swift
//  AniXPlayer
//
//  tvOS 播放器加载指示器 — 替代 iOS 的 MBProgressHUD
//

import UIKit
import SnapKit

class PlayerLoadingView: UIView {

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.startAnimating()
        return indicator
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 20, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black.withAlphaComponent(0.6)

        addSubview(activityIndicator)
        addSubview(statusLabel)

        activityIndicator.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-10)
        }

        statusLabel.snp.makeConstraints { make in
            make.top.equalTo(activityIndicator.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(60)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(text: String?) {
        statusLabel.text = text
    }

    func dismiss() {
        activityIndicator.stopAnimating()
        removeFromSuperview()
    }
}
