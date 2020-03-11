import Flutter
import UIKit

public class SwiftDandanplayNativePlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
//    let channel = FlutterMethodChannel(name: "dandanplay_native", binaryMessenger: registrar.messenger())
//    let instance = SwiftDandanplayNativePlugin()
//    registrar.addMethodCallDelegate(instance, channel: channel)
    
    let channel = FlutterBasicMessageChannel(name: "com.dandanplay/message", binaryMessenger: registrar.messenger(), codec: FlutterJSONMessageCodec());
    channel.setMessageHandler { (obj, reply) in
        if let obj = obj as? [String : Any] {
            DispatchQueue.main.async {
                MessageManager.shared.parseMessage(obj)
            }
        }
    }
  }
    
}
