import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/pdf_service.dart';
import '../../data/recipe_repository.dart';
import '../../data/share_import_service.dart';
import '../../domain/recipe.dart';
import '../../../../core/router/app_router.dart';

/// Displays the full details of a single recipe identified by its SQLite [recipeId].
///
/// Loads the recipe via a [FutureProvider] on first render.
/// Provides edit and delete actions in the [AppBar].
class RecipeDetailScreen extends ConsumerWidget {
  /// The SQLite integer primary key of the recipe to display.
  final int recipeId;

  const RecipeDetailScreen({super.key, required this.recipeId});

  /// Shows a confirmation dialog, then deletes the recipe and navigates back
  /// to the recipe list.
  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete recipe?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(recipeListProvider.notifier).deleteRecipe(recipeId);
      if (context.mounted) context.go(AppRoutes.recipes);
    }
  }

  /// Opens the system print/preview dialog for [recipe] as a PDF.
  Future<void> _printPdf(BuildContext context, WidgetRef ref,
      Recipe recipe) async {
    try {
      await ref.read(pdfServiceProvider).previewRecipe(recipe);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF failed: $e')),
        );
      }
    }
  }

  /// Shares [recipe] as a JSON file via the system share sheet.
  Future<void> _share(BuildContext context, WidgetRef ref,
      Recipe recipe) async {
    try {
      await ref.read(shareImportServiceProvider).shareRecipe(recipe);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    /// A family provider scoped to this [recipeId] that fetches the recipe
    /// once from SQLite.  Declared inline here so the family key is the
    /// integer ID rather than a string.
    final recipeAsync = ref.watch(_recipeDetailProvider(recipeId));

    return Scaffold(
      body: recipeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading recipe: $e')),
        data: (recipe) {
          if (recipe == null) {
            return const Center(child: Text('Recipe not found.'));
          }
          return _RecipeDetailBody(
            recipe: recipe,
            onEdit: () =>
                context.push('${AppRoutes.recipes}/$recipeId/edit'),
            onDelete: () => _delete(context, ref),
            onPdf: () => _printPdf(context, ref, recipe),
            onShare: () => _share(context, ref, recipe),
          );
        },
      ),
    );
  }
}

/// Family provider that fetches a single recipe by integer [id] from SQLite.
///
/// Declared at file scope (not inside the widget) so Riverpod caches and
/// disposes it correctly as the user navigates between screens.
final _recipeDetailProvider =
    FutureProvider.family<Recipe?, int>((ref, id) async {
  return ref.watch(recipeRepositoryProvider).getRecipe(id);
});

/// The scrollable body of the detail screen, extracted to keep
/// [RecipeDetailScreen] focused on data-fetching and action handling.
class _RecipeDetailBody extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Called when the user requests a PDF preview / print of this recipe.
  final VoidCallback onPdf;

  /// Called when the user wants to share this recipe as a JSON file.
  final VoidCallback onShare;

  const _RecipeDetailBody({
    required this.recipe,
    required this.onEdit,
    required this.onDelete,
    required this.onPdf,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return CustomScrollView(
      slivers: [
        // ----------------------------------------------------------------
        // Collapsible app bar — shows the cover photo when one is set.
        // ----------------------------------------------------------------
        SliverAppBar(
          expandedHeight: recipe.imagePath.isNotEmpty ? 260 : 0,
          pinned: true,
          flexibleSpace: recipe.imagePath.isNotEmpty
              ? FlexibleSpaceBar(
                  background: Image.file(
                    File(recipe.imagePath),
                    fit: BoxFit.cover,
                    // Show a plain container if the file has been deleted.
                    errorBuilder: (context, error, stack) => Container(
                      color: colorScheme.surfaceContainerHighest,
                    ),
                  ),
                )
              : null,
          title: Text(recipe.title),
          actions: [
            /// Share this recipe as a JSON file.
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share recipe',
              onPressed: onShare,
            ),
            /// Open the print / PDF preview dialog.
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Print / Save PDF',
              onPressed: onPdf,
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit recipe',
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete recipe',
              onPressed: onDelete,
            ),
          ],
        ),

        // ----------------------------------------------------------------
        // Recipe content
        // ----------------------------------------------------------------
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Metadata chips: prep time and servings.
              Wrap(
                spacing: 8,
                children: [
                  if (recipe.prepTimeMinutes > 0)
                    _InfoChip(
                      icon: Icons.timer_outlined,
                      label: '${recipe.prepTimeMinutes} min',
                    ),
                  if (recipe.servings > 0)
                    _InfoChip(
                      icon: Icons.people_outline,
                      label: '${recipe.servings} servings',
                    ),
                ],
              ),

              // Tags
              if (recipe.tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 6,
                    children:
                        recipe.tags.map((t) => Chip(label: Text(t))).toList(),
                  ),
                ),

              // Description
              if (recipe.description.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  recipe.description,
                  style: textTheme.bodyMedium
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],

              // Source URL (shown for imported recipes)
              if (recipe.sourceUrl.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Source: ${recipe.sourceUrl}',
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.primary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const Divider(height: 32),

              // ---- Ingredients ----
              Text('Ingredients', style: textTheme.titleLarge),
              const SizedBox(height: 8),
              ...recipe.ingredients.map(
                (ingredient) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 18)),
                      Expanded(child: Text(ingredient)),
                    ],
                  ),
                ),
              ),

              const Divider(height: 32),

              // ---- Steps ----
              Text('Steps', style: textTheme.titleLarge),
              const SizedBox(height: 8),
              ...recipe.steps.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Numbered circle badge
                          Container(
                            width: 28,
                            height: 28,
                            margin: const EdgeInsets.only(right: 10, top: 1),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${entry.key + 1}',
                              style: textTheme.labelMedium
                                  ?.copyWith(color: colorScheme.onPrimary),
                            ),
                          ),
                          Expanded(child: Text(entry.value)),
                        ],
                      ),
                    ),
                  ),

              const SizedBox(height: 32),
            ]),
          ),
        ),
      ],
    );
  }
}

/// Small chip displaying an icon and a text label.
/// Used for prep-time and servings metadata in the detail view.
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}
