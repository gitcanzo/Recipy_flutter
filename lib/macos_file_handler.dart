import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/recipes/data/recipe_repository.dart';
import 'features/recipes/data/share_import_service.dart';

/// Registers a [MethodChannel] that receives file-open events from the macOS
/// [AppDelegate] when the user double-clicks a `.recipy` file in Finder or
/// drags one onto the Dock icon.
///
/// Parsed recipes are placed into [pendingImportProvider], which causes
/// [RecipeListScreen] to show the standard confirmation dialog — the same
/// flow used for Android intent-based imports and the in-app file picker.
/// This ensures the user always gets a chance to confirm before anything
/// is written to the database.
void initMacOSFileHandler(WidgetRef ref) {
  // This channel name must exactly match the one used in AppDelegate.swift.
  // Any mismatch means the method call is silently dropped on both sides.
  const channel = MethodChannel('com.gcanz.recipy/file_open');

  channel.setMethodCallHandler((call) async {
    // We only handle one method — ignore anything unexpected from the native side.
    if (call.method != 'openFile') return;

    // The argument is the absolute file system path sent by AppDelegate.swift.
    final path = call.arguments as String?;
    if (path == null || path.isEmpty) return;

    // Verify the file actually exists before trying to read it.
    // The path is provided by macOS so it should always exist, but we guard
    // defensively in case the file was moved or deleted between the open event
    // and this handler being called.
    final file = File(path);
    if (!file.existsSync()) return;

    try {
      // Read as bytes so _parseBytes can auto-detect ZIP vs plain JSON,
      // matching the same logic used by the in-app file picker.
      final bytes = await file.readAsBytes();
      final service = ref.read(shareImportServiceProvider);
      final parsed = await service.parseBytesFromFile(bytes);

      // Nothing to import (empty or unrecognised file) — bail out silently.
      if (parsed.isEmpty) return;

      // Place the parsed recipes into the pending-import provider.
      // RecipeListScreen listens to this provider and will show the
      // confirmation dialog on the next frame, exactly as it does for
      // Android intent-based imports.
      ref.read(pendingImportProvider.notifier).state = parsed;
    } catch (_) {
      // Silently ignore unreadable or malformed files — the user will simply
      // see nothing happen, which is better than an unhandled crash.
    }
  });
}
