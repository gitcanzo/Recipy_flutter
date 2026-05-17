import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/recipes/presentation/screens/recipe_list_screen.dart';
import '../../features/recipes/presentation/screens/recipe_detail_screen.dart';
import '../../features/recipes/presentation/screens/recipe_edit_screen.dart';
import '../../features/url_import/presentation/url_import_screen.dart';

/// Named route paths used throughout the app.
///
/// Centralising paths here prevents typos when calling [context.go] or
/// [context.push] and makes refactoring routes easier.
class AppRoutes {
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
    // Start on the recipe list screen.
    initialLocation: AppRoutes.recipes,

    routes: [
      GoRoute(
        path: AppRoutes.recipes,
        builder: (context, state) => const RecipeListScreen(),
        routes: [
          // "new" must be declared before ":id" so GoRouter matches the
          // literal path segment before treating it as a parameter.
          GoRoute(
            path: 'new',
            builder: (context, state) =>
                const RecipeEditScreen(recipeId: null),
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
