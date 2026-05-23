//
//  PlayerUITopView.swift
//  AniXPlayer
//
//  tvOS 播放器顶部控制栏 — 显示视频标题
//

import UIKit
import SnapKit

class PlayerUITopView: UIView {

    var title: String? {
        get { titleLabel.text }
        set { titleLabel.text = newValue }
    }

    private let backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0, alpha: 0.4)
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .ddp_normal(weight: .medium)
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        addSubview(backgroundView)
        addSubview(titleLabel)

        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(80)
            make.trailing.equalToSuperview().offset(-80)
            make.bottom.equalToSuperview().offset(-16)
        }
    }
}
