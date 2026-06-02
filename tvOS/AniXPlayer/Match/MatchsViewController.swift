//
//  MatchsViewController.swift
//  AniXPlayer
//
//  tvOS 弹幕匹配页面 — 展示匹配列表，支持搜索弹幕/直接播放，参考 iOS 实现
//

import UIKit
import SnapKit
import RxSwift
#if !os(tvOS)
import ANXLog
#endif

protocol MatchsViewControllerDelegate: AnyObject {
    func matchsViewController(_ matchsViewController: MatchsViewController, didMatched matchInfo: MatchInfo)
    func playNowInMatchsViewController(_ matchsViewController: MatchsViewController)
}

class MatchsViewController: ViewController {

    enum Style {
        case full
        case mini
    }

    private let collection: MatchCollection
    private let media: File
    private let playerModel: PlayerModel
    private let style: Style

    weak var delegate: MatchsViewControllerDelegate?

    private var matches: [Match] = []
    private let bag = DisposeBag()

    // MARK: - Toolbar Buttons

    private lazy var searchButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle(NSLocalizedString("搜索弹幕", comment: ""), for: .normal)
        btn.setImage(UIImage(systemName: "magnifyingglass"), for: .normal)
        btn.titleLabel?.font = .ddp_small()
        btn.tintColor = UIColor.mainColor
        btn.addTarget(self, action: #selector(onTouchSearchButton), for: .primaryActionTriggered)
        return btn
    }()

    private lazy var playNowButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle(NSLocalizedString("直接播放", comment: ""), for: .normal)
        btn.setImage(UIImage(systemName: "play.fill"), for: .normal)
        btn.titleLabel?.font = .ddp_small()
        btn.tintColor = UIColor.mainColor
        btn.addTarget(self, action: #selector(onTouchPlayNowButton), for: .primaryActionTriggered)
        return btn
    }()

    private lazy var toolbarStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [searchButton, playNowButton])
        stack.axis = .horizontal
        stack.spacing = 40
        stack.alignment = .center
        return stack
    }()

    // MARK: - TableView

    private lazy var tableView: TableView = {
        let tv = TableView(frame: .zero, style: .grouped)
        tv.delegate = self
        tv.dataSource = self
        tv.register(MatchCell.self, forCellReuseIdentifier: MatchCell.reuseIdentifier)
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 100
        return tv
    }()

    // MARK: - Init

    init(collection: MatchCollection, media: File, playerModel: PlayerModel, style: Style = .full) {
        self.collection = collection
        self.media = media
        self.playerModel = playerModel
        self.style = style
        self.matches = collection.collection
        super.init(nibName: nil, bundle: nil)
    }

    convenience init(file: File, playerModel: PlayerModel) {
        self.init(collection: MatchCollection(isMatched: false, collection: []), media: file, playerModel: playerModel, style: .mini)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = NSLocalizedString("选择弹幕匹配", comment: "")

        view.addSubview(toolbarStack)
        view.addSubview(tableView)

        toolbarStack.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(12)
            make.centerX.equalToSuperview()
        }

        playNowButton.isHidden = (style != .mini)

        tableView.snp.makeConstraints { make in
            make.top.equalTo(toolbarStack.snp.bottom).offset(12)
            make.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(40)
        }

        if style == .mini {
            requestData {}
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.defaultFocusView = style == .mini && matches.isEmpty ? searchButton : tableView
    }

    // MARK: - Actions

    @objc private func onTouchSearchButton() {
        let vc = SearchViewController()
        vc.delegate = self
        self.navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func onTouchPlayNowButton() {
        if let delegate = self.delegate {
            delegate.playNowInMatchsViewController(self)
        } else {
            self.dismiss(animated: true) { [weak self] in
                guard let self = self else { return }
                _ = self.playerModel.startPlay(self.media, matchInfo: nil, danmakus: [:]).subscribe()
            }
        }
    }

    // MARK: - Private

    private func selectMatch(_ match: Match) {
        if let delegate = self.delegate {
            delegate.matchsViewController(self, didMatched: match)
        } else {
            self.dismiss(animated: true) { [weak self] in
                guard let self = self else { return }
                ANX.logInfo(.player, "[MatchVC] 用户选择弹幕匹配: \(match.animeTitle) - \(match.episodeTitle)")
                _ = self.playerModel.didMatchMedia(self.media, matchInfo: match).subscribe()
            }
        }
    }

    private func requestData(completion: @escaping () -> Void) {
        MatchNetworkHandle.match(with: self.media) { _ in
        } completion: { [weak self] collection, error in
            guard let self = self else { return }

            if let collection = collection {
                DispatchQueue.main.async {
                    self.matches = collection.collection
                    self.tableView.reloadData()
                    completion()
                }
            } else if let error = error {
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: nil, message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: NSLocalizedString("确定", comment: ""), style: .default))
                    self.present(alert, animated: true)
                    completion()
                }
            }
        }
    }
}

// MARK: - UITableViewDataSource

extension MatchsViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return matches.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MatchCell.reuseIdentifier, for: indexPath) as! MatchCell
        cell.configure(with: matches[indexPath.row])
        return cell
    }
}

// MARK: - UITableViewDelegate

extension MatchsViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectMatch(matches[indexPath.row])
    }
}

// MARK: - SearchViewControllerDelegate

extension MatchsViewController: SearchViewControllerDelegate {
    func searchViewController(_ searchViewController: SearchViewController, didMatched matchInfo: any MatchInfo) {
        if let delegate = self.delegate {
            delegate.matchsViewController(self, didMatched: matchInfo)
        } else {
            self.navigationController?.popToRootViewController(animated: false)
            self.dismiss(animated: true) { [weak self] in
                guard let self = self else { return }
                ANX.logInfo(.player, "[MatchVC] 搜索弹幕匹配: \(matchInfo.matchDesc)")
                _ = self.playerModel.didMatchMedia(self.media, matchInfo: matchInfo).subscribe()
            }
        }
    }
}
