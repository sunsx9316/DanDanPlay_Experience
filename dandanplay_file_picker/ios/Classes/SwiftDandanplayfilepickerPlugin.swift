import Flutter
import UIKit
import CoreServices

public class SwiftDandanplayfilepickerPlugin: NSObject, FlutterPlugin {
    
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
    private var manager: FileBrowerManager?
    
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
    
    //MARK: Private
    private func resolvePickDocumentWithMultipleSelection(_ multipleSelection: Bool, fileTypes: [String]? = nil) {
        let manager = FileBrowerManager(multipleSelection: multipleSelection, fileTypes: fileTypes)
        manager.delegate = self
        self.manager = manager
        self.rootVC?.present(manager.containerViewController, animated: true, completion: nil)
    }
}

extension SwiftDandanplayfilepickerPlugin: FileBrowerManagerDelegate {
    public func didSelectedPaths(manager: FileBrowerManager, paths: [String]) {
        self.resultCallBack?(paths)
        self.resultCallBack = nil
        self.manager = nil
    }
    
    public func didDismiss(manager: FileBrowerManager) {
        self.resultCallBack = nil
        self.manager = nil
    }
    
    public func didCancel(manager: FileBrowerManager) {
        self.resultCallBack = nil
        self.manager = nil
    }
}
