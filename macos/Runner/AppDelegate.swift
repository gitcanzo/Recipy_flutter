import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // Channel name must match the one registered in macos_file_handler.dart.
  // A mismatch causes method calls to be silently dropped on both sides.
  private let channelName = "com.gcanz.recipy/file_open"

  // The channel is created in applicationDidFinishLaunching once the Flutter
  // engine is up. Held as a property so application(_:openFile:) can use it.
  private var methodChannel: FlutterMethodChannel?

  // If macOS delivers a file-open event before the Flutter engine is ready
  // (e.g. the user double-clicked a .recipy file to cold-launch the app),
  // we store the path here and deliver it once the channel exists.
  private var pendingFilePath: String?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    // Retrieve the FlutterViewController from the main window so we can attach
    // the MethodChannel to its engine's binary messenger.
    if let flutterVC = mainFlutterWindow?.contentViewController as? FlutterViewController {
      methodChannel = FlutterMethodChannel(
        name: channelName,
        binaryMessenger: flutterVC.engine.binaryMessenger
      )
    }

    // Let the superclass finish its own setup (registers plugins, etc.).
    super.applicationDidFinishLaunching(notification)

    // Now that the channel is registered, deliver any file that arrived
    // during the cold-start window before the engine was ready.
    if let path = pendingFilePath {
      methodChannel?.invokeMethod("openFile", arguments: path)
      pendingFilePath = nil
    }
  }

  // Called by macOS when the user double-clicks a .recipy file in Finder,
  // or when the file is dropped onto the Dock icon.
  // This is the legacy single-file variant — still called on older macOS.
  // Returning true tells macOS we accepted responsibility for the file.
  override func application(_ sender: NSApplication, openFile filename: String) -> Bool {
    deliverFilePath(filename)
    return true
  }

  // Called by macOS 12+ (and sometimes earlier) instead of application(_:openFile:)
  // when the app is registered as a document handler via CFBundleDocumentTypes.
  // We handle all URLs in the array, but in practice Recipy only opens one at a time.
  override func application(_ sender: NSApplication, openFiles filenames: [String]) {
    for filename in filenames {
      deliverFilePath(filename)
    }
  }

  // Shared delivery logic used by both file-open delegate methods above.
  // Routes the path through the MethodChannel if the Flutter engine is ready,
  // or parks it in pendingFilePath for delivery once the engine finishes launching.
  private func deliverFilePath(_ path: String) {
    if let channel = methodChannel {
      // Engine is ready — deliver the path to Dart immediately.
      channel.invokeMethod("openFile", arguments: path)
    } else {
      // Engine not ready yet (cold launch). Store the path; it will be
      // delivered in applicationDidFinishLaunching once the channel exists.
      // Only the most recent path is kept — Recipy is single-window.
      pendingFilePath = path
    }
  }

  // Close the app when the last window is closed (standard macOS behaviour
  // for document-style apps, but Recipy has only one window).
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
