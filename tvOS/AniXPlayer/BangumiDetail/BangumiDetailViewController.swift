//
//  BangumiDetailViewController.swift
//  AniXPlayer
//
//  tvOS 番剧详情 — 封面 + 信息 + 集数列表
//

import UIKit
import SnapKit
import Kingfisher

class BangumiDetailViewController: ViewController {

    private let animeId: Int

    private var bangumiDetail: BangumiDetail?

    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        return sv
    }()

    private let contentView = UIView()

    private let posterImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 8
        iv.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        return iv
    }()

    private let titleLabel: Label = {
        let label = Label()
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = .white
        label.numberOfLines = 2
        return label
    }()

    private let summaryLabel: Label = {
        let label = Label()
        label.font = .systemFont(ofSize: 17)
        label.textColor = .lightGray
        label.numberOfLines = 0
        return label
    }()

    private let episodeHeaderLabel: Label = {
        let label = Label()
        label.font = .systemFont(ofSize: 22, weight: .bold)
        label.textColor = .white
        label.text = NSLocalizedString("剧集列表", comment: "")
        return label
    }()

    private lazy var episodeTableView: TableView = {
        let tv = TableView(frame: .zero, style: .plain)
        tv.delegate = self
        tv.dataSource = self
        tv.register(EpisodeCell.self, forCellReuseIdentifier: EpisodeCell.reuseIdentifier)
        tv.rowHeight = 80
        tv.isScrollEnabled = false
        return tv
    }()

    private var episodeTableViewHeightConstraint: Constraint?

    init(animateId: Int) {
        self.animeId = animateId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = NSLocalizedString("番剧详情", comment: "")

        setupUI()
        loadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.defaultFocusView = episodeTableView
    }

    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(posterImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(summaryLabel)
        contentView.addSubview(episodeHeaderLabel)
        contentView.addSubview(episodeTableView)

        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }

        posterImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(40)
            make.centerX.equalToSuperview()
            make.width.equalTo(300)
            make.height.equalTo(169)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(posterImageView.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(60)
        }

        summaryLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(60)
        }

        episodeHeaderLabel.snp.makeConstraints { make in
            make.top.equalTo(summaryLabel.snp.bottom).offset(30)
            make.leading.trailing.equalToSuperview().inset(60)
        }

        episodeTableView.snp.makeConstraints { make in
            make.top.equalTo(episodeHeaderLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(60)
            self.episodeTableViewHeightConstraint = make.height.equalTo(0).constraint
            make.bottom.equalToSuperview().offset(-40)
        }
    }

    private func loadData() {
        BangumiNetworkHandle.detail(animateId: animeId) { [weak self] response, error in
            guard let self = self else { return }
            if let detail = response?.bangumi {
                self.bangumiDetail = detail
                DispatchQueue.main.async {
                    self.updateUI()
                }
            }
        }
    }

    private func updateUI() {
        guard let detail = bangumiDetail else { return }

        titleLabel.text = detail.animeTitle
        summaryLabel.text = detail.summary

        if let url = URL(string: detail.imageUrl) {
            posterImageView.kf.setImage(with: url)
        }

        let episodeCount = detail.episodes.count
        episodeTableView.snp.remakeConstraints { make in
            make.top.equalTo(episodeHeaderLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(60)
            make.height.equalTo(CGFloat(episodeCount) * 80)
            make.bottom.equalToSuperview().offset(-40)
        }

        episodeTableView.reloadData()
    }

    private func playEpisode(_ episode: BangumiEpisode) {
        let playerVC = PlayerViewController()
        // TODO: Phase 9 — 根据 episode 创建对应的 File 并播放
        self.present(playerVC, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension BangumiDetailViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return bangumiDetail?.episodes.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: EpisodeCell.reuseIdentifier, for: indexPath) as! EpisodeCell
        if let episode = bangumiDetail?.episodes[indexPath.row] {
            cell.configure(with: episode)
        }
        return cell
    }
}

// MARK: - UITableViewDelegate

extension BangumiDetailViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let episode = bangumiDetail?.episodes[indexPath.row] else { return }
        playEpisode(episode)
    }
}
