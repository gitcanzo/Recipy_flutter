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
    // mainFlutterWindow is wired by the nib and available here.
    if let flutterVC = mainFlutterWindow?.contentViewController as? FlutterViewController {
      NSLog("[Recipy] applicationDidFinishLaunching — channel created")
      methodChannel = FlutterMethodChannel(
        name: channelName,
        binaryMessenger: flutterVC.engine.binaryMessenger
      )
    } else {
      NSLog("[Recipy] applicationDidFinishLaunching — WARNING: could not create channel, flutterVC is nil")
    }

    // On a cold launch triggered by a file open, the Flutter widget tree is
    // not ready yet even though the channel exists. We wait for the window to
    // become key (i.e. fully visible and interactive) before delivering pending
    // paths — at that point Dart is guaranteed to be listening.
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(windowDidBecomeKey(_:)),
      name: NSWindow.didBecomeKeyNotification,
      object: mainFlutterWindow
    )

    // Also attempt delivery now for the case where the app was already running
    // (warm launch) — the window is already key so the notification won't fire.
    deliverPendingPaths()
  }

  // Called when the main window becomes key — at this point Flutter's widget
  // tree is fully initialised and ready to receive method channel calls.
  @objc func windowDidBecomeKey(_ notification: Notification) {
    NSLog("[Recipy] windowDidBecomeKey — delivering pending paths")
    // Unregister so we only deliver once per launch.
    NotificationCenter.default.removeObserver(
      self,
      name: NSWindow.didBecomeKeyNotification,
      object: mainFlutterWindow
    )
    // Small delay to let the Dart side register its method call handler.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      self.deliverPendingPaths()
    }
  }

  // Delivers all queued file paths via the MethodChannel.
  private func deliverPendingPaths() {
    guard !pendingFilePaths.isEmpty, let channel = methodChannel else { return }
    let paths = pendingFilePaths
    pendingFilePaths = []
    NSLog("[Recipy] deliverPendingPaths — delivering \(paths.count) path(s)")
    for path in paths {
      channel.invokeMethod("openFile", arguments: path)
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

  // Queues the path and attempts immediate delivery if the channel exists.
  // On cold launch the channel isn't ready yet — delivery happens later
  // in windowDidBecomeKey once Flutter's widget tree is initialised.
  private func deliverFilePath(_ path: String) {
    NSLog("[Recipy] deliverFilePath — queuing: \(path)")
    pendingFilePaths.append(path)
    deliverPendingPaths()
  }

  // Quit when the last window closes — standard for single-window apps.
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
