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
  // Returning true tells macOS we accepted responsibility for the file.
  override func application(_ sender: NSApplication, openFile filename: String) -> Bool {
    if let channel = methodChannel {
      // Engine is ready — deliver the path to Dart immediately.
      channel.invokeMethod("openFile", arguments: filename)
    } else {
      // Engine not ready yet (cold launch). Store the path; it will be
      // delivered in applicationDidFinishLaunching once the channel exists.
      pendingFilePath = filename
    }
    return true
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
