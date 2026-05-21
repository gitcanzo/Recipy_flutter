import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
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
/// The `.recipy` format is a ZIP archive containing:
///   - `recipes.json`  — the recipe collection (same JSON shape as before)
///   - `images/<filename>` — one entry per referenced image
///
/// Legacy plain-JSON `.recipy` files are still accepted on import.
///
/// Export has two modes per operation:
/// - **Save to device** — writes the file to Downloads (Android) or a save
///   dialog (desktop).
/// - **Share** — writes a temp file and opens the system share sheet.
class ShareImportService {
  // ---------------------------------------------------------------------------
  // Export — single recipe — save to device
  // ---------------------------------------------------------------------------

  Future<String?> saveRecipeToDevice(Recipe recipe) async {
    final bytes = await _buildZip([recipe]);
    final filename = '${_safeFilename(recipe.title)}.recipy';
    return _saveBytesToDevice(filename: filename, bytes: bytes);
  }

  // ---------------------------------------------------------------------------
  // Export — single recipe — share sheet
  // ---------------------------------------------------------------------------

  Future<void> shareRecipe(Recipe recipe, {required String shareText}) async {
    final bytes = await _buildZip([recipe]);
    final file = await _writeTempBytes(
      filename: '${_safeFilename(recipe.title)}.recipy',
      bytes: bytes,
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

  Future<String?> saveCollectionToDevice(List<Recipe> recipes) async {
    final bytes = await _buildZip(recipes);
    return _saveBytesToDevice(
        filename: 'recipy_collection.recipy', bytes: bytes);
  }

  // ---------------------------------------------------------------------------
  // Export — full collection — share sheet
  // ---------------------------------------------------------------------------

  Future<void> shareCollection(
    List<Recipe> recipes, {
    required String subject,
    required String shareText,
  }) async {
    final bytes = await _buildZip(recipes);
    final file = await _writeTempBytes(
      filename: 'recipy_collection.recipy',
      bytes: bytes,
    );
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/x-recipy')],
      subject: subject,
      text: shareText,
    );
  }

  // ---------------------------------------------------------------------------
  // Export — PDF — save to device
  // ---------------------------------------------------------------------------

  /// Saves [bytes] as a PDF file named [filename].pdf to the Downloads folder
  /// on Android, or shows a native save dialog on desktop platforms.
  ///
  /// Returns the saved file path on success, or null if the user cancelled.
  Future<String?> savePdfToDevice(String filename, Uint8List bytes) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      // On Android write directly to the public Downloads folder so the user
      // can find the file in their file manager without any extra steps.
      final dir = Directory('/storage/emulated/0/Download');
      final base = dir.existsSync() ? dir : await getApplicationDocumentsDirectory();
      final file = File(p.join(base.path, '$filename.pdf'));
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    }
    // Desktop (macOS, Windows, Linux): show a native save dialog so the user
    // can choose where to put the file.
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save PDF',
      fileName: '$filename.pdf',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (savePath == null) return null;
    await File(savePath).writeAsBytes(bytes, flush: true);
    return savePath;
  }

  // ---------------------------------------------------------------------------
  // Export — PDF — share sheet
  // ---------------------------------------------------------------------------

  /// Writes [bytes] to a temp file and opens the system share sheet so the
  /// user can send the PDF via email, AirDrop, or any installed app.
  Future<void> sharePdf(String filename, Uint8List bytes) async {
    final file = await _writeTempBytes(filename: '$filename.pdf', bytes: bytes);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: filename,
    );
  }

  // ---------------------------------------------------------------------------
  // Import — file picker
  // ---------------------------------------------------------------------------

  Future<List<Recipe>> pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return [];

    final path = result.files.single.path;
    if (path == null) return [];

    final bytes = await File(path).readAsBytes();
    return _parseBytes(bytes);
  }

  /// Parses raw bytes from a `.recipy` file (ZIP or legacy plain JSON).
  ///
  /// Called from [pickAndImport] and from the intent-handler in main.dart
  /// when the app is opened by tapping a `.recipy` attachment.
  Future<List<Recipe>> parseBytesFromFile(Uint8List bytes) =>
      _parseBytes(bytes);

  /// Parses a plain-JSON string (legacy format, no images).
  ///
  /// Kept for callers that already have a decoded string.
  List<Recipe> parseContent(String content) => _parseJsonString(content);

  // ---------------------------------------------------------------------------
  // ZIP builder
  // ---------------------------------------------------------------------------

  /// Builds a ZIP archive containing `recipes.json` and all referenced images.
  Future<Uint8List> _buildZip(List<Recipe> recipes) async {
    final archive = Archive();

    // Collect image files, deduplicated by absolute path.
    final imageFiles = <String, String>{}; // absPath -> archive entry name
    for (final recipe in recipes) {
      if (recipe.imagePath.isNotEmpty) {
        final file = File(recipe.imagePath);
        if (file.existsSync() && !imageFiles.containsKey(recipe.imagePath)) {
          final name = p.basename(recipe.imagePath);
          imageFiles[recipe.imagePath] = 'images/$name';
        }
      }
    }

    // Build JSON payload: imagePath replaced by just the filename.
    final jsonList = recipes.map((r) {
      final map = r.toJson();
      if (r.imagePath.isNotEmpty && imageFiles.containsKey(r.imagePath)) {
        map['imageFile'] = p.basename(r.imagePath);
      }
      return map;
    }).toList();

    final payload = {
      'version': 2,
      'recipes': jsonList,
    };
    final jsonBytes =
        utf8.encode(const JsonEncoder.withIndent('  ').convert(payload));
    archive.addFile(ArchiveFile('recipes.json', jsonBytes.length, jsonBytes));

    // Add image files.
    for (final entry in imageFiles.entries) {
      final bytes = await File(entry.key).readAsBytes();
      archive.addFile(ArchiveFile(entry.value, bytes.length, bytes));
    }

    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  // ---------------------------------------------------------------------------
  // ZIP / JSON parser
  // ---------------------------------------------------------------------------

  Future<List<Recipe>> _parseBytes(Uint8List bytes) async {
    // Detect ZIP by magic bytes: PK\x03\x04
    if (bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04) {
      return _parseZip(bytes);
    }
    // Fall back to plain JSON.
    return _parseJsonString(utf8.decode(bytes));
  }

  Future<List<Recipe>> _parseZip(Uint8List bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);

    // Extract images first so paths are available when building recipes.
    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(dir.path, 'recipe_images'));
    if (!imagesDir.existsSync()) imagesDir.createSync(recursive: true);

    // Map archive entry name → local absolute path.
    final extractedImages = <String, String>{};
    for (final file in archive) {
      if (file.isFile && file.name.startsWith('images/')) {
        final filename = p.basename(file.name);
        // Avoid collisions with existing files by prepending a timestamp.
        final ts = DateTime.now().millisecondsSinceEpoch;
        final localName = '${ts}_$filename';
        final dest = File(p.join(imagesDir.path, localName));
        await dest.writeAsBytes(file.content);
        extractedImages[filename] = dest.path;
      }
    }

    // Parse recipes.json.
    final jsonEntry = archive.findFile('recipes.json');
    if (jsonEntry == null) throw const FormatException('json_not_recipe_data');
    final jsonString = utf8.decode(jsonEntry.content);
    final recipes = _parseJsonString(jsonString);

    // Re-attach image paths using the imageFile key stored in toJson.
    final dynamic decoded = jsonDecode(jsonString);
    final List<dynamic> rawList = decoded is Map && decoded.containsKey('recipes')
        ? decoded['recipes'] as List<dynamic>
        : decoded is List
            ? decoded
            : [];

    return List.generate(recipes.length, (i) {
      final imageFile = i < rawList.length
          ? (rawList[i] as Map<String, dynamic>)['imageFile'] as String?
          : null;
      if (imageFile != null && extractedImages.containsKey(imageFile)) {
        return recipes[i].copyWith(imagePath: extractedImages[imageFile]);
      }
      return recipes[i];
    });
  }

  List<Recipe> _parseJsonString(String content) {
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

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<String?> _saveBytesToDevice({
    required String filename,
    required Uint8List bytes,
  }) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final dir = Directory('/storage/emulated/0/Download');
      final base = dir.existsSync() ? dir : await getApplicationDocumentsDirectory();
      final file = File(p.join(base.path, filename));
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    }

    // Desktop: show a native save dialog.
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save recipe',
      fileName: filename,
      type: FileType.custom,
      allowedExtensions: ['recipy'],
    );
    if (savePath == null) return null;
    await File(savePath).writeAsBytes(bytes, flush: true);
    return savePath;
  }

  Future<File> _writeTempBytes({
    required String filename,
    required Uint8List bytes,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, filename));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  String _safeFilename(String title) {
    return title
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
  }
}
