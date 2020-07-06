import Cocoa
import FlutterMacOS

public class DandanplayfilepickerPlugin: NSObject, FlutterPlugin {
    
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
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "dandanplay.flutter.plugins.file_picker", binaryMessenger: registrar.messenger)
        registrar.addMethodCallDelegate(DandanplayfilepickerPlugin(), channel: channel)
    }
    
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if let resultCallBack = self.resultCallBack {
            let error = FlutterError(code: "multiple_request", message: "Cancelled by a second request", details: nil)
            resultCallBack(error)
            self.resultCallBack = nil;
            return;
        }
        
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
    
    private func resolvePickDocumentWithMultipleSelection(_ multipleSelection: Bool,
                                                          fileTypes: [String]? = nil) {
        let panel = NSOpenPanel();
        panel.allowedFileTypes = fileTypes
        panel.allowsMultipleSelection = multipleSelection
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        weak var weakPanel = panel
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window) { [weak self] (result) in
                guard let self = self else {
                    return
                }
                
                if result == .OK {
                    let paths = weakPanel?.urls.compactMap({ $0.path }) ?? []
                    self.resultCallBack?(paths)
                }
                
                self.resultCallBack = nil
            }
        }
    }
}
