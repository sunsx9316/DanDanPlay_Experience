import Cocoa
import FlutterMacOS
import dandanplay_native

@NSApplicationMain
class AppDelegate: FlutterAppDelegate {
    
    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    override func applicationDidFinishLaunching(_ notification: Notification) {
        
    }
    
    @IBAction func onClickSettingMenu(_ sender: NSMenuItem) {
        
        if let vc = self.mainFlutterWindow.contentViewController as? MessageViewController {
            vc.push("setting")
        }
        
        mainFlutterWindow.makeKeyAndOrderFront(nil)
    }
    
}
