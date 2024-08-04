//
//  SearchViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/10.
//

import Cocoa
import ProgressHUD

protocol SearchViewControllerDelegate: AnyObject {
    func searchViewController(_ searchViewController: SearchViewController, didMatched matchInfo: MatchInfo)
}

class SearchViewController: ViewController {
    
    @IBOutlet weak var searchField: NSSearchField!
    
    @IBOutlet weak var outlineView: NSOutlineView!
    
    weak var delegate: SearchViewControllerDelegate?
    
    private var dataSource = [MediaMatchItem]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("搜索结果", comment: "")
        
        self.outlineView.registerClassCell(class: MatchsCell.self)
        self.outlineView.target = self
        self.outlineView.doubleAction = #selector(doubleAction(_:))
        self.searchField.target = self
        self.searchField.action = #selector(searchAction(_:))
    }
    
    // MARK: Private
    @objc private func doubleAction(_ sender: NSOutlineView) {
        if sender.selectedRow > -1,
            let item = sender.item(atRow: sender.selectedRow) as? MediaMatchItem {
            if let episodeId = item.episodeId {
                self.delegate?.searchViewController(self, didMatched: item)
            }
        }
    }
    
    @objc private func searchAction(_ sender: NSSearchField) {
        
        let text = sender.stringValue
        
        if text.isEmpty {
            return
        }
        
        SearchNetworkHandle.searchWithKeyword(text) { [weak self] (result, error) in
            
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.view.show(error: error)
                }
                return
            }
            
            DispatchQueue.main.async {
                self.dataSource = result?.collection ?? []
                self.outlineView.reloadData()
            }
        }
    }
}


extension SearchViewController: NSOutlineViewDataSource {
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


extension SearchViewController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        if let item = item as? MediaMatchItem {
            let cell = outlineView.dequeueReusableCell(class: MatchsCell.self)
            cell.model = item
            return cell
        }
        return nil
    }
}

