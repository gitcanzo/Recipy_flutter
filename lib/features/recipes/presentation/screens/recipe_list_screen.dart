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
import '../../../../l10n/app_localizations.dart';

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

class _RecipeListScreenState extends ConsumerState<RecipeListScreen>
    with WidgetsBindingObserver {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _showFavouritesOnly = false;

  /// IDs of currently selected recipes. Non-empty means selection mode is active.
  Set<int> _selectedIds = {};

  bool get _isSelecting => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(recipeListProvider.notifier).refresh();
    }
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds = Set.of(_selectedIds)..remove(id);
      } else {
        _selectedIds = Set.of(_selectedIds)..add(id);
      }
    });
  }

  void _clearSelection() => setState(() => _selectedIds = {});

  Future<void> _deleteSelected() async {
    final l10n = AppLocalizations.of(context)!;
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteRecipeTitle),
        content: Text(count == 1
            ? l10n.deleteRecipeContent
            : l10n.deleteMultipleRecipesContent(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    for (final id in _selectedIds.toList()) {
      await ref.read(recipeListProvider.notifier).deleteRecipe(id);
    }
    _clearSelection();
  }

  void _shareSelected(List<Recipe> allRecipes) {
    final selected = allRecipes.where((r) => _selectedIds.contains(r.id)).toList();
    if (selected.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    _showExportSheet(
      saveAction: () async {
        final service = ref.read(shareImportServiceProvider);
        String? path;
        if (selected.length == 1) {
          path = await service.saveRecipeToDevice(selected.first);
        } else {
          path = await service.saveCollectionToDevice(selected);
        }
        if (mounted && path != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.savedToDevice(path))),
          );
        }
      },
      shareAction: () async {
        final service = ref.read(shareImportServiceProvider);
        if (selected.length == 1) {
          await service.shareRecipe(selected.first,
              shareText: l10n.shareRecipeText(selected.first.title));
        } else {
          await service.shareCollection(selected,
              subject: l10n.shareCollectionSubject,
              shareText: l10n.shareCollectionText);
        }
      },
    );
  }

  /// Filters [recipes] by the favourites toggle and search query.
  List<Recipe> _filtered(List<Recipe> recipes) {
    var result = _showFavouritesOnly ? recipes.where((r) => r.isFavourite).toList() : recipes;
    if (_searchQuery.isEmpty) return result;
    final q = _searchQuery.toLowerCase();
    return result.where((r) {
      return r.title.toLowerCase().contains(q) ||
          r.description.toLowerCase().contains(q) ||
          r.tags.any((t) => t.toLowerCase().contains(q)) ||
          r.ingredients.any((i) => i.toLowerCase().contains(q));
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Share / import actions
  // ---------------------------------------------------------------------------

  /// Shows a Save / Share bottom sheet for the full recipe collection.
  void _exportAll(List<Recipe> recipes) {
    final l10n = AppLocalizations.of(context)!;
    if (recipes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noRecipesToExport)),
      );
      return;
    }
    _showExportSheet(
      saveAction: () async {
        final path = await ref
            .read(shareImportServiceProvider)
            .saveCollectionToDevice(recipes);
        if (mounted && path != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.savedToDevice(path))),
          );
        }
      },
      shareAction: () => ref.read(shareImportServiceProvider).shareCollection(
        recipes,
        subject: l10n.shareCollectionSubject,
        shareText: l10n.shareCollectionText,
      ),
    );
  }

  /// Shows a bottom sheet with Save to device / Share options, running
  /// [saveAction] or [shareAction] and reporting errors via a snackbar.
  void _showExportSheet({
    required Future<void> Function() saveAction,
    required Future<void> Function() shareAction,
  }) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.save_alt_outlined),
              title: Text(l10n.saveToDevice),
              subtitle: Text(l10n.saveToDeviceSubtitle),
              onTap: () async {
                Navigator.of(ctx).pop();
                try {
                  await saveAction();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.exportFailed(e.toString()))),
                    );
                  }
                }
                if (mounted) _clearSelection();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: Text(l10n.shareViaApp),
              subtitle: Text(l10n.shareViaAppSubtitle),
              onTap: () async {
                Navigator.of(ctx).pop();
                try {
                  await shareAction();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.exportFailed(e.toString()))),
                    );
                  }
                }
                if (mounted) _clearSelection();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Generates a recipe book PDF from all [recipes] and opens the system
  /// print / preview dialog.
  Future<void> _exportPdfBook(List<Recipe> recipes) async {
    final l10n = AppLocalizations.of(context)!;
    if (recipes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noRecipesToExport)),
      );
      return;
    }
    try {
      await ref.read(pdfServiceProvider).previewBook(recipes, labels: PdfLabels(
        sectionIngredients: l10n.pdfSectionIngredients,
        sectionSteps: l10n.pdfSectionSteps,
        sectionNotes: l10n.pdfSectionNotes,
        bookTitle: l10n.pdfBookTitle,
        generatedBy: l10n.pdfGeneratedBy,
        contents: l10n.pdfContents,
        prepTime: (m) => l10n.pdfPrepTime(m),
        serves: (c) => l10n.pdfServes(c),
        pageOf: (p, t) => l10n.pdfPageOf(p, t),
        recipeCount: (c) => l10n.pdfRecipeCount(c),
        sourceLabel: (u) => l10n.pdfSourceLabel(u),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.pdfFailed(e.toString()))));
      }
    }
  }

  /// Filters [incoming] against [existing], returning only recipes whose title
  /// (case-insensitive) is not already present.  [skipped] receives the count
  /// of duplicates that were removed.
  ({List<Recipe> toImport, int skipped}) _deduplicateImport(
    List<Recipe> incoming,
    List<Recipe> existing,
  ) {
    final existingTitles =
        existing.map((r) => r.title.toLowerCase()).toSet();
    final toImport =
        incoming.where((r) => !existingTitles.contains(r.title.toLowerCase())).toList();
    return (toImport: toImport, skipped: incoming.length - toImport.length);
  }

  /// Shows the import confirmation dialog for [parsed] recipes, then
  /// deduplicates and inserts on confirmation.  Used by both the in-app file
  /// picker and the intent-based import path.
  Future<void> _confirmAndImport(List<Recipe> parsed) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.importConfirmTitle),
        content: Text(
          parsed.length == 1
              ? l10n.importConfirmContentOne(parsed.first.title)
              : l10n.importConfirmContentMany(parsed.length),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.buttonImport),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final existing = ref.read(recipeListProvider).valueOrNull ?? [];
    final (:toImport, :skipped) = _deduplicateImport(parsed, existing);

    if (toImport.isNotEmpty) {
      await ref.read(recipeListProvider.notifier).importRecipes(toImport);
    }

    final String msg;
    if (toImport.isEmpty) {
      msg = l10n.importAllDuplicates;
    } else {
      final importedMsg = toImport.length == 1
          ? l10n.recipeImportedOne
          : l10n.recipesImportedMany(toImport.length);
      final skippedMsg = skipped == 1
          ? l10n.importSkippedOne
          : skipped > 1
              ? l10n.importSkippedMany(skipped)
              : null;
      msg = skippedMsg != null ? '$importedMsg $skippedMsg' : importedMsg;
    }
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Opens the file picker, parses the selected file, then shows a
  /// confirmation dialog before inserting.
  Future<void> _import() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final parsed = await ref.read(shareImportServiceProvider).pickAndImport();
      if (parsed.isEmpty) return;
      await _confirmAndImport(parsed);
    } catch (e) {
      if (mounted) {
        final msg = e is FormatException && e.message == 'json_not_recipe_data'
            ? l10n.jsonNotRecipeData
            : e is FormatException && e.message == 'json_unrecognised_format'
                ? l10n.jsonUnrecognisedFormat
                : l10n.importFailed(e.toString());
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  /// Shows a bottom sheet with two options: create a new recipe manually or
  /// import one from a URL.
  void _showAddOptions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.newRecipeOption),
              subtitle: Text(l10n.newRecipeOptionSubtitle),
              onTap: () {
                Navigator.of(ctx).pop();
                context.push('${AppRoutes.recipes}/new');
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(l10n.importFromUrlOption),
              subtitle: Text(l10n.importFromUrlOptionSubtitle),
              onTap: () {
                Navigator.of(ctx).pop();
                context.push(AppRoutes.urlImport);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(recipeListProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Show a confirmation dialog whenever a file intent delivers pending recipes.
    ref.listen<List<Recipe>>(pendingImportProvider, (previous, recipes) {
      if (recipes.isEmpty) return;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        ref.read(pendingImportProvider.notifier).state = const [];
        await _confirmAndImport(recipes);
      });
    });

    final isSelecting = _selectedIds.isNotEmpty;
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      // Back button exits selection mode instead of navigating away.
      canPop: !isSelecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _clearSelection();
      },
      child: Scaffold(
        // ---- App bar ----
        appBar: isSelecting
            ? AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _clearSelection,
                ),
                title: Text('${_selectedIds.length}'),
                actions: [
                  recipesAsync.maybeWhen(
                    data: (recipes) => IconButton(
                      icon: const Icon(Icons.share_outlined),
                      tooltip: l10n.tooltipShare,
                      onPressed: () => _shareSelected(recipes),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: l10n.tooltipDelete,
                    onPressed: _deleteSelected,
                  ),
                ],
              )
            : AppBar(
                title: Image.asset(
                  'assets/images/wordmark.png',
                  height: 45,
                  fit: BoxFit.contain,
                ),
                actions: [
                  recipesAsync.maybeWhen(
                    data: (recipes) => PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      tooltip: l10n.moreActions,
                      onSelected: (value) {
                        if (value == 'export') _exportAll(recipes);
                        if (value == 'import') _import();
                        if (value == 'pdf') _exportPdfBook(recipes);
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'export',
                          child: ListTile(
                            leading: const Icon(Icons.upload_outlined),
                            title: Text(l10n.exportCollection),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'import',
                          child: ListTile(
                            leading: const Icon(Icons.download_outlined),
                            title: Text(l10n.importFromFile),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'pdf',
                          child: ListTile(
                            leading: const Icon(Icons.menu_book_outlined),
                            title: Text(l10n.printRecipeBook),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),

        // ---- Body ----
        body: Column(
          children: [
            // Search bar + filter chips — hidden during selection mode
            if (!isSelecting) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: SearchBar(
                  controller: _searchController,
                  hintText: l10n.searchHint,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FilterChip(
                    label: Text(l10n.filterFavourites),
                    avatar: Icon(
                      _showFavouritesOnly ? Icons.favorite : Icons.favorite_border,
                      size: 16,
                      color: _showFavouritesOnly ? Colors.red : null,
                    ),
                    selected: _showFavouritesOnly,
                    showCheckmark: false,
                    onSelected: (value) => setState(() => _showFavouritesOnly = value),
                  ),
                ),
              ),
            ],

            // Recipe count sub-header
            recipesAsync.maybeWhen(
              data: (recipes) {
                if (recipes.isEmpty) return const SizedBox.shrink();
                final filtered = _filtered(recipes);
                final isFiltered = _searchQuery.isNotEmpty || _showFavouritesOnly;
                final label = isFiltered
                    ? l10n.recipeCountFiltered(filtered.length, recipes.length)
                    : l10n.recipeCountAll(recipes.length);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),

            // Recipe grid
            Expanded(
              child: recipesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                    child: Text(l10n.couldNotLoadRecipes(e.toString()))),
                data: (recipes) {
                  final filtered = _filtered(recipes);

                  if (recipes.isEmpty) {
                    return EmptyState(
                      icon: Icons.menu_book_outlined,
                      message: l10n.noRecipesYet,
                      subMessage: l10n.noRecipesYetSub,
                    );
                  }

                  if (filtered.isEmpty) {
                    if (_showFavouritesOnly && _searchQuery.isEmpty) {
                      return EmptyState(
                        icon: Icons.favorite_border,
                        message: l10n.noFavouritesYet,
                        subMessage: l10n.noFavouritesYetSub,
                      );
                    }
                    return EmptyState(
                      icon: Icons.search_off,
                      message: l10n.noResultsFor(_searchQuery),
                      subMessage: l10n.noResultsForSub,
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      mainAxisExtent: 220,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final recipe = filtered[index];
                      final isSelected = _selectedIds.contains(recipe.id);
                      return RecipeCard(
                        recipe: recipe,
                        isSelected: isSelected,
                        onTap: isSelecting
                            ? () => _toggleSelection(recipe.id)
                            : () => context.push(
                                '${AppRoutes.recipes}/${recipe.id}'),
                        onLongPress: isSelecting
                            ? null
                            : () => _toggleSelection(recipe.id),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),

        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: isSelecting
            ? null
            : FloatingActionButton(
                onPressed: () => _showAddOptions(context),
                tooltip: l10n.addRecipeTooltip,
                child: const Icon(Icons.add),
              ),
      ),
    );
  }
}
