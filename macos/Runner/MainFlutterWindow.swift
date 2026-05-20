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

    // Create the MethodChannel now that the engine exists.
    methodChannel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )

    // Register for the kAEOpenDocuments Apple Event — sent by macOS when
    // the user double-clicks a .recipy file in Finder or drops it on the Dock.
    // We register here because awakeFromNib is called before the app finishes
    // launching, giving us time to catch cold-launch file-open events.
    NSAppleEventManager.shared().setEventHandler(
      self,
      andSelector: #selector(handleOpenDocuments(_:replyEvent:)),
      forEventClass: AEEventClass(kCoreEventClass),
      andEventID: AEEventID(kAEOpenDocuments)
    )

    // Observe our own window becoming key — at that point Flutter's Dart
    // isolate has started and registered its method call handler, so it
    // is safe to deliver pending cold-launch file paths.
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(windowDidBecomeKey(_:)),
      name: NSWindow.didBecomeKeyNotification,
      object: self
    )

    super.awakeFromNib()
  }

  // Receives the kAEOpenDocuments Apple Event from Finder.
  @objc func handleOpenDocuments(_ event: NSAppleEventDescriptor, replyEvent: NSAppleEventDescriptor) {
    guard let fileList = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject)) else { return }
    let count = fileList.numberOfItems
    for i in 1...max(1, count) {
      guard let fileDesc = fileList.atIndex(i),
            let fileURL = fileDesc.fileURLValue else { continue }
      // Queue the path — deliver once the Flutter widget tree is ready.
      pendingFilePaths.append(fileURL.path)
    }
    // Attempt delivery immediately in case the engine is already running
    // (e.g. the file was opened while the app was already open).
    deliverPendingPaths()
  }

  // Called when the window becomes key — Flutter's Dart isolate is now
  // running and the method call handler is registered on the Dart side.
  @objc func windowDidBecomeKey(_ notification: Notification) {
    // Unregister so we only do the initial delivery once.
    NotificationCenter.default.removeObserver(
      self,
      name: NSWindow.didBecomeKeyNotification,
      object: self
    )
    // Small delay to ensure Dart's channel.setMethodCallHandler has run.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      self.deliverPendingPaths()
    }
  }

  // Delivers all queued file paths to Dart via the MethodChannel.
  private func deliverPendingPaths() {
    guard !pendingFilePaths.isEmpty, let channel = methodChannel else { return }
    let paths = pendingFilePaths
    pendingFilePaths = []
    for path in paths {
      channel.invokeMethod("openFile", arguments: path)
    }
  }
}
