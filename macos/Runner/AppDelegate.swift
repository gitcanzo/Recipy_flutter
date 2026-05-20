import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private let channelName = "com.gcanz.recipy/file_open"
  private var methodChannel: FlutterMethodChannel?
  private var pendingFilePaths: [String] = []

  override func applicationWillFinishLaunching(_ notification: Notification) {
    NSLog("[Recipy] applicationWillFinishLaunching")
    // Register for the kAEOpenDocuments Apple Event before macOS delivers
    // any queued file-open events. This is the most reliable interception point.
    NSAppleEventManager.shared().setEventHandler(
      self,
      andSelector: #selector(handleOpenDocuments(_:replyEvent:)),
      forEventClass: AEEventClass(kCoreEventClass),
      andEventID: AEEventID(kAEOpenDocuments)
    )
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    NSLog("[Recipy] applicationDidFinishLaunching")
    // Let FlutterAppDelegate complete its own setup first.
    super.applicationDidFinishLaunching(notification)

    // Create the MethodChannel using the engine that FlutterAppDelegate set up.
    if let flutterVC = mainFlutterWindow?.contentViewController as? FlutterViewController {
      NSLog("[Recipy] channel created")
      methodChannel = FlutterMethodChannel(
        name: channelName,
        binaryMessenger: flutterVC.engine.binaryMessenger
      )
    } else {
      NSLog("[Recipy] WARNING: could not create channel")
    }

    // Listen for the window becoming key so we know Flutter's widget tree
    // is ready — only then do we deliver any cold-launch pending paths.
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(windowDidBecomeKey(_:)),
      name: NSWindow.didBecomeKeyNotification,
      object: mainFlutterWindow
    )

    // If channel is already ready (warm launch), deliver immediately.
    deliverPendingPaths()
  }

  // Called when the main Flutter window becomes key and interactive.
  // By this point Dart has registered its method call handler.
  @objc func windowDidBecomeKey(_ notification: Notification) {
    NSLog("[Recipy] windowDidBecomeKey — delivering pending paths")
    NotificationCenter.default.removeObserver(
      self,
      name: NSWindow.didBecomeKeyNotification,
      object: mainFlutterWindow
    )
    // Short delay to let the Dart method call handler register.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      self.deliverPendingPaths()
    }
  }

  // Handles the kAEOpenDocuments Apple Event from Finder double-click.
  @objc func handleOpenDocuments(_ event: NSAppleEventDescriptor, replyEvent: NSAppleEventDescriptor) {
    guard let fileList = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject)) else {
      NSLog("[Recipy] handleOpenDocuments: no file list")
      return
    }
    let count = fileList.numberOfItems
    NSLog("[Recipy] handleOpenDocuments: \(count) file(s)")
    for i in 1...max(1, count) {
      guard let fileDesc = fileList.atIndex(i),
            let fileURL = fileDesc.fileURLValue else { continue }
      NSLog("[Recipy] handleOpenDocuments: \(fileURL.path)")
      pendingFilePaths.append(fileURL.path)
    }
    deliverPendingPaths()
  }

  // Delivers queued paths via the channel if it exists and paths are waiting.
  private func deliverPendingPaths() {
    guard !pendingFilePaths.isEmpty, let channel = methodChannel else {
      NSLog("[Recipy] deliverPendingPaths: nothing to deliver (paths=\(pendingFilePaths.count) channel=\(methodChannel != nil))")
      return
    }
    let paths = pendingFilePaths
    pendingFilePaths = []
    NSLog("[Recipy] deliverPendingPaths: delivering \(paths.count) path(s)")
    for path in paths {
      channel.invokeMethod("openFile", arguments: path)
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
