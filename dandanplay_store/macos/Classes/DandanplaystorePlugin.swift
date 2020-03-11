import Cocoa
import FlutterMacOS
import MMKV

public class DandanplaystorePlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "dandanplaystore", binaryMessenger: registrar.messenger)
        let instance = DandanplaystorePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        MMKV.setLogLevel(MMKVLogNone)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        
        guard let data = call.arguments as? [String : Any],
            let key = data["key"] as? String else {
                result(FlutterError(code: "999", message: "数据格式不正确", details: nil))
                return
        }
        
        switch call.method {
        case "setBool":
            var success = true
            if let value = data["value"] as? Bool {
                success = MMKV.default().set(value, forKey: key)
            } else {
                MMKV.default().removeValue(forKey: key)
            }
            
            result(success)
        case "getBool":
            result(MMKV.default().bool(forKey: key))
        case "setInt":
            var success = true
            if let value = data["value"] as? Int32 {
                success = MMKV.default().set(value, forKey: key)
            } else {
                MMKV.default().removeValue(forKey: key)
            }
            
            result(success)
        case "getInt":
            result(MMKV.default().int32(forKey: key))
        case "setDouble":
            var success = true
            if let value = data["value"] as? Double {
                success = MMKV.default().set(value, forKey: key)
            } else {
                MMKV.default().removeValue(forKey: key)
            }
            
            result(success)
        case "getDouble":
            result(MMKV.default().double(forKey: key))
        case "setString":
            var success = true
            if let value = data["value"] as? String {
                success = MMKV.default().set(value, forKey: key)
            } else {
                MMKV.default().removeValue(forKey: key)
            }
            
            result(success)
        case "getString":
            result(MMKV.default().string(forKey: key))
        case "contains":
            result(MMKV.default().contains(key: key))
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
}
