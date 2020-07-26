//
//  FileBrowser.swift
//  FileBrowser
//
//  Created by Roy Marmelstein on 14/02/2016.
//  Copyright © 2016 Roy Marmelstein. All rights reserved.
//

import UIKit

/// File browser containing navigation controller.
@objcMembers
open class FileBrowser: UINavigationController {
    
    let parser = FileParser.sharedInstance
    
    var fileList: FileListViewController?
    
    var documentTypes: [String]? {
        didSet {
            parser.documentTypes = documentTypes
        }
    }
    
    /// Override default preview and actionsheet behaviour in favour of custom file handling.
    open var didSelectFiles: (([FBFile]) -> ())? {
        didSet {
            fileList?.didSelectFiles = didSelectFiles
        }
    }
    
    open var multipleSelection = false {
        didSet {
            fileList?.multipleSelection = multipleSelection
        }
    }
    
    open var dismissCallBack: (() -> Void)?

    public convenience init() {
        let parser = FileParser.sharedInstance
        let path = parser.documentsURL()
        self.init(initialPath: path)
    }

    /// Initialise file browser.
    ///
    /// - Parameters:
    ///   - initialPath: NSURL filepath to containing directory.
    public convenience init(initialPath: URL? = nil) {
        
        let validInitialPath = initialPath ?? FileParser.sharedInstance.documentsURL()
        
        let fileListViewController = FileListViewController(initialPath: validInitialPath)
        self.init(rootViewController: fileListViewController)
        self.view.backgroundColor = UIColor.white
        self.fileList = fileListViewController
    }
    
    deinit {
        self.dismissCallBack?()
    }
}
