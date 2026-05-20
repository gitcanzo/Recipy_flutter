import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // Channel name must match the one registered in macos_file_handler.dart.
  private let channelName = "com.gcanz.recipy/file_open"

  // Set once the Flutter engine is ready in applicationDidFinishLaunching.
  private var methodChannel: FlutterMethodChannel?

  // Paths collected before the Flutter engine is ready (cold launch via
  // Finder double-click). Delivered once the channel is up.
  private var pendingFilePaths: [String] = []

  override func applicationDidFinishLaunching(_ notification: Notification) {
    // super must run first — it creates MainFlutterWindow and starts the engine.
    super.applicationDidFinishLaunching(notification)

    // Wire up the MethodChannel now that the engine messenger exists.
    if let flutterVC = mainFlutterWindow?.contentViewController as? FlutterViewController {
      methodChannel = FlutterMethodChannel(
        name: channelName,
        binaryMessenger: flutterVC.engine.binaryMessenger
      )
    }

    // Register for the kAEOpenDocuments Apple Event directly.
    // macOS sends this event when the user double-clicks a registered file type.
    // The NSApplication delegate methods (openFile/openFiles) are not reliably
    // called for cold launches — the Apple Event is the authoritative source.
    NSAppleEventManager.shared().setEventHandler(
      self,
      andSelector: #selector(handleOpenDocumentsEvent(_:replyEvent:)),
      forEventClass: AEEventClass(kCoreEventClass),
      andEventID: AEEventID(kAEOpenDocuments)
    )

    // Deliver any paths that arrived before the engine was ready.
    // Async so the Flutter widget tree has one run-loop cycle to settle first.
    let pending = pendingFilePaths
    pendingFilePaths = []
    if !pending.isEmpty {
      DispatchQueue.main.async {
        for path in pending {
          self.methodChannel?.invokeMethod("openFile", arguments: path)
        }
      }
    }
  }

  // Handles the kAEOpenDocuments Apple Event sent by macOS when the user
  // double-clicks a .recipy file in Finder or drops it onto the Dock icon.
  // This is the most reliable cross-version mechanism; the NSApplicationDelegate
  // openFile/openFiles methods are not consistently called on cold launches.
  @objc func handleOpenDocumentsEvent(_ event: NSAppleEventDescriptor, replyEvent: NSAppleEventDescriptor) {
    // The direct object of the event is a list of file aliases.
    guard let fileList = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject)) else { return }

    // Iterate over all items in the list (usually just one for Recipy).
    let count = fileList.numberOfItems
    for i in 1...max(1, count) {
      guard let fileDesc = fileList.atIndex(i),
            let fileURL = fileDesc.fileURLValue else { continue }
      let path = fileURL.path
      NSLog("[Recipy] handleOpenDocumentsEvent: \(path)")
      deliverFilePath(path)
    }
  }

  // Routes a file path to Dart via the MethodChannel if the engine is ready,
  // or queues it in pendingFilePaths for delivery after launch completes.
  private func deliverFilePath(_ path: String) {
    if let channel = methodChannel {
      // Engine is ready — deliver immediately on the main thread.
      DispatchQueue.main.async {
        channel.invokeMethod("openFile", arguments: path)
      }
    } else {
      // Cold launch: engine not ready yet. Park the path; it will be
      // sent in applicationDidFinishLaunching once the channel exists.
      pendingFilePaths.append(path)
    }
  }

  // Quit when the last window closes — standard for single-window document apps.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
