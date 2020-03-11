import Cocoa
import FlutterMacOS

public class DandanplayNativePlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "dandanplay_native", binaryMessenger: registrar.messenger)
        let instance = DandanplayNativePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        
    }
    
}
