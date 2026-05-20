import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'macos_file_handler.dart';

// Conditional import: Android gets the real sharing handler; all other
// platforms get a no-op stub so receive_sharing_intent is never compiled in.
import 'sharing_handler_stub.dart'
    if (dart.library.io) 'sharing_handler_android.dart'
    // The if-clause above matches any native platform, so we need an
    // additional Android check at runtime inside initSharingHandler itself.
    // The stub is the safe fallback for web.
    ;

void main() {
  if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS) {
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
    // Wire up Android file-intent handler (receive_sharing_intent).
    if (defaultTargetPlatform == TargetPlatform.android) {
      initSharingHandler(ref);
    }
    // Wire up macOS file-open handler (MethodChannel from AppDelegate.swift).
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      initMacOSFileHandler(ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Recipy',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
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
