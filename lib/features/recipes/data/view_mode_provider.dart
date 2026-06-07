import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The two display modes available on the recipe list screen.
enum RecipeViewMode { grid, list }

const _prefsKey = 'recipe_view_mode';

/// Persists and exposes the user's preferred view mode (grid vs list).
///
/// Loads the saved preference asynchronously on first read; defaults to
/// [RecipeViewMode.grid] if nothing has been saved yet.
class ViewModeNotifier extends StateNotifier<RecipeViewMode> {
  ViewModeNotifier() : super(RecipeViewMode.grid) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved == RecipeViewMode.list.name) {
      state = RecipeViewMode.list;
    }
  }

  /// Toggles between grid and list, then persists the new value.
  Future<void> toggle() async {
    final next = state == RecipeViewMode.grid
        ? RecipeViewMode.list
        : RecipeViewMode.grid;
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, next.name);
  }
}

final viewModeProvider =
    StateNotifierProvider<ViewModeNotifier, RecipeViewMode>(
  (_) => ViewModeNotifier(),
);
