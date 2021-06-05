//
//  MatchsViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/3.
//

import UIKit
import SnapKit

protocol MatchsViewControllerDelegate: AnyObject {
    func matchsViewController(_ matchsViewController: MatchsViewController, didSelectedEpisodeId episodeId: Int)
    
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
            let vc = MatchsViewController(with: items, file: self.file)
            vc.title = model.title
            vc.hidesBottomBarWhenPushed = true
            vc.delegate = self
            self.navigationController?.pushViewController(vc, animated: true)
        } else if let episodeId = model.episodeId {
            self.delegate?.matchsViewController(self, didSelectedEpisodeId: episodeId)
        }
    }
}


extension MatchsViewController: MatchsViewControllerDelegate {
    func matchsViewController(_ matchsViewController: MatchsViewController, didSelectedEpisodeId episodeId: Int) {
        self.delegate?.matchsViewController(matchsViewController, didSelectedEpisodeId: episodeId)
    }
    
    func playNowInMatchsViewController(_ matchsViewController: MatchsViewController) {
        self.delegate?.playNowInMatchsViewController(matchsViewController)
    }
}


extension MatchsViewController: SearchViewControllerDelegate {
    
    func searchViewController(_ searchViewController: SearchViewController, didSelectedEpisodeId episodeId: Int) {
        self.delegate?.matchsViewController(self, didSelectedEpisodeId: episodeId)
    }
    
}

class MatchsViewController: ViewController {
    
    private class _AnimateModel: MatchItem {
        var typeDesc: String?
        
        var items: [MatchItem]? = .init()
        
        var title = ""
        
        var episodeId: Int?
    }
    
    private class _EpisodeModel: _AnimateModel {
        
    }
    
    private lazy var dataSource = [MatchItem]()
    
    private lazy var tableView: TableView = {
        let tableView = TableView(frame: .zero, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.registerClassCell(class: EpisodeTableViewCell.self)
        tableView.registerClassCell(class: AnimatesTableViewCell.self)
        tableView.estimatedRowHeight = 50
        tableView.rowHeight = UITableView.automaticDimension
        return tableView
    }()
    
    let file: File
    
    private init(with items: [MatchItem], file: File) {
        self.file = file
        super.init(nibName: nil, bundle: nil)
        self.dataSource = items.sorted(by: { m1, m2 in
            return m1.title.compare(m2.title) == .orderedDescending
        })
    }
    
    convenience init(with collection: MatchCollection, file: File) {
 
        var animateDic = [Int : _AnimateModel]()
        
        for item in collection.collection {
            if animateDic[item.animeId] == nil {
                let anime = _AnimateModel()
                anime.title = item.animeTitle
                anime.typeDesc = item.typeDescription
                animateDic[item.animeId] = anime
            }
            
            let episodeModel = _EpisodeModel()
            episodeModel.title = item.episodeTitle
            episodeModel.episodeId = item.episodeId
            animateDic[item.animeId]?.items?.append(episodeModel)
        }
        
        let values = Array(animateDic.values).sorted { m1, m2 in
            
            let t1 = m1.title
            let t2 = m2.title
            
            return t1.compare(t2) == .orderedDescending
        }
        self.init(with: values, file: file)
        self.title = NSLocalizedString("匹配结果", comment: "")
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
        
        let rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("搜索", comment: ""), style: .plain, target: self, action: #selector(onTouchSearchButton))
        rightBarButtonItem.setTitleTextAttributes([.font : UIFont.ddp_normal,
                                                   .foregroundColor : UIColor.navigationTitleColor], for: .normal)
        rightBarButtonItem.setTitleTextAttributes([.font : UIFont.ddp_normal,
                                                   .foregroundColor : UIColor.black], for: .highlighted)
        
        let playNowItem = UIBarButtonItem(title: NSLocalizedString("直接播放", comment: ""), style: .plain, target: self, action: #selector(onTouchPlayNowButton))
        playNowItem.setTitleTextAttributes([.font : UIFont.ddp_normal,
                                                   .foregroundColor : UIColor.navigationTitleColor], for: .normal)
        playNowItem.setTitleTextAttributes([.font : UIFont.ddp_normal,
                                                   .foregroundColor : UIColor.black], for: .highlighted)
        
        self.navigationItem.rightBarButtonItems = [rightBarButtonItem, playNowItem]
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    @objc private func onTouchSearchButton() {
        let vc = SearchViewController()
        vc.delegate = self
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func onTouchPlayNowButton() {
        self.delegate?.playNowInMatchsViewController(self)
    }

}
