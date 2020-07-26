//
//  FileBrowerViewController.swift
//  dandanplayfilepicker
//
//  Created by JimHuang on 2020/7/26.
//

import UIKit
import CoreServices

public protocol FileBrowerManagerDelegate: class {
    func didSelectedPaths(manager: FileBrowerManager, paths: [String])
    func didDismiss(manager: FileBrowerManager)
    func didCancel(manager: FileBrowerManager)
}

extension FileBrowerManagerDelegate {
    func didSelectedPaths(manager: FileBrowerManager, paths: [String]) {}
    func didDismiss(manager: FileBrowerManager) {}
    func didCancel(manager: FileBrowerManager) {}
}

open class FileBrowerManager: NSObject {
    
    open weak var delegate: FileBrowerManagerDelegate?
    open var containerViewController = UIViewController()
    
    private var multipleSelection = false
    private var fileTypes: [String]? = nil
    
    public init(multipleSelection: Bool, fileTypes: [String]? = nil) {
        super.init()
        self.multipleSelection = multipleSelection
        self.fileTypes = fileTypes
        self.containerViewController = createContainerViewController()
    }
    
    private func createContainerViewController() -> UIViewController {
        if #available(iOS 11.0, *) {
            let vc = UIDocumentPickerViewController(documentTypes: fileTypes ?? [kUTTypeItem as String], in: .import)
            vc.allowsMultipleSelection = multipleSelection
            vc.delegate = self
            return vc
        } else {
            let vc = FileBrowser()
            self.containerViewController = vc
            vc.documentTypes = fileTypes
            vc.multipleSelection = multipleSelection
            vc.didSelectFiles = { [weak self] (aFiles) in
                guard let self = self else {
                    return
                }
                
                let paths = aFiles.compactMap { (file) -> String? in
                    if file.isDirectory {
                        return nil
                    }
                    
                    return file.filePath.path
                }

                self.delegate?.didSelectedPaths(manager: self, paths: paths)
            }
            
            vc.dismissCallBack = { [weak self] in
                guard let self = self else {
                    return
                }
                
                self.delegate?.didDismiss(manager: self)
            }
            
            return vc
        }
    }
}


extension FileBrowerManager: UIDocumentPickerDelegate {
    //MARK: Delegates
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        controller.dismiss(animated: true, completion: nil)
        self.delegate?.didSelectedPaths(manager: self, paths: [url.path])
    }
    
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        controller.dismiss(animated: true, completion: nil)
        let paths = urls.compactMap({ $0.path })
        self.delegate?.didSelectedPaths(manager: self, paths: paths)
    }
    
    public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        self.delegate?.didCancel(manager: self)
    }
}