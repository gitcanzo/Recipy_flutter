import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/recipes/domain/recipe.dart';
import '../../features/recipes/presentation/screens/recipe_list_screen.dart';
import '../../features/recipes/presentation/screens/recipe_detail_screen.dart';
import '../../features/recipes/presentation/screens/recipe_edit_screen.dart';
import '../../features/url_import/presentation/url_import_screen.dart';
import '../../shared/widgets/loading_screen.dart';

/// Named route paths used throughout the app.
///
/// Centralising paths here prevents typos when calling [context.go] or
/// [context.push] and makes refactoring routes easier.
class AppRoutes {
  static const loading = '/';
  static const recipes = '/recipes';
  static const recipeNew = '/recipes/new';
  static const recipeDetail = '/recipes/:id';
  static const recipeEdit = '/recipes/:id/edit';
  static const urlImport = '/import';
}

/// Provides the single [GoRouter] instance for the app.
///
/// No auth redirect guard is needed — all data is local and the app is
/// always accessible without signing in.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    // Start on the branded loading screen; it redirects to recipes after 2 s.
    initialLocation: AppRoutes.loading,

    // When the app is launched via a file intent (e.g. opening a .recipy file
    // from WhatsApp), Android passes the content:// URI as the initial route.
    // GoRouter can't match it, so we redirect to the loading screen which will
    // navigate to /recipes after its delay. The actual file import is handled
    // separately by ReceiveSharingIntent in main.dart.
    errorBuilder: (context, state) => const LoadingScreen(),

    routes: [
      GoRoute(
        path: AppRoutes.loading,
        builder: (context, state) => const LoadingScreen(),
      ),
      GoRoute(
        path: AppRoutes.recipes,
        // Cross-fade from the loading screen instead of the default platform
        // slide so the hand-off feels like a reveal rather than a navigation.
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const RecipeListScreen(),
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (context, animation, _, child) =>
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeIn,
                ),
                child: child,
              ),
        ),
        routes: [
          // "new" must be declared before ":id" so GoRouter matches the
          // literal path segment before treating it as a parameter.
          GoRoute(
            path: 'new',
            builder: (context, state) => RecipeEditScreen(
              recipeId: null,
              // When navigating here from the URL import flow, the parsed
              // Recipe is passed via GoRouter's `extra` parameter so that
              // the edit form is pre-populated without a database round-trip.
              initialRecipe: state.extra is Recipe
                  ? state.extra as Recipe
                  : null,
            ),
          ),
          GoRoute(
            path: ':id',
            builder: (context, state) => RecipeDetailScreen(
              /// Parse the path parameter as an integer primary key.
              recipeId: int.parse(state.pathParameters['id']!),
            ),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) => RecipeEditScreen(
                  recipeId: int.tryParse(
                      state.pathParameters['id'] ?? ''),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.urlImport,
        builder: (context, state) => const UrlImportScreen(),
      ),
    ],
  );
});
