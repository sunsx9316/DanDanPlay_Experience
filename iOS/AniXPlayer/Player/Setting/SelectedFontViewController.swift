//
//  SelectedFontViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2025/1/30.
//

import UIKit
import SnapKit

class SelectedFontViewController: ViewController {
    
    private lazy var familyNames = [String]()
    
    private lazy var allFontDic = [String: [UIFont]]()
    
    private var selectedFontName: String?
    
    private var mediaModel: PlayerMediaModel!
    
    private lazy var tableView: TableView = {
        let tableView = TableView(frame: .zero, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.registerNibCell(class: TitleTableViewCell.self)
        tableView.estimatedRowHeight = 50
        tableView.rowHeight = UITableView.automaticDimension
        tableView.backgroundColor = .clear
        tableView.showsVerticalScrollIndicator = false
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = .darkGray
        tableView.mj_header = RefreshHeader(refreshingTarget: self, refreshingAction: #selector(beginRefresh))
        return tableView
    }()
    
    init(mediaModel: PlayerMediaModel!) {
        self.mediaModel = mediaModel
        self.selectedFontName = mediaModel.subtitleFontName
        super.init(nibName: nil, bundle: nil)
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("字幕字体", comment: "")
        self.view.addSubview(self.tableView)
        
        let resetItem = UIBarButtonItem(title: NSLocalizedString("恢复默认", comment: ""), target: self, action: #selector(onTouchResetItem))
        resetItem.setTitleTextAttributes([.font : UIFont.ddp_large, .foregroundColor : UIColor.navigationTitleColor], for: .normal)
        self.navigationItem.rightBarButtonItem = resetItem
        
        self.tableView.snp.makeConstraints { make in
            make.top.leading.trailing.bottom.equalToSuperview()
        }
        
        tableView.mj_header?.beginRefreshing()
    }
    
    @objc private func onTouchResetItem() {
        self.selectedFontName = nil
        self.mediaModel.onChangeSubtitleFont(nil)
        self.tableView.reloadData()
    }
    
    @objc private func beginRefresh() {
        // 获取所有字体家族名称
        let fontFamilies = UIFont.familyNames
        DispatchQueue.global().async {
            // 获取该系列下的具体字体
            
            var allFontDic = [String: [UIFont]]()
            fontFamilies.forEach { family in
                let fontNames = UIFont.fontNames(forFamilyName: family)
                var fonts = [UIFont]()
                fontNames.forEach { fontName in
                    if let font = UIFont(name: fontName, size: 16) {
                        fonts.append(font)
                    }
                }
                allFontDic[family] = fonts
            }
            
            
            DispatchQueue.main.async {
                self.familyNames = fontFamilies.sorted(by: { name1, name2 in
                    return name1 > name2
                })
                self.allFontDic = allFontDic
                self.tableView.reloadData()
                self.tableView.mj_header?.endRefreshing()
                
                /// 滚动到指定位置
                for (familyName, fonts) in allFontDic {
                    if let row = fonts.firstIndex(where: { $0.fontName == self.selectedFontName }),
                       let section = self.familyNames.firstIndex(of: familyName) {
                        let indexPath = IndexPath(row: row, section: section)
                        self.tableView.scrollToRow(at: indexPath, at: .middle, animated: false)
                        break
                    }
                }
                
            }
        }
    }
}

extension SelectedFontViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueCell(class: TitleTableViewCell.self, indexPath: indexPath)
        let font = self.allFontDic[self.familyNames[indexPath.section]]?[indexPath.row]
        cell.label.text = font?.fontName
        cell.label.font = font
        
        if font?.fontName == self.selectedFontName {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let font = self.allFontDic[self.familyNames[indexPath.section]]?[indexPath.row] {
            self.selectedFontName = font.fontName
            self.mediaModel.onChangeSubtitleFont(font)
            tableView.reloadData()
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.familyNames[section]
    }
}

extension SelectedFontViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.allFontDic[self.familyNames[section]]?.count ?? 0
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.allFontDic.count
    }
}
