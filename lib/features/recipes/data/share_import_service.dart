import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../domain/recipe.dart';

/// Provides a singleton [ShareImportService] instance.
final shareImportServiceProvider =
    Provider<ShareImportService>((ref) => ShareImportService());

/// Handles exporting recipes to `.recipy` files and importing them back.
///
/// Export has two modes per operation:
/// - **Save to device** — writes the file to the user-visible Downloads folder
///   (Android) or shows a native save dialog (Windows/macOS/Linux).
/// - **Share** — writes a temp file and opens the system share sheet.
///
/// Import reads any `.recipy` (or legacy `.json`) file the user picks.
class ShareImportService {
  // ---------------------------------------------------------------------------
  // Export — single recipe — save to device
  // ---------------------------------------------------------------------------

  /// Saves [recipe] as `<title>.recipy` to a user-visible location.
  ///
  /// Returns the saved path, or null if the user cancelled the save dialog.
  Future<String?> saveRecipeToDevice(Recipe recipe) async {
    final json = jsonEncode(recipe.toJson());
    final filename = '${_safeFilename(recipe.title)}.recipy';
    return _saveToDevice(filename: filename, content: json);
  }

  // ---------------------------------------------------------------------------
  // Export — single recipe — share sheet
  // ---------------------------------------------------------------------------

  /// Serialises [recipe] to a temp `.recipy` file and opens the system share
  /// sheet so the user can send it via email, Bluetooth, etc.
  Future<void> shareRecipe(Recipe recipe, {required String shareText}) async {
    final json = jsonEncode(recipe.toJson());
    final file = await _writeTempFile(
      filename: '${_safeFilename(recipe.title)}.recipy',
      content: json,
    );
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/x-recipy')],
      subject: recipe.title,
      text: shareText,
    );
  }

  // ---------------------------------------------------------------------------
  // Export — full collection — save to device
  // ---------------------------------------------------------------------------

  /// Saves all [recipes] as `recipy_collection.recipy` to a user-visible
  /// location.  Returns the saved path, or null if cancelled.
  Future<String?> saveCollectionToDevice(List<Recipe> recipes) async {
    final payload = {
      'version': 1,
      'recipes': recipes.map((r) => r.toJson()).toList(),
    };
    final json = const JsonEncoder.withIndent('  ').convert(payload);
    return _saveToDevice(
        filename: 'recipy_collection.recipy', content: json);
  }

  // ---------------------------------------------------------------------------
  // Export — full collection — share sheet
  // ---------------------------------------------------------------------------

  /// Serialises [recipes] to a temp `.recipy` file and opens the system share
  /// sheet.
  Future<void> shareCollection(
    List<Recipe> recipes, {
    required String subject,
    required String shareText,
  }) async {
    final payload = {
      'version': 1,
      'recipes': recipes.map((r) => r.toJson()).toList(),
    };
    final json = const JsonEncoder.withIndent('  ').convert(payload);
    final file = await _writeTempFile(
      filename: 'recipy_collection.recipy',
      content: json,
    );
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/x-recipy')],
      subject: subject,
      text: shareText,
    );
  }

  // ---------------------------------------------------------------------------
  // Import — file picker
  // ---------------------------------------------------------------------------

  /// Opens the system file picker filtered to `.recipy` and `.json` files,
  /// reads the selected file, and returns the parsed list of [Recipe] objects.
  ///
  /// Returns an empty list if the user cancels or the file is unreadable.
  /// Throws a [FormatException] with a sentinel message when the content is
  /// structurally valid JSON but not recognisable as recipe data.
  Future<List<Recipe>> pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['recipy', 'json'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return [];

    final path = result.files.single.path;
    if (path == null) return [];

    final content = await File(path).readAsString();
    return _parseImportContent(content);
  }

  /// Parses a raw JSON string from a `.recipy` or `.json` import file.
  ///
  /// Called both from [pickAndImport] and from the intent-handler in main.dart
  /// when the app is opened by tapping a `.recipy` file attachment.
  List<Recipe> parseContent(String content) => _parseImportContent(content);

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Saves [content] to [filename].
  ///
  /// On Android writes to the public Downloads directory so the file is visible
  /// in the Files app without any storage permission on API 29+.
  /// On desktop (Windows/macOS/Linux) shows a native save-file dialog.
  /// Returns the saved path, or null if the user cancelled (desktop only).
  Future<String?> _saveToDevice({
    required String filename,
    required String content,
  }) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      // On Android, getExternalStorageDirectory points to the app-scoped
      // external storage.  For a user-visible Downloads folder we construct
      // the standard path directly — no permission needed on API 29+.
      final dir = Directory('/storage/emulated/0/Download');
      if (!dir.existsSync()) {
        // Fallback to app documents if the standard path is unavailable.
        final appDir = await getApplicationDocumentsDirectory();
        final file = File(p.join(appDir.path, filename));
        await file.writeAsString(content, flush: true);
        return file.path;
      }
      final file = File(p.join(dir.path, filename));
      await file.writeAsString(content, flush: true);
      return file.path;
    }

    // Desktop: show a native save dialog via file_picker.
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save recipe',
      fileName: filename,
      type: FileType.custom,
      allowedExtensions: ['recipy'],
    );
    if (savePath == null) return null;
    final file = File(savePath);
    await file.writeAsString(content, flush: true);
    return savePath;
  }

  /// Writes [content] to a file named [filename] in the system temp directory.
  Future<File> _writeTempFile({
    required String filename,
    required String content,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, filename));
    await file.writeAsString(content, flush: true);
    return file;
  }

  List<Recipe> _parseImportContent(String content) {
    final dynamic decoded = jsonDecode(content);

    if (decoded is Map<String, dynamic>) {
      if (decoded.containsKey('recipes')) {
        final list = decoded['recipes'] as List<dynamic>;
        return list
            .whereType<Map<String, dynamic>>()
            .map(Recipe.fromJson)
            .toList();
      }
      if (decoded.containsKey('title')) {
        return [Recipe.fromJson(decoded)];
      }
      throw const FormatException('json_not_recipe_data');
    }

    if (decoded is List<dynamic>) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Recipe.fromJson)
          .toList();
    }

    throw const FormatException('json_unrecognised_format');
  }

  String _safeFilename(String title) {
    return title
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
  }
}
