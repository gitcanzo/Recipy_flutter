import Cocoa
import FlutterMacOS

@main
class AppDelegate: NSObject, NSApplicationDelegate {
  // Channel name must match the one registered in macos_file_handler.dart.
  private let channelName = "com.gcanz.recipy/file_open"

  // Connected by the MainMenu nib — gives us access to the Flutter engine.
  @IBOutlet var mainFlutterWindow: MainFlutterWindow?

  // Set once the Flutter engine is ready.
  private var methodChannel: FlutterMethodChannel?

  // Paths queued before the Flutter engine is ready (cold launch).
  private var pendingFilePaths: [String] = []

  // applicationWillFinishLaunching fires before the Apple Event system
  // delivers any queued file-open events, so we register our handler here.
  func applicationWillFinishLaunching(_ notification: Notification) {
    NSLog("[Recipy] applicationWillFinishLaunching — registering Apple Event handler")
    NSAppleEventManager.shared().setEventHandler(
      self,
      andSelector: #selector(handleOpenDocuments(_:replyEvent:)),
      forEventClass: AEEventClass(kCoreEventClass),
      andEventID: AEEventID(kAEOpenDocuments)
    )
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSLog("[Recipy] applicationDidFinishLaunching — mainFlutterWindow: \(String(describing: mainFlutterWindow))")
    // Attach the MethodChannel to the Flutter engine's binary messenger.
    // MainFlutterWindow is set up by the nib before this method is called.
    if let flutterVC = mainFlutterWindow?.contentViewController as? FlutterViewController {
      NSLog("[Recipy] applicationDidFinishLaunching — channel created")
      methodChannel = FlutterMethodChannel(
        name: channelName,
        binaryMessenger: flutterVC.engine.binaryMessenger
      )
    } else {
      NSLog("[Recipy] applicationDidFinishLaunching — WARNING: could not create channel, flutterVC is nil")
    }

    // Deliver any file paths that arrived before the engine was ready.
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

  // Handles kAEOpenDocuments — sent by macOS when the user double-clicks
  // a .recipy file in Finder or drops one onto the Dock icon.
  @objc func handleOpenDocuments(_ event: NSAppleEventDescriptor, replyEvent: NSAppleEventDescriptor) {
    guard let fileList = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject)) else { return }

    let count = fileList.numberOfItems
    for i in 1...max(1, count) {
      guard let fileDesc = fileList.atIndex(i),
            let fileURL = fileDesc.fileURLValue else { continue }
      NSLog("[Recipy] handleOpenDocuments: \(fileURL.path)")
      deliverFilePath(fileURL.path)
    }
  }

  // Sends the path to Dart via MethodChannel, or queues it if the engine
  // is not ready yet (cold launch before applicationDidFinishLaunching).
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
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
