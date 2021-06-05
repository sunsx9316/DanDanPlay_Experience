//
//  SearchViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/8.
//

import UIKit

protocol SearchViewControllerDelegate: AnyObject {
    func searchViewController(_ searchViewController: SearchViewController, didSelectedEpisodeId episodeId: Int)
}

extension Search: MatchItem {
    var episodeId: Int? {
        self.id
    }
    
    var items: [MatchItem]? {
        return nil
    }
    
    var title: String {
        return self.episodeTitle
    }
    
    var typeDesc: String? {
        return nil
    }
}

extension SearchCollection: MatchItem {
    var items: [MatchItem]? {
        return self.collection
    }
    
    var title: String {
        return self.animeTitle
    }
    
    var episodeId: Int? {
        return nil
    }
    
    var typeDesc: String? {
        return self.typeDescription
    }
}

extension SearchViewController: UITableViewDelegate, UITableViewDataSource {
    
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
        
        let item = self.dataSource[indexPath.row]
        
        if let items = item.items, items.isEmpty == false {
            let vc = SearchViewController(with: items)
            vc.title = item.title
            vc.isRootVC = false
            vc.delegate = self
            self.navigationController?.pushViewController(vc, animated: true)
        } else if let episodeId = item.episodeId {
            self.delegate?.searchViewController(self, didSelectedEpisodeId: episodeId)
        }
    }
}

extension SearchViewController: SearchViewControllerDelegate {
    func searchViewController(_ searchViewController: SearchViewController, didSelectedEpisodeId episodeId: Int) {
        self.delegate?.searchViewController(searchViewController, didSelectedEpisodeId: episodeId)
    }
}

extension SearchViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        self.beginRefresh()
    }
}

class SearchViewController: ViewController {
    
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
    
    private var isRootVC = true
    
    private init(with items: [MatchItem]) {
        super.init(nibName: nil, bundle: nil)
        self.dataSource = items
    }
    
    weak var delegate: SearchViewControllerDelegate?
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.view.safeAreaLayoutGuide.snp.edges)
        }
        
        if self.isRootVC {
            let searchController = UISearchController(searchResultsController: nil)
            searchController.searchBar.autocapitalizationType = .none
            searchController.searchBar.setImage(UIImage(named: "Player/player_close_button")?.byResize(to: .init(width: 16, height: 16)), for: .clear, state: .normal)
            searchController.dimsBackgroundDuringPresentation = false
            searchController.searchBar.delegate = self
            self.navigationItem.searchController = searchController
            self.navigationItem.hidesSearchBarWhenScrolling = false
            
            self.tableView.mj_header = RefreshHeader(refreshingTarget: self, refreshingAction: #selector(beginRefresh))
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    //MARK: Private Method
    @objc private func beginRefresh() {
        if let text = self.navigationItem.searchController?.searchBar.text,
           text.isEmpty == false {
            NetworkManager.shared.searchWithKeyword(text) { [weak self] (result, error) in
                
                guard let self = self else { return }
                
                if let error = error {
                    DispatchQueue.main.async {
                        self.view.showError(error)
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self.dataSource = result?.collection ?? []
                    self.tableView.mj_header?.endRefreshing()
                    self.tableView.reloadData()
                }
            }
        } else {
            self.tableView.mj_header?.endRefreshing()
        }
    }
    
}
