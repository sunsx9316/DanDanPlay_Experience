//
//  FileBrowerViewController.swift
//  dandanplayfilepicker
//
//  Created by JimHuang on 2020/7/26.
//

import UIKit
import CoreServices

public protocol FileBrowerManagerDelegate: class {
    func didSelectedPaths(manager: FileBrowerManager, urls: [URL])
    func didDismiss(manager: FileBrowerManager)
    func didCancel(manager: FileBrowerManager)
}

public extension FileBrowerManagerDelegate {
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
            let vc = UIDocumentPickerViewController(documentTypes: fileTypes ?? [kUTTypeItem as String], in: .open)
            vc.allowsMultipleSelection = multipleSelection
            vc.delegate = self
            if #available(iOS 13.0, *) {
                vc.shouldShowFileExtensions = true
            }
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
                
                let paths = aFiles.compactMap { (file) -> URL? in
                    if file.isDirectory {
                        return nil
                    }
                    
                    return file.filePath
                }

                self.delegate?.didSelectedPaths(manager: self, urls: paths)
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
        self.delegate?.didSelectedPaths(manager: self, urls: [url])
    }
    
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        controller.dismiss(animated: true, completion: nil)
        self.delegate?.didSelectedPaths(manager: self, urls: urls)
    }
    
    public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        self.delegate?.didCancel(manager: self)
    }
}
