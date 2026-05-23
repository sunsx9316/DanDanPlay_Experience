//
//  PlayerLoadingView.swift
//  AniXPlayer
//
//  tvOS 播放器加载指示器 — 带进度条的加载视图
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

    private let progressView: UIProgressView = {
        let pv = UIProgressView(progressViewStyle: .default)
        pv.trackTintColor = UIColor.white.withAlphaComponent(0.2)
        pv.progressTintColor = .white
        pv.progress = 0
        return pv
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .ddp_small(weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black.withAlphaComponent(0.6)

        addSubview(activityIndicator)
        addSubview(progressView)
        addSubview(statusLabel)

        activityIndicator.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-30)
        }

        progressView.snp.makeConstraints { make in
            make.top.equalTo(activityIndicator.snp.bottom).offset(24)
            make.centerX.equalToSuperview()
            make.width.equalTo(300)
        }

        statusLabel.snp.makeConstraints { make in
            make.top.equalTo(progressView.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(60)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(text: String?, progress: Float) {
        statusLabel.text = text
        progressView.progress = progress
    }

    func dismiss() {
        activityIndicator.stopAnimating()
        removeFromSuperview()
    }
}
