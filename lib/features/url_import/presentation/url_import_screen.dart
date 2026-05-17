import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/url_import_service.dart';
import '../../recipes/data/recipe_repository.dart';
import '../../recipes/domain/recipe.dart';
import '../../../core/router/app_router.dart';

/// Screen that lets the user paste a recipe URL and import it into the
/// local SQLite database.
///
/// Flow:
/// 1. User pastes a URL and taps "Import".
/// 2. [UrlImportService] fetches the page and attempts to parse it.
/// 3. The parsed [Recipe] is shown in a preview panel.
/// 4. The user can adjust the title and description before saving.
/// 5. Tapping "Save Recipe" writes the recipe to SQLite and navigates to
///    the detail screen.
class UrlImportScreen extends ConsumerStatefulWidget {
  const UrlImportScreen({super.key});

  @override
  ConsumerState<UrlImportScreen> createState() => _UrlImportScreenState();
}

class _UrlImportScreenState extends ConsumerState<UrlImportScreen> {
  final _urlController = TextEditingController();
  final _importService = UrlImportService();

  /// True while [_importService.importFromUrl] is running.
  bool _isImporting = false;

  /// True while the Firestore save is in progress.
  bool _isSaving = false;

  /// Successfully parsed recipe, or null if none yet.
  Recipe? _importedRecipe;

  /// Error message from the most recent failed import attempt.
  String? _error;

  // Controllers for the editable fields in the preview panel.
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Fetches and parses the URL currently in [_urlController].
  Future<void> _import() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isImporting = true;
      _error = null;
      _importedRecipe = null;
    });

    final result = await _importService.importFromUrl(url);

    if (!mounted) return;

    if (result.error != null) {
      setState(() {
        _error = result.error;
        _isImporting = false;
      });
      return;
    }

    // Pre-fill the editable fields from the parsed recipe so the user can
    // adjust them before committing the save.
    _titleController.text = result.recipe!.title;
    _descriptionController.text = result.recipe!.description;

    setState(() {
      _importedRecipe = result.recipe;
      _isImporting = false;
    });
  }

  /// Saves [_importedRecipe] (with any user edits) to SQLite and navigates
  /// to the new recipe's detail screen.
  Future<void> _save() async {
    if (_importedRecipe == null) return;
    setState(() => _isSaving = true);
    try {
      final recipe = _importedRecipe!.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
      );
      final id =
          await ref.read(recipeListProvider.notifier).addRecipe(recipe);
      if (mounted) context.go('${AppRoutes.recipes}/$id');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import from URL')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- URL input row ----
          Text(
            'Paste the URL of a recipe page:',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    hintText: 'https://…',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                  ),
                  keyboardType: TextInputType.url,
                  // Also trigger import when the user taps "Go" on the keyboard.
                  onSubmitted: (_) => _import(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _isImporting ? null : _import,
                child: _isImporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Import'),
              ),
            ],
          ),

          // ---- Error card ----
          if (_error != null) ...[
            const SizedBox(height: 16),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color:
                            Theme.of(context).colorScheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ---- Preview / edit panel ----
          if (_importedRecipe != null) ...[
            const SizedBox(height: 24),
            Text('Review & edit before saving:',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),

            // Editable title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                  labelText: 'Title', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),

            // Editable description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                  labelText: 'Description', border: OutlineInputBorder()),
              maxLines: 3,
            ),
            const SizedBox(height: 10),

            // Read-only previews of parsed ingredients and steps.
            _SectionPreview(
              title: 'Ingredients (${_importedRecipe!.ingredients.length})',
              items: _importedRecipe!.ingredients,
            ),
            const SizedBox(height: 10),
            _SectionPreview(
              title: 'Steps (${_importedRecipe!.steps.length})',
              items: _importedRecipe!.steps,
              numbered: true,
            ),
            const SizedBox(height: 8),
            Text(
              'You can edit ingredients and steps in full after saving.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),

            // Save button
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_isSaving ? 'Saving…' : 'Save Recipe'),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact read-only preview of a string list (ingredients or steps).
///
/// Shows up to 5 items and collapses the rest behind a "Show more" link
/// to avoid overwhelming the screen with very long recipe lists.
class _SectionPreview extends StatefulWidget {
  final String title;
  final List<String> items;

  /// Whether to prefix each item with its 1-based index number.
  final bool numbered;

  const _SectionPreview({
    required this.title,
    required this.items,
    this.numbered = false,
  });

  @override
  State<_SectionPreview> createState() => _SectionPreviewState();
}

class _SectionPreviewState extends State<_SectionPreview> {
  /// Maximum items shown before the "Show more" link appears.
  static const _previewLimit = 5;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final shown = _expanded
        ? widget.items
        : widget.items.take(_previewLimit).toList();
    final hasMore = widget.items.length > _previewLimit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title,
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        ...shown.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                widget.numbered ? '${e.key + 1}. ${e.value}' : '• ${e.value}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )),
        if (hasMore)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(_expanded
                ? 'Show less'
                : 'Show ${widget.items.length - _previewLimit} more…'),
          ),
      ],
    );
  }
}
