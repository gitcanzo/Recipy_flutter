import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private let channelName = "com.gcanz.recipy/file_open"
  private var methodChannel: FlutterMethodChannel?
  private var pendingFilePaths: [String] = []

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    methodChannel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )

    NSAppleEventManager.shared().setEventHandler(
      self,
      andSelector: #selector(handleOpenDocuments(_:replyEvent:)),
      forEventClass: AEEventClass(kCoreEventClass),
      andEventID: AEEventID(kAEOpenDocuments)
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(windowDidBecomeKey(_:)),
      name: NSWindow.didBecomeKeyNotification,
      object: self
    )

    super.awakeFromNib()
  }

  @objc func handleOpenDocuments(_ event: NSAppleEventDescriptor, replyEvent: NSAppleEventDescriptor) {
    guard let fileList = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject)) else { return }
    let count = fileList.numberOfItems
    for i in 1...max(1, count) {
      guard let fileDesc = fileList.atIndex(i),
            let fileURL = fileDesc.fileURLValue else { continue }
      pendingFilePaths.append(fileURL.path)
    }
    deliverPendingPaths()
  }

  @objc func windowDidBecomeKey(_ notification: Notification) {
    NotificationCenter.default.removeObserver(
      self,
      name: NSWindow.didBecomeKeyNotification,
      object: self
    )
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      self.deliverPendingPaths()
    }
  }

  private func deliverPendingPaths() {
    guard !pendingFilePaths.isEmpty, let channel = methodChannel else { return }
    let paths = pendingFilePaths
    pendingFilePaths = []
    for path in paths {
      channel.invokeMethod("openFile", arguments: path)
    }
  }
}
