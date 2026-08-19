import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.setContentSize(NSSize(width: 1280, height: 720))
    self.styleMask.insert(.resizable)
    self.collectionBehavior.insert(.fullScreenPrimary)
    self.minSize = NSSize(width: 900, height: 600)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
