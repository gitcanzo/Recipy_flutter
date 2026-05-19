import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'core/router/app_router.dart';
import 'features/recipes/data/recipe_repository.dart';
import 'features/recipes/data/share_import_service.dart';
import 'features/recipes/domain/recipe.dart';

/// Wires up [ReceiveSharingIntent] for cold-start and warm-start file intents.
/// Called once from [_RecipyAppState.initState] on Android only.
void initSharingHandler(WidgetRef ref) {
  ReceiveSharingIntent.instance.getInitialMedia().then((files) {
    if (files.isNotEmpty) _handleSharedFiles(ref, files);
    ReceiveSharingIntent.instance.reset();
  });

  ReceiveSharingIntent.instance.getMediaStream().listen((files) {
    if (files.isNotEmpty) _handleSharedFiles(ref, files);
  });
}

Future<void> _handleSharedFiles(WidgetRef ref, List<SharedMediaFile> files) async {
  debugPrint('[Recipy] _handleSharedFiles: ${files.length} file(s)');
  final allRecipes = <Recipe>[];
  for (final sharedFile in files) {
    debugPrint('[Recipy] processing path: ${sharedFile.path}');
    try {
      final rawPath = sharedFile.path;
      final filePath = rawPath.startsWith('file://')
          ? Uri.parse(rawPath).toFilePath()
          : rawPath;

      final file = File(filePath);
      debugPrint('[Recipy] file exists: ${file.existsSync()} at $filePath');
      if (!file.existsSync()) continue;

      final bytes = await file.readAsBytes();
      debugPrint('[Recipy] content length: ${bytes.length}');
      final service = ref.read(shareImportServiceProvider);
      final parsed = await service.parseBytesFromFile(bytes);
      debugPrint('[Recipy] parsed ${parsed.length} recipe(s)');
      allRecipes.addAll(parsed);
    } catch (e) {
      debugPrint('[Recipy] error processing file: $e');
    }
  }

  debugPrint('[Recipy] total recipes parsed: ${allRecipes.length}');
  if (allRecipes.isEmpty) return;

  ref.read(appRouterProvider).go(AppRoutes.recipes);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    debugPrint('[Recipy] setting pendingImportProvider');
    ref.read(pendingImportProvider.notifier).state = allRecipes;
  });
}
