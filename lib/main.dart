import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// Application entry point.
///
/// On Android and iOS, sqflite initialises itself automatically.
/// On desktop platforms (Windows, Linux, macOS), we must manually point sqflite
/// at the FFI implementation before any database call is made — otherwise the
/// global [openDatabase] function throws "databaseFactory not initialized".
void main() {
  // Initialise the sqflite FFI factory on desktop platforms.
  // [defaultTargetPlatform] is used rather than `Platform.isWindows` because
  // it also works correctly in widget tests where dart:io is mocked.
  if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux) {
    // sqfliteFfiInit registers the FFI dynamic library with sqflite_common_ffi.
    sqfliteFfiInit();
    // Replace the global databaseFactory so that calls to openDatabase() route
    // through the FFI implementation instead of the (absent) Android/iOS one.
    databaseFactory = databaseFactoryFfi;
  }

  // Wrap the entire app in a [ProviderScope] so every Riverpod provider
  // declared anywhere in the app is accessible from any widget.
  runApp(const ProviderScope(child: RecipyApp()));
}

/// Root widget of the application.
///
/// Watches [appRouterProvider] for the [GoRouter] instance that handles all
/// navigation in the app.
class RecipyApp extends ConsumerWidget {
  const RecipyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Recipy',
      // Custom Material 3 theme with a warm orange seed colour.
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Respect the device's system light/dark preference automatically.
      themeMode: ThemeMode.system,
      routerConfig: router,
      // Remove the debug banner so it doesn't obscure the UI during testing.
      debugShowCheckedModeBanner: false,
    );
  }
}
