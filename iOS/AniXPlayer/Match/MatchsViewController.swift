//
//  MatchsViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/3.
//

import UIKit
import SnapKit

protocol MatchsViewControllerDelegate: AnyObject {
    func matchsViewController(_ matchsViewController: MatchsViewController, didMatched matchInfo: MatchInfo)
    
    func playNowInMatchsViewController(_ matchsViewController: MatchsViewController)
}

extension MatchsViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = self.dataSource[indexPath.item]
        
        let cell: EpisodeTableViewCell
        
        if model.items?.isEmpty == false {
            cell = tableView.dequeueCell(class: AnimatesTableViewCell.self, indexPath: indexPath)
        } else {
            cell = tableView.dequeueCell(class: EpisodeTableViewCell.self, indexPath: indexPath)
        }
        
        cell.model = model
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let model = self.dataSource[indexPath.item]
        if let items = model.items, !items.isEmpty {
            let vc = MatchsViewController(with: items, file: self.file, style: self.style)
            vc.title = model.title
            vc.hidesBottomBarWhenPushed = true
            vc.delegate = self
            self.navigationController?.pushViewController(vc, animated: true)
        } else if (model.episodeId ?? 0) > 0 {
            self.delegate?.matchsViewController(self, didMatched: model)
        }
    }
}


extension MatchsViewController: MatchsViewControllerDelegate {
    func matchsViewController(_ matchsViewController: MatchsViewController, didMatched matchInfo: any MatchInfo) {
        self.delegate?.matchsViewController(matchsViewController, didMatched: matchInfo)
    }
    
    func playNowInMatchsViewController(_ matchsViewController: MatchsViewController) {
        self.delegate?.playNowInMatchsViewController(matchsViewController)
    }
}


extension MatchsViewController: SearchViewControllerDelegate {
    func searchViewController(_ searchViewController: SearchViewController, didMatched matchInfo: any MatchInfo) {
        self.delegate?.matchsViewController(self, didMatched: matchInfo)
    }
}

class MatchsViewController: ViewController {
    
    enum Style {
        case full
        case mini
    }
    
    private class _AnimateModel: MediaMatchItem {
        
        var matchId: Int {
            return 0
        }
        
        var matchDesc: String {
            return ""
        }
        
        var typeDesc: String? {
            return self.match.typeDescription
        }
        
        var items: [MediaMatchItem]? = .init()
        
        var title: String {
            return self.match.animeTitle
        }
        
        var episodeId: Int? {
            return nil
        }
        
        let match: Match
        
        init(match: Match) {
            self.match = match
        }
    }
    
    private class _EpisodeModel: _AnimateModel {
        
        override var matchId: Int {
            return self.episodeId
        }
        
        override var episodeId: Int {
            return self.match.episodeId
        }
        
        override var title: String {
            return self.match.episodeTitle
        }
        
        override var matchDesc: String {
            return self.match.matchDesc
        }
    }
    
    private lazy var dataSource = [MediaMatchItem]()
    
    private lazy var tableView: TableView = {
        let tableView = TableView(frame: .zero, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.registerClassCell(class: EpisodeTableViewCell.self)
        tableView.registerClassCell(class: AnimatesTableViewCell.self)
        tableView.estimatedRowHeight = 50
        tableView.rowHeight = UITableView.automaticDimension
        tableView.mj_header = RefreshHeader(refreshingTarget: self, refreshingAction: #selector(beginRefresh))
        return tableView
    }()
    
    private var requestDataAtInit = false
    
    var showPlayNowItem = true
    
    let file: File
    
    let style: Style
    
    private init(with items: [MediaMatchItem], file: File, style: Style) {
        self.style = style
        self.file = file
        super.init(nibName: nil, bundle: nil)
        self.dataSource = items
        self.title = NSLocalizedString("弹幕匹配结果", comment: "")
    }
    
    convenience init(file: File) {
        self.init(with: [], file: file, style: .mini)
        self.requestDataAtInit = true
    }
    
    convenience init(with collection: MatchCollection, file: File) {
        let values = type(of: self).converCollection(collection)
        self.init(with: values, file: file, style: .full)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    weak var delegate: MatchsViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.view.safeAreaLayoutGuide.snp.edges)
        }
        
        var items = [UIBarButtonItem]()
        let rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("搜索弹幕", comment: ""), target: self, action: #selector(onTouchSearchButton))
        items.append(rightBarButtonItem)
        
        if self.showPlayNowItem {
            let playNowItem = UIBarButtonItem(title: NSLocalizedString("直接播放", comment: ""), target: self, action: #selector(onTouchPlayNowButton))
            items.append(playNowItem)
        }
        
        self.navigationItem.rightBarButtonItems = items
        
        if self.requestDataAtInit {
            self.requestDate {}
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    //MARK: Private Method
    @objc private func onTouchSearchButton() {
        let vc = SearchViewController()
        vc.delegate = self
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    private func requestDate(completion: @escaping(() -> Void)) {
        MatchNetworkHandle.match(with: file) { (_) in
            
        } completion: { [weak self] (collection, error) in
            
            guard let self = self else {
                return
            }
            
            if let collection = collection {
                let values = type(of: self).converCollection(collection)
                DispatchQueue.main.async {
                    self.dataSource = values
                    self.tableView.reloadData()
                    completion()
                }
            } else if let error = error {
                DispatchQueue.main.async {
                    self.view.showError(error)
                    completion()
                }
            }
        }
        
    }
    
    @objc private func beginRefresh() {
        self.requestDate { [weak self] in
            guard let self = self else { return }
            
            self.tableView.mj_header?.endRefreshing()
        }
    }
    
    @objc private func onTouchPlayNowButton() {
        self.delegate?.playNowInMatchsViewController(self)
    }
    
    private static func converCollection(_ collection: MatchCollection) -> [_AnimateModel] {
        var animateDic = [Int : _AnimateModel]()
        
        for item in collection.collection {
            if animateDic[item.animeId] == nil {
                let anime = _AnimateModel(match: item)
                animateDic[item.animeId] = anime
            }
            
            let episodeModel = _EpisodeModel(match: item)
            animateDic[item.animeId]?.items?.append(episodeModel)
        }
        
        return Array(animateDic.values).sorted { m1, m2 in
            
            let t1 = m1.title
            let t2 = m2.title
            
            return t1.compare(t2) == .orderedDescending
        }
    }

}
