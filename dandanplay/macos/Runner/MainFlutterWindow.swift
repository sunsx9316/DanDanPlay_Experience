import Cocoa
import FlutterMacOS
import dandanplay_native

class MainFlutterWindow: NSWindow {
    override func awakeFromNib() {
        let flutterViewController = MainViewController()
        let windowFrame = self.frame
        self.contentViewController = flutterViewController
        self.setFrame(windowFrame, display: true)
        self.isMovableByWindowBackground = true
        
        super.awakeFromNib()
    }
    
    
}
