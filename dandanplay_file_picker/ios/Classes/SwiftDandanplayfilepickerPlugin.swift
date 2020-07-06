import Flutter
import UIKit
import CoreServices

public class SwiftDandanplayfilepickerPlugin: NSObject, UIDocumentPickerDelegate, UINavigationControllerDelegate, FlutterPlugin {
    
    enum FileType: Int {
        case file
        case video
        case image
        
        var typeString: String {
            switch self {
            case .file:
                return kUTTypeItem as String
            case .video:
                return kUTTypeMovie as String
            case .image:
                return kUTTypeImage as String
            }
        }
    }
    
    private var resultCallBack: FlutterResult?
    private var rootVC: UIViewController? {
        return UIApplication.shared.delegate?.window??.rootViewController
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "dandanplay.flutter.plugins.file_picker", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(SwiftDandanplayfilepickerPlugin(), channel: channel)
    }
    
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        assert(self.resultCallBack == nil, "Cancelled by a second request")
        
        self.resultCallBack = result
        
        if call.method == "pickFiles" {
            let arguments = call.arguments as? [String : Any]
            let isMultiplePick = arguments?["multipleSelection"] as? Bool ?? false
            if let fileTypeRawValue = arguments?["pickType"] as? Int,
                let fileType = FileType(rawValue: fileTypeRawValue) {
                self.resolvePickDocumentWithMultipleSelection(isMultiplePick, fileTypes: [fileType.typeString])
            } else {
                self.resolvePickDocumentWithMultipleSelection(isMultiplePick)
            }
        }
    }
    
    //MARK: Delegates
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        controller.dismiss(animated: true, completion: nil)
        self.resultCallBack?(url.path)
        self.resultCallBack = nil
    }
    
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        controller.dismiss(animated: true, completion: nil)
        let paths = urls.compactMap({ $0.path })
        self.resultCallBack?(paths)
        self.resultCallBack = nil
    }
    
    public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        self.resultCallBack = nil
    }
    
    //MARK: Private
    private func resolvePickDocumentWithMultipleSelection(_ multipleSelection: Bool, fileTypes: [String]? = nil) {
        
        if #available(iOS 11.0, *) {
            let vc = UIDocumentPickerViewController(documentTypes: fileTypes ?? [kUTTypeItem as String], in: .import)
            vc.allowsMultipleSelection = multipleSelection
            vc.delegate = self
            self.rootVC?.present(vc, animated: true, completion: nil)
        } else {
            let vc = FileBrowser()
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

                self.resultCallBack?(paths)
                self.resultCallBack = nil
            }
            
            vc.dismissCallBack = { [weak self] in
                guard let self = self else {
                    return
                }
                
                self.resultCallBack = nil
            }
            self.rootVC?.present(vc, animated: true, completion: nil)
        }
    }
}
