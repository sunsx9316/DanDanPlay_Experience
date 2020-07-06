//
//  FileListViewController.swift
//  FileBrowser
//
//  Created by Roy Marmelstein on 12/02/2016.
//  Copyright © 2016 Roy Marmelstein. All rights reserved.
//

import Foundation

class FileListViewController: UIViewController {
    
    // TableView
    @IBOutlet weak var tableView: UITableView!
    let collation = UILocalizedIndexedCollation.current()
    
    /// Data
    var multipleSelection = false {
        didSet {
            if isViewLoaded {
                tableView.allowsMultipleSelection = multipleSelection
                tableView.allowsMultipleSelectionDuringEditing = multipleSelection
                
                resetNavigationItem()
            }
        }
    }
    var didSelectFiles: (([FBFile]) -> ())?
    var files = [FBFile]()
    var initialPath: URL?
    let parser = FileParser.sharedInstance
    let previewManager = PreviewManager()
    var sections: [[FBFile]] = []
//    var allowEditing: Bool = false

    // Search controller
    var filteredFiles = [FBFile]()
    let searchController: UISearchController = {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchBar.searchBarStyle = .minimal
        searchController.searchBar.backgroundColor = UIColor.white
        searchController.dimsBackgroundDuringPresentation = false
        return searchController
    }()
    
    private let fileCell = "FileCell"
    
    
    //MARK: Lifecycle
    convenience init (initialPath: URL) {
        self.init(nibName: "FileBrowser", bundle: Bundle(for: FileListViewController.self))
        self.edgesForExtendedLayout = UIRectEdge()
        
        // Set initial path
        self.initialPath = initialPath
        self.title = initialPath.lastPathComponent
        
        // Set search controller delegates
        searchController.searchResultsUpdater = self
        searchController.searchBar.delegate = self
        searchController.delegate = self
        
        resetNavigationItem()
    }
    
    deinit{
        if #available(iOS 9.0, *) {
            searchController.loadViewIfNeeded()
        } else {
            searchController.loadView()
        }
    }
    
    //MARK: UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        prepareData()
        
        // Set search bar
        tableView.tableHeaderView = searchController.searchBar
        tableView.tableFooterView = UIView()
        tableView.estimatedRowHeight = 60
        let multipleSelectionValue = multipleSelection
        self.multipleSelection = multipleSelectionValue
        // Register for 3D touch
        self.registerFor3DTouch()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Scroll to hide search bar
        self.tableView.contentOffset = CGPoint(x: 0, y: searchController.searchBar.frame.size.height)
        
        // Make sure navigation bar is visible
        self.navigationController?.isNavigationBarHidden = false
    }
    
    //MARK: Private
    func prepareData() {
        // Prepare data
        if let initialPath = initialPath {
            files = parser.filesForDirectory(initialPath)
            indexFiles()
        }
    }
    
    func indexFiles() {
        let selector: Selector = #selector(getter: FBFile.displayName)
        sections = Array(repeating: [], count: collation.sectionTitles.count)
        if let sortedObjects = collation.sortedArray(from: files, collationStringSelector: selector) as? [FBFile]{
            for object in sortedObjects {
                let sectionNumber = collation.section(for: object, collationStringSelector: selector)
                sections[sectionNumber].append(object)
            }
        }
    }
    
    func fileForIndexPath(_ indexPath: IndexPath) -> FBFile {
        var file: FBFile
        if searchController.isActive {
            file = filteredFiles[indexPath.row]
        }
        else {
            file = sections[indexPath.section][indexPath.row]
        }
        return file
    }
    
    func filterContentForSearchText(_ searchText: String) {
        filteredFiles = files.filter({ (file: FBFile) -> Bool in
            return file.displayName.lowercased().contains(searchText.lowercased())
        })
        tableView.reloadData()
    }
    
    @objc private func onTouchDoneItem(_ item: UINavigationItem) {
        if let indexPathsForSelectedRows = self.tableView.indexPathsForSelectedRows {
            let files = indexPathsForSelectedRows.compactMap({ fileForIndexPath($0) })
            self.didSelectFiles?(files)
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    private func resetNavigationItem() {
        if multipleSelection && tableView.isEditing {
            let downButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(FileListViewController.onTouchDoneItem(_:)))
            
            let dismissButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(FileListViewController.onTouchExitEditingModeButton(button:)))
            self.navigationItem.rightBarButtonItems = [downButton, dismissButton]
        } else {
            let dismissButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(FileListViewController.dismiss(button:)))
            self.navigationItem.rightBarButtonItems = [dismissButton]
        }
    }

    @objc private func dismiss(button: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc private func onTouchExitEditingModeButton(button: UIBarButtonItem) {
        self.tableView.setEditing(false, animated: true)
        resetNavigationItem()
    }
}

extension FileListViewController: UITableViewDataSource, UITableViewDelegate {
    
    //MARK: UITableViewDataSource, UITableViewDelegate
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if searchController.isActive {
            return 1
        }
        return sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if searchController.isActive {
            return filteredFiles.count
        }
        return sections[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell
        if let reuseCell = tableView.dequeueReusableCell(withIdentifier: fileCell) {
            cell = reuseCell
        } else {
            cell = UITableViewCell(style: .default, reuseIdentifier: fileCell)
            cell.selectionStyle = .blue
            cell.textLabel?.lineBreakMode = .byWordWrapping
            cell.textLabel?.numberOfLines = 0
        }
        
        let selectedFile = fileForIndexPath(indexPath)
        cell.textLabel?.text = selectedFile.displayName
        cell.imageView?.image = selectedFile.type.image()
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedFile = fileForIndexPath(indexPath)
        
        if searchController.isActive {
            if let didSelectFiles = didSelectFiles {
                didSelectFiles([fileForIndexPath(indexPath)])
                searchController.dismiss(animated: true, completion: nil)
                self.dismiss(animated: true, completion: nil)
            }
        }
        
        if selectedFile.isDirectory {
            let fileListViewController = FileListViewController(initialPath: selectedFile.filePath)
            fileListViewController.didSelectFiles = didSelectFiles
            self.navigationController?.pushViewController(fileListViewController, animated: true)
        }
        else {
            if self.multipleSelection {
                if !tableView.isEditing {
                    tableView.setEditing(true, animated: true)
                    resetNavigationItem()
                }
            } else {
                if let didSelectFiles = didSelectFiles {
                    didSelectFiles([fileForIndexPath(indexPath)])
                    self.dismiss(animated: true, completion: nil)
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if searchController.isActive {
            return nil
        }
        if sections[section].count > 0 {
            return collation.sectionTitles[section]
        }
        else {
            return nil
        }
    }
    
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        if searchController.isActive {
            return nil
        }
        return collation.sectionIndexTitles
    }
    
    func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        if searchController.isActive {
            return 0
        }
        return collation.section(forSectionIndexTitle: index)
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if (editingStyle == UITableViewCell.EditingStyle.delete) {
            let selectedFile = fileForIndexPath(indexPath)
            selectedFile.delete()
            
            prepareData()
            tableView.reloadSections([indexPath.section], with: UITableView.RowAnimation.automatic)
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
//        return allowEditing
        let selectedFile = fileForIndexPath(indexPath)
        return !selectedFile.isDirectory
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
}
