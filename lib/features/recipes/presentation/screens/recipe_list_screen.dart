import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/pdf_service.dart';
import '../../data/recipe_repository.dart';
import '../../data/share_import_service.dart';
import '../../domain/recipe.dart';
import '../widgets/recipe_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../core/router/app_router.dart';

/// The main screen of the app: a searchable grid of all locally-stored
/// recipes with export and import actions.
///
/// Uses [ConsumerStatefulWidget] to keep the search query as local widget
/// state while watching [recipeListProvider] for live SQLite-backed updates.
class RecipeListScreen extends ConsumerStatefulWidget {
  const RecipeListScreen({super.key});

  @override
  ConsumerState<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends ConsumerState<RecipeListScreen> {
  /// Current text in the search bar.  Empty string means no filter is active.
  String _searchQuery = '';

  /// Controller for the search bar so we can clear it programmatically.
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Filters [recipes] case-insensitively against [_searchQuery], checking
  /// the title, description, tags, and individual ingredients.  This lets
  /// users search by what they have on hand (e.g. "chicken" or "garlic").
  List<Recipe> _filtered(List<Recipe> recipes) {
    if (_searchQuery.isEmpty) return recipes;
    final q = _searchQuery.toLowerCase();
    return recipes.where((r) {
      return r.title.toLowerCase().contains(q) ||
          r.description.toLowerCase().contains(q) ||
          r.tags.any((t) => t.toLowerCase().contains(q)) ||
          r.ingredients.any((i) => i.toLowerCase().contains(q));
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Share / import actions
  // ---------------------------------------------------------------------------

  /// Exports the full recipe collection as a JSON file and opens the system
  /// share sheet.
  Future<void> _exportAll(List<Recipe> recipes) async {
    if (recipes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No recipes to export.')),
      );
      return;
    }
    try {
      await ref.read(shareImportServiceProvider).shareCollection(recipes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  /// Generates a recipe book PDF from all [recipes] and opens the system
  /// print / preview dialog so the user can print or save it.
  Future<void> _exportPdfBook(List<Recipe> recipes) async {
    if (recipes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No recipes to export.')),
      );
      return;
    }
    try {
      await ref.read(pdfServiceProvider).previewBook(recipes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('PDF failed: $e')));
      }
    }
  }

  /// Opens the file picker, parses the selected JSON, and inserts the recipes.
  Future<void> _import() async {
    try {
      final service = ref.read(shareImportServiceProvider);
      final imported = await service.pickAndImport();

      if (imported.isEmpty) return; // User cancelled or file was empty.

      await ref.read(recipeListProvider.notifier).importRecipes(imported);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              imported.length == 1
                  ? '1 recipe imported.'
                  : '${imported.length} recipes imported.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(recipeListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipy'),
        actions: [
          // Import from URL
          IconButton(
            icon: const Icon(Icons.link),
            tooltip: 'Import from URL',
            onPressed: () => context.push(AppRoutes.urlImport),
          ),
          // Overflow menu for export/import file actions
          recipesAsync.maybeWhen(
            data: (recipes) => PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'More actions',
              onSelected: (value) {
                if (value == 'export') _exportAll(recipes);
                if (value == 'import') _import();
                if (value == 'pdf') _exportPdfBook(recipes);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'export',
                  child: ListTile(
                    leading: Icon(Icons.upload_outlined),
                    title: Text('Export collection'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'import',
                  child: ListTile(
                    leading: Icon(Icons.download_outlined),
                    title: Text('Import from file'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'pdf',
                  child: ListTile(
                    leading: Icon(Icons.menu_book_outlined),
                    title: Text('Print recipe book'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Column(
        children: [
          // ---- Search bar ----
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search recipes or ingredients…',
              leading: const Icon(Icons.search),
              trailing: [
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
              ],
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // ---- Recipe grid ----
          Expanded(
            child: recipesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Could not load recipes: $e')),
              data: (recipes) {
                final filtered = _filtered(recipes);

                if (recipes.isEmpty) {
                  return EmptyState(
                    icon: Icons.menu_book_outlined,
                    message: 'No recipes yet',
                    subMessage:
                        'Tap + to add your first recipe, or import one from a URL or file.',
                    actionLabel: 'Add recipe',
                    onAction: () =>
                        context.push('${AppRoutes.recipes}/new'),
                  );
                }

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off,
                    message: 'No results for "$_searchQuery"',
                    subMessage:
                        'Try a different title, ingredient, or tag.',
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    // Fixed height per cell instead of an aspect ratio so the
                    // card never overflows regardless of screen density or font
                    // scaling.  320 fits the image (160) + title + metadata +
                    // up to 3 tag chips with comfortable padding.
                    mainAxisExtent: 360,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final recipe = filtered[index];
                    return RecipeCard(
                      recipe: recipe,
                      onTap: () => context.push(
                          '${AppRoutes.recipes}/${recipe.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('${AppRoutes.recipes}/new'),
        icon: const Icon(Icons.add),
        label: const Text('Add recipe'),
      ),
    );
  }
}
