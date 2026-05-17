import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../domain/recipe.dart';

/// Provides a singleton [ShareImportService] instance.
final shareImportServiceProvider =
    Provider<ShareImportService>((ref) => ShareImportService());

/// Handles exporting recipes to JSON files and importing them back.
///
/// Two export modes are supported:
/// - **Single recipe** — exports one recipe as `<title>.recipy.json` and
///   triggers the system share sheet so the user can send it via any app.
/// - **Full collection** — exports all recipes into one
///   `recipy_collection.json` file (same share sheet).
///
/// Import reads any `.json` file the user picks and inserts the recipes
/// into the local SQLite database via the caller's [RecipeListNotifier].
class ShareImportService {
  // ---------------------------------------------------------------------------
  // Export — single recipe
  // ---------------------------------------------------------------------------

  /// Serialises [recipe] to JSON, writes it to a temporary file, and opens
  /// the system share sheet so the user can send it via any app
  /// (WhatsApp, email, AirDrop, etc.).
  ///
  /// The file is written to the system temp directory so it is cleaned up
  /// automatically by the OS and does not accumulate on the device.
  Future<void> shareRecipe(Recipe recipe) async {
    final json = jsonEncode(recipe.toJson());
    final file = await _writeTempFile(
      // Sanitise the title for use as a filename.
      filename: '${_safeFilename(recipe.title)}.recipy.json',
      content: json,
    );
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: recipe.title,
      text: 'Here\'s my recipe for ${recipe.title}!',
    );
  }

  // ---------------------------------------------------------------------------
  // Export — full collection
  // ---------------------------------------------------------------------------

  /// Serialises [recipes] to a JSON array and shares the resulting file.
  ///
  /// The exported format is a top-level object with a `recipes` key so the
  /// file is self-describing and easy to extend in future versions:
  /// ```json
  /// { "version": 1, "recipes": [ { … }, … ] }
  /// ```
  Future<void> shareCollection(List<Recipe> recipes) async {
    final payload = {
      'version': 1,
      'recipes': recipes.map((r) => r.toJson()).toList(),
    };
    final json = const JsonEncoder.withIndent('  ').convert(payload);
    final file = await _writeTempFile(
      filename: 'recipy_collection.json',
      content: json,
    );
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'My Recipy collection',
      text: 'Here are all my recipes exported from Recipy!',
    );
  }

  // ---------------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------------

  /// Opens the system file picker filtered to JSON files, reads the selected
  /// file, and returns the parsed list of [Recipe] objects.
  ///
  /// Supports both single-recipe files (produced by [shareRecipe]) and
  /// collection files (produced by [shareCollection]).
  ///
  /// Returns an empty list if:
  /// - The user cancels the picker.
  /// - The file cannot be read or parsed.
  ///
  /// Throws a descriptive [FormatException] if the JSON is structurally valid
  /// but does not contain recognisable recipe data.
  Future<List<Recipe>> pickAndImport() async {
    // Open the OS file picker.  On Android this shows the document browser;
    // on iOS/macOS the Files app; on Windows/Linux a native dialog.
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: false,
    );

    // User cancelled the picker.
    if (result == null || result.files.isEmpty) return [];

    final path = result.files.single.path;
    if (path == null) return [];

    final content = await File(path).readAsString();
    return _parseImportContent(content);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Parses the raw JSON string from an import file.
  ///
  /// Handles three formats:
  /// 1. Collection file: `{ "version": 1, "recipes": [ … ] }`
  /// 2. Single-recipe object: `{ "title": "…", … }`
  /// 3. Bare array (legacy / third-party): `[ { "title": "…" }, … ]`
  List<Recipe> _parseImportContent(String content) {
    final dynamic decoded = jsonDecode(content);

    if (decoded is Map<String, dynamic>) {
      if (decoded.containsKey('recipes')) {
        // Collection format.
        final list = decoded['recipes'] as List<dynamic>;
        return list
            .whereType<Map<String, dynamic>>()
            .map(Recipe.fromJson)
            .toList();
      }
      // Single recipe object.
      if (decoded.containsKey('title')) {
        return [Recipe.fromJson(decoded)];
      }
      throw const FormatException(
          'JSON file does not appear to contain recipe data.');
    }

    if (decoded is List<dynamic>) {
      // Bare array of recipe objects.
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Recipe.fromJson)
          .toList();
    }

    throw const FormatException('Unrecognised JSON format.');
  }

  /// Writes [content] to a file named [filename] in the system temp directory
  /// and returns the resulting [File].
  Future<File> _writeTempFile({
    required String filename,
    required String content,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, filename));
    await file.writeAsString(content, flush: true);
    return file;
  }

  /// Converts a recipe title into a safe filename by replacing characters
  /// that are invalid in file names with underscores.
  String _safeFilename(String title) {
    return title
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
  }
}
