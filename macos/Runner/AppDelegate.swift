import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // Channel name must match the one registered in macos_file_handler.dart.
  private let channelName = "com.gcanz.recipy/file_open"

  // Set once the Flutter engine is ready.
  private var methodChannel: FlutterMethodChannel?

  // Paths queued before the Flutter engine is ready (cold launch).
  private var pendingFilePaths: [String] = []

  // applicationWillFinishLaunching fires before the Apple Event system
  // delivers any queued file-open events. Registering our handler here
  // ensures we intercept kAEOpenDocuments before AppKit tries to call
  // applicationDidFinishLaunching with a file path baked in (which was
  // causing "unrecognized selector" crashes in our override).
  override func applicationWillFinishLaunching(_ notification: Notification) {
    super.applicationWillFinishLaunching(notification)

    NSAppleEventManager.shared().setEventHandler(
      self,
      andSelector: #selector(handleOpenDocuments(_:replyEvent:)),
      forEventClass: AEEventClass(kCoreEventClass),
      andEventID: AEEventID(kAEOpenDocuments)
    )
  }

  // applicationDidFinishLaunching: let the superclass run first so the
  // Flutter engine and MainFlutterWindow are fully initialised, then
  // attach the MethodChannel and flush any pending file paths.
  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)

    // Attach the channel to the engine's binary messenger.
    if let flutterVC = mainFlutterWindow?.contentViewController as? FlutterViewController {
      methodChannel = FlutterMethodChannel(
        name: channelName,
        binaryMessenger: flutterVC.engine.binaryMessenger
      )
    }

    // Deliver any paths that arrived before the engine was ready.
    // Async so the Flutter widget tree has one run-loop cycle to settle.
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

  // Handles the kAEOpenDocuments Apple Event — the authoritative mechanism
  // macOS uses when the user double-clicks a .recipy file in Finder or
  // drops it onto the Dock icon.
  @objc func handleOpenDocuments(_ event: NSAppleEventDescriptor, replyEvent: NSAppleEventDescriptor) {
    guard let fileList = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject)) else { return }

    // fileList is usually a single item but we iterate defensively.
    let count = fileList.numberOfItems
    for i in 1...max(1, count) {
      guard let fileDesc = fileList.atIndex(i),
            let fileURL = fileDesc.fileURLValue else { continue }
      let path = fileURL.path
      NSLog("[Recipy] handleOpenDocuments: \(path)")
      deliverFilePath(path)
    }
  }

  // Sends the file path to Dart via MethodChannel, or queues it if the
  // engine is not ready yet (cold launch before applicationDidFinishLaunching).
  private func deliverFilePath(_ path: String) {
    if let channel = methodChannel {
      DispatchQueue.main.async {
        channel.invokeMethod("openFile", arguments: path)
      }
    } else {
      pendingFilePaths.append(path)
    }
  }

  // Quit when the last window closes — standard for single-window apps.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
