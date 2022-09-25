//
//  MatchsViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/10.
//

import Cocoa
import ProgressHUD

protocol MatchsViewControllerDelegate: AnyObject {
    func matchsViewController(_ matchsViewController: MatchsViewController, didSelectedEpisodeId episodeId: Int)
    
    func playNowInMatchsViewController(_ matchsViewController: MatchsViewController)
}

class MatchsViewController: ViewController {
    
    private class _AnimateModel: MatchItem {
        var typeDesc: String?
        
        var items: [MatchItem]? = .init()
        
        var title = ""
        
        var episodeId: Int?
    }
    
    private class _EpisodeModel: _AnimateModel {}
    
    
    @IBOutlet weak var outlineView: NSOutlineView!
    
    weak var delegate: MatchsViewControllerDelegate?
    
    private var searchWindowController: WindowController?
    
    init(file: File) {
        self.file = file
        super.init()
    }
    
    init(with collection: MatchCollection, file: File) {
        self.file = file
        super.init()
        self.dataFromInit = true
        self.dataSource = type(of: self).converCollection(collection)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    let file: File
    
    private var dataSource = [MatchItem]()
    
    /// 数据来源于初始化
    private var dataFromInit = false
    
    deinit {
        self.closeSearchWindow()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("弹幕匹配结果", comment: "")
        
        self.outlineView.target = self
        self.outlineView.doubleAction = #selector(doubleAction(_:))
        
        let menu = NSMenu()
        menu.addItem(withTitle: NSLocalizedString("刷新", comment: ""), action: #selector(startRequestData), keyEquivalent: "")
        menu.addItem(withTitle: NSLocalizedString("搜索更多弹幕", comment: ""), action: #selector(searchAction), keyEquivalent: "")
        menu.addItem(withTitle: NSLocalizedString("直接播放", comment: ""), action: #selector(playNow), keyEquivalent: "")
        self.view.menu = menu
        
        if dataFromInit {
            self.outlineView.reloadData()
        } else {
            self.startRequestData()
        }
    }
    
    // MARK: Private
    @objc private func doubleAction(_ sender: NSOutlineView) {
        if sender.selectedRow > -1,
            let item = sender.item(atRow: sender.selectedRow) as? MatchItem {
            if let episodeId = item.episodeId {
                self.delegate?.matchsViewController(self, didSelectedEpisodeId: episodeId)
            }
        }
    }
    
    private func closeSearchWindow() {
        self.searchWindowController?.close()
        self.searchWindowController = nil
    }
    
    @objc private func playNow() {
        self.delegate?.playNowInMatchsViewController(self)
    }
    
    @objc private func searchAction() {
        self.closeSearchWindow()
        
        let vc = SearchViewController()
        vc.delegate = self
        self.searchWindowController = .init()
        self.searchWindowController?.contentViewController = vc
        self.searchWindowController?.showAtCenter(self.view.window)
        self.searchWindowController?.window?.title = vc.title ?? ""
        self.searchWindowController?.window?.level = .floating
        self.searchWindowController?.windowWillCloseCallBack = { [weak self] in
            guard let self = self else { return }
            
            self.searchWindowController = nil
        }
    }
    
    @objc private func startRequestData() {
        let hud = self.view.showLoading("")
        self.requestData { [weak hud] in
            guard let hud = hud else { return }
            hud.hide(true)
        }
    }
    
    private func requestData(completion: @escaping(() -> Void)) {
        
        NetworkManager.shared.matchWithFile(file) { (_) in
            
        } completion: { [weak self] (collection, error) in
            
            guard let self = self else {
                return
            }
            
            if let collection = collection {
                DispatchQueue.main.async {
                    let items = type(of: self).converCollection(collection)
                    self.dataSource = items
                    self.outlineView.reloadData()
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
    
    private static func converCollection(_ collection: MatchCollection) -> [_AnimateModel] {
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
        
        return Array(animateDic.values).sorted { m1, m2 in
            
            let t1 = m1.title
            let t2 = m2.title
            
            return t1.compare(t2) == .orderedDescending
        }
    }
    
}

extension MatchsViewController: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        
        if item is NSNull {
            return 0
        }
        
        if let item = item as? MatchItem {
            return item.items?.count ?? 0
        }
        return self.dataSource.count
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return self.dataSource[index]
        } else if let item = item as? MatchItem {
            return item.items?[index] ?? NSNull()
        }
        return NSNull()
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let item = item as? MatchItem {
            return item.items?.isEmpty == false
        }
        return false
    }
    
}


extension MatchsViewController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        if let item = item as? MatchItem {
            let cell = outlineView.dequeueCell(cellClass: MatchsCell.self)
            cell.model = item
            return cell
        }
        return nil
    }
}


extension MatchsViewController: SearchViewControllerDelegate {
    func searchViewController(_ searchViewController: SearchViewController, didSelectedEpisodeId episodeId: Int) {
        self.delegate?.matchsViewController(self, didSelectedEpisodeId: episodeId)
    }
    
    
}
