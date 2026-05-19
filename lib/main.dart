import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/recipes/data/recipe_repository.dart';
import 'features/recipes/data/share_import_service.dart';
import 'features/recipes/domain/recipe.dart';
import 'l10n/app_localizations.dart';

void main() {
  if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const ProviderScope(child: RecipyApp()));
}

class RecipyApp extends ConsumerStatefulWidget {
  const RecipyApp({super.key});

  @override
  ConsumerState<RecipyApp> createState() => _RecipyAppState();
}

class _RecipyAppState extends ConsumerState<RecipyApp> {
  @override
  void initState() {
    super.initState();
    // File intent handling is Android-only.
    if (defaultTargetPlatform != TargetPlatform.android) return;

    // Cold-start: app was launched by tapping a .recipy file attachment.
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      if (files.isNotEmpty) _handleSharedFiles(files);
      ReceiveSharingIntent.instance.reset();
    });

    // Warm-start: app was already running when the file was tapped.
    ReceiveSharingIntent.instance.getMediaStream().listen((files) {
      if (files.isNotEmpty) _handleSharedFiles(files);
    });
  }

  Future<void> _handleSharedFiles(List<SharedMediaFile> files) async {
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

        final content = await file.readAsString();
        debugPrint('[Recipy] content length: ${content.length}');
        final service = ref.read(shareImportServiceProvider);
        final parsed = service.parseContent(content);
        debugPrint('[Recipy] parsed ${parsed.length} recipe(s)');
        allRecipes.addAll(parsed);
      } catch (e) {
        debugPrint('[Recipy] error processing file: $e');
      }
    }

    debugPrint('[Recipy] total recipes parsed: ${allRecipes.length}');
    if (allRecipes.isEmpty) return;

    // Navigate first, then set the provider on the next frame so that
    // RecipeListScreen is already built and listening before the value arrives.
    ref.read(appRouterProvider).go(AppRoutes.recipes);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[Recipy] setting pendingImportProvider');
      ref.read(pendingImportProvider.notifier).state = allRecipes;
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Recipy',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
