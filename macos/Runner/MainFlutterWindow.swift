import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private let channelName = "com.gcanz.recipy/file_open"
  private var methodChannel: FlutterMethodChannel?
  private var pendingFilePaths: [String] = []
  // Set to true once windowDidBecomeKey fires and Dart's handler is ready.
  private var dartIsReady = false

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
      let path = fileURL.path
      if dartIsReady {
        // App already running — deliver immediately on the next run loop tick.
        DispatchQueue.main.async {
          self.methodChannel?.invokeMethod("openFile", arguments: path)
        }
      } else {
        // Cold launch — queue until Dart registers its handler.
        pendingFilePaths.append(path)
      }
    }
  }

  // Called once when the window first becomes key — signals that Dart's
  // initState has run and the method call handler is registered.
  @objc func windowDidBecomeKey(_ notification: Notification) {
    NotificationCenter.default.removeObserver(
      self,
      name: NSWindow.didBecomeKeyNotification,
      object: self
    )
    // Wait for Dart's channel.setMethodCallHandler to complete.
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      self.dartIsReady = true
      self.deliverPendingPaths()
    }
  }

  // Delivers all queued cold-launch paths once Dart is ready.
  private func deliverPendingPaths() {
    guard !pendingFilePaths.isEmpty, let channel = methodChannel else { return }
    let paths = pendingFilePaths
    pendingFilePaths = []
    for path in paths {
      channel.invokeMethod("openFile", arguments: path)
    }
  }
}
