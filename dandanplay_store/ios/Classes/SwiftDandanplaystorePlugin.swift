import Flutter
import UIKit

public class SwiftDandanplaystorePlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        #if os(iOS)
        let channel = FlutterMethodChannel(name: "dandanplaystore", binaryMessenger: registrar.messenger())
        #else
        let channel = FlutterMethodChannel(name: "dandanplaystore", binaryMessenger: registrar.messenger)
        #endif
        let instance = SwiftDandanplaystorePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        
        guard let data = call.arguments as? [String : Any],
            let key = data["key"] as? String else {
                result(FlutterError(code: "999", message: "数据格式不正确", details: nil))
                return
        }
        
        let id = data["id"] as? String ?? "com.ddplay.default"
        
        switch call.method {
        case "setBool":
            var success = true
            if let value = data["value"] as? Bool {
                success = Store.shared.set(value, forKey: key, groupId: id)
            } else {
                Store.shared.remove(key, groupId: id)
            }
            
            result(success)
        case "getBool":
            let value: Bool = Store.shared.value(forKey: key, groupId: id)
            result(value)
        case "setInt":
            var success = true
            if let value = data["value"] as? Int {
                success = Store.shared.set(value, forKey: key, groupId: id)
            } else {
                Store.shared.remove(key, groupId: id)
            }
            
            result(success)
        case "getInt":
            let value: Int = Store.shared.value(forKey: key, groupId: id)
            result(value)
        case "setDouble":
            var success = true
            if let value = data["value"] as? Double {
                success = Store.shared.set(value, forKey: key, groupId: id)
            } else {
                Store.shared.remove(key, groupId: id)
            }
            
            result(success)
        case "getDouble":
            let value: Double = Store.shared.value(forKey: key, groupId: id)
            result(value)
        case "setString":
            var success = true
            if let value = data["value"] as? String {
                success = Store.shared.set(value, forKey: key, groupId: id)
            } else {
                Store.shared.remove(key, groupId: id)
            }
            
            result(success)
        case "getString":
            let value: String? = Store.shared.value(forKey: key, groupId: id)
            result(value)
        case "contains":
            result(Store.shared.contains(key, groupId: id))
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
