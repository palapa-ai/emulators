import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var drop: FlutterMethodChannel?
  private var romExtensions: Set<String> = []

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.setContentSize(NSSize(width: 1280, height: 720))
    self.styleMask.insert(.resizable)
    self.collectionBehavior.insert(.fullScreenPrimary)
    self.minSize = NSSize(width: 900, height: 600)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "emulators_example/drop",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    // Which extensions count as a cartridge is Dart's to decide; drag feedback
    // has to answer synchronously, so the list is pushed up front.
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "accept":
        guard let extensions = call.arguments as? [String] else {
          result(FlutterMethodNotImplemented)
          return
        }
        self?.romExtensions = Set(extensions.map { $0.lowercased() })
        result(nil)
      case "fullscreen":
        self?.toggleFullScreen(nil)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    drop = channel

    registerForDraggedTypes([.fileURL])

    super.awakeFromNib()
  }

  private func cartridges(in sender: NSDraggingInfo) -> [String] {
    let urls =
      sender.draggingPasteboard.readObjects(
        forClasses: [NSURL.self],
        options: [.urlReadingFileURLsOnly: true]
      ) as? [URL] ?? []

    return
      urls
      .filter { romExtensions.contains($0.pathExtension.lowercased()) }
      .map { $0.path }
  }

  @objc func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    let accepted = !cartridges(in: sender).isEmpty
    drop?.invokeMethod("over", arguments: accepted)
    return accepted ? .copy : []
  }

  @objc func draggingExited(_ sender: NSDraggingInfo?) {
    drop?.invokeMethod("over", arguments: false)
  }

  @objc func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    drop?.invokeMethod("over", arguments: false)

    let paths = cartridges(in: sender)
    guard !paths.isEmpty else { return false }

    drop?.invokeMethod("dropped", arguments: paths)
    return true
  }
}
