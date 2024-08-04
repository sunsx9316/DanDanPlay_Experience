//
//  MatchsViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/10.
//

import Cocoa
import ProgressHUD

protocol MatchsViewControllerDelegate: AnyObject {
    func matchsViewController(_ matchsViewController: MatchsViewController, didMatched matchInfo: MatchInfo)
    
    func playNowInMatchsViewController(_ matchsViewController: MatchsViewController)
}

class MatchsViewController: ViewController {
    
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
    
    private var dataSource = [MediaMatchItem]()
    
    /// 数据来源于初始化
    private var dataFromInit = false
    
    deinit {
        self.closeSearchWindow()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("弹幕匹配结果（右键搜索）", comment: "")
        
        self.outlineView.target = self
        self.outlineView.doubleAction = #selector(doubleAction(_:))
        self.outlineView.registerClassCell(class: MatchsCell.self)
        
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
            let item = sender.item(atRow: sender.selectedRow) as? MediaMatchItem {
            if let episodeId = item.episodeId {
                self.delegate?.matchsViewController(self, didMatched: item)
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
        self.view.showLoading(statusText: "")
        self.requestData { [weak self] in
            guard let self = self else { return }
            
            self.view.dismiss(delay: 0)
        }
    }
    
    private func requestData(completion: @escaping(() -> Void)) {
        MatchNetworkHandle.match(with: file) { (_) in
            
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
                    self.view.show(error: error)
                    completion()
                }
            }
        }
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

extension MatchsViewController: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        
        if item is NSNull {
            return 0
        }
        
        if let item = item as? MediaMatchItem {
            return item.items?.count ?? 0
        }
        return self.dataSource.count
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return self.dataSource[index]
        } else if let item = item as? MediaMatchItem {
            return item.items?[index] ?? NSNull()
        }
        return NSNull()
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let item = item as? MediaMatchItem {
            return item.items?.isEmpty == false
        }
        return false
    }
    
}


extension MatchsViewController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        if let item = item as? MediaMatchItem {
            let cell = outlineView.dequeueReusableCell(class: MatchsCell.self)
            cell.model = item
            return cell
        }
        return nil
    }
}


extension MatchsViewController: SearchViewControllerDelegate {
    func searchViewController(_ searchViewController: SearchViewController, didMatched matchInfo: any MatchInfo) {
        self.delegate?.matchsViewController(self, didMatched: matchInfo)
    }
    
}
