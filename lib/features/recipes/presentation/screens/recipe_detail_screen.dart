import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/pdf_service.dart';
import '../../data/recipe_repository.dart';
import '../../data/share_import_service.dart';
import '../../domain/recipe.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/recipy_colors.dart';

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
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteRecipeTitle),
        content: Text(l10n.deleteRecipeContent),
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

    if (confirmed == true) {
      await ref.read(recipeListProvider.notifier).deleteRecipe(recipeId);
      if (context.mounted) context.go(AppRoutes.recipes);
    }
  }

  /// Opens the system print/preview dialog for [recipe] as a PDF.
  Future<void> _printPdf(BuildContext context, WidgetRef ref, Recipe recipe) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(pdfServiceProvider).previewRecipe(recipe, labels: PdfLabels(
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context)!.pdfFailed(e.toString()))));
      }
    }
  }

  /// Shows a Save / Share bottom sheet for [recipe].
  void _showExportSheet(BuildContext context, WidgetRef ref, Recipe recipe) {
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
                  final path = await ref
                      .read(shareImportServiceProvider)
                      .saveRecipeToDevice(recipe);
                  if (context.mounted && path != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.savedToDevice(path))),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.exportFailed(e.toString()))),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: Text(l10n.shareViaApp),
              subtitle: Text(l10n.shareViaAppSubtitle),
              onTap: () async {
                Navigator.of(ctx).pop();
                try {
                  await ref.read(shareImportServiceProvider).shareRecipe(
                    recipe,
                    shareText: l10n.shareRecipeText(recipe.title),
                  );
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.shareFailed(e.toString()))),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    /// A family provider scoped to this [recipeId] that fetches the recipe
    /// once from SQLite.  Declared inline here so the family key is the
    /// integer ID rather than a string.
    final recipeAsync = ref.watch(_recipeDetailProvider(recipeId));

    return Scaffold(
      body: recipeAsync.when(
        // Keep showing existing data while a re-fetch is in progress so
        // mutations (favourite toggle, edit) don't cause a loading flash.
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(AppLocalizations.of(context)!.errorLoadingRecipe(e.toString()))),
        data: (recipe) {
          if (recipe == null) {
            return Center(child: Text(AppLocalizations.of(context)!.recipeNotFound));
          }
          return _RecipeDetailBody(
            recipe: recipe,
            onEdit: () async {
              await context.push('${AppRoutes.recipes}/$recipeId/edit');
              // Invalidate so the detail screen reloads after an edit.
              if (context.mounted) {
                ref.invalidate(_recipeDetailProvider(recipeId));
              }
            },
            onDelete: () => _delete(context, ref),
            onPdf: () => _printPdf(context, ref, recipe),
            onShare: () => _showExportSheet(context, ref, recipe),
            onToggleFavourite: (bool newValue) => ref
                .read(recipeListProvider.notifier)
                .toggleFavourite(recipe.id, newValue),
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
/// Family provider that fetches a single recipe by integer [id] from SQLite.
///
/// Watches [recipeListProvider] so that any write (edit, delete, import)
/// invalidates this provider and triggers a fresh fetch — ensuring the detail
/// screen always reflects the latest saved state.
final _recipeDetailProvider =
    FutureProvider.family<Recipe?, int>((ref, id) async {
  // Watch the list so any mutation (edit, favourite toggle) re-fetches this
  // provider. skipLoadingOnReload in the UI prevents the loading flash.
  ref.watch(recipeListProvider);
  return ref.read(recipeRepositoryProvider).getRecipe(id);
});

/// The scrollable body of the detail screen, extracted to keep
/// [RecipeDetailScreen] focused on data-fetching and action handling.
///
/// Uses [StatefulWidget] to allow future local state (e.g. scroll position,
/// animation controllers) without restructuring the widget tree.
class _RecipeDetailBody extends StatefulWidget {
  final Recipe recipe;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPdf;
  final VoidCallback onShare;
  final ValueChanged<bool> onToggleFavourite;

  const _RecipeDetailBody({
    required this.recipe,
    required this.onEdit,
    required this.onDelete,
    required this.onPdf,
    required this.onShare,
    required this.onToggleFavourite,
  });

  @override
  State<_RecipeDetailBody> createState() => _RecipeDetailBodyState();
}

class _RecipeDetailBodyState extends State<_RecipeDetailBody> {
  /// Local optimistic favourite state — updated immediately on tap so the icon
  /// switches without waiting for the provider round-trip.
  late bool _isFavourite;

  @override
  void initState() {
    super.initState();
    _isFavourite = widget.recipe.isFavourite;
  }

  @override
  void didUpdateWidget(_RecipeDetailBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync from provider if the value changed externally (e.g. after edit).
    if (oldWidget.recipe.isFavourite != widget.recipe.isFavourite) {
      _isFavourite = widget.recipe.isFavourite;
    }
  }

  /// Convenience getter so sub-builders don't have to write [widget.recipe].
  Recipe get r => widget.recipe;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    // SelectionArea makes every Text widget inside the scroll view
    // selectable — the user can long-press to copy ingredients, steps, etc.
    return SelectionArea(child: CustomScrollView(
      slivers: [
        // ── Collapsible app bar ───────────────────────────────────────────────
        // Always expands to 260 px. Shows the recipe photo when available,
        // falling back to a branded placeholder otherwise.
        SliverAppBar(
          expandedHeight: 260,
          pinned: true,
          backgroundColor: RecipyColors.paper,
          foregroundColor: RecipyColors.ink,
          // Suppress the M3 surface tint so the bar stays paper-coloured
          // when scrolled and the hero photo is no longer visible.
          surfaceTintColor: Colors.transparent,
          // Back button wrapped in the same frosted disc as the action buttons
          // so it stays legible over hero photos.
          leading: _AppBarAction(
            icon: Icons.arrow_back,
            tooltip: AppLocalizations.of(context)!.tooltipBack,
            onPressed: () => Navigator.of(context).pop(),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: ClipRRect(
              // Round only the bottom corners so the image flows into the
              // content area with a soft edge.
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(24)),
              child: r.imagePath.isNotEmpty
                  ? Image.file(
                      File(r.imagePath),
                      fit: BoxFit.cover,
                      // Show a plain container if the file has been deleted.
                      errorBuilder: (context, error, stack) => _heroPlaceholder(),
                    )
                  : _heroPlaceholder(),
            ),
          ),
          actions: [
            _AppBarAction(
              icon: _isFavourite ? Icons.favorite : Icons.favorite_border,
              tooltip: _isFavourite
                  ? AppLocalizations.of(context)!.tooltipUnfavourite
                  : AppLocalizations.of(context)!.tooltipFavourite,
              iconColor: _isFavourite ? Colors.red : null,
              onPressed: () {
                final newValue = !_isFavourite;
                setState(() => _isFavourite = newValue);
                widget.onToggleFavourite(newValue);
              },
            ),
            _AppBarAction(
              icon: Icons.share_outlined,
              tooltip: AppLocalizations.of(context)!.tooltipShare,
              onPressed: widget.onShare,
            ),
            _AppBarAction(
              icon: Icons.picture_as_pdf_outlined,
              tooltip: AppLocalizations.of(context)!.tooltipPdf,
              onPressed: widget.onPdf,
            ),
            _AppBarAction(
              icon: Icons.edit_outlined,
              tooltip: AppLocalizations.of(context)!.tooltipEdit,
              onPressed: widget.onEdit,
            ),
            _AppBarAction(
              icon: Icons.delete_outline,
              tooltip: AppLocalizations.of(context)!.tooltipDelete,
              onPressed: widget.onDelete,
            ),
            const SizedBox(width: 4),
          ],
        ),

        // ── Recipe content ────────────────────────────────────────────────────
        // 22 px horizontal padding follows the BRAND.md "generous whitespace"
        // principle.
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([

              // Recipe title — uses titleLarge from RecipyTheme (28 px, w500).
              Text(r.title, style: tt.titleLarge),
              const SizedBox(height: 8),

              // Optional short description or personal note.
              if (r.description.isNotEmpty) ...[
                Text(
                  r.description,
                  style: tt.bodyMedium?.copyWith(color: RecipyColors.inkSoft),
                ),
                const SizedBox(height: 12),
              ],

              // Time + servings row.
              if (r.prepTimeMinutes > 0 || r.servings > 0) ...[
                _MetaStrip(recipe: r),
                const SizedBox(height: 8),
              ],

              // Tags on their own line, below time/servings.
              if (r.tags.isNotEmpty) ...[
                _TagsRow(tags: r.tags),
                const SizedBox(height: 8),
              ],

              const SizedBox(height: 12),

              // ── Ingredients soft card ──────────────────────────────────────
              // BRAND.md §6: radius-18 card with a double box-shadow instead
              // of Material elevation.
              // Groups with a name render a sub-header inside the card;
              // a single unnamed group looks identical to the old flat list.
              if (r.ingredients.isNotEmpty) ...[
                _SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top-level eyebrow label — always shown.
                      Text(AppLocalizations.of(context)!.sectionIngredients, style: tt.labelSmall),
                      const SizedBox(height: 14),
                      ...r.ingredientGroups.expand((group) => [
                        // Group name sub-header — only rendered when non-empty.
                        if (group.name.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 8),
                            child: Text(
                              group.name,
                              style: tt.titleMedium?.copyWith(
                                color: RecipyColors.accent2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        ...group.items.map((ing) => _IngredientRow(text: ing)),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Steps soft card ────────────────────────────────────────────
              if (r.steps.isNotEmpty) ...[
                _SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Eyebrow label above the numbered steps.
                      Text(AppLocalizations.of(context)!.sectionMethod, style: tt.labelSmall),
                      const SizedBox(height: 14),
                      ...r.steps.asMap().entries.map(
                            (e) => _StepRow(
                              index: e.key + 1,
                              text: e.value,
                            ),
                          ),
                    ],
                  ),
                ),
              ],

              // ── Notes soft card ────────────────────────────────────────────
              // URLs inside notes are rendered as tappable links; tapping one
              // shows a confirmation dialog before opening the browser.
              if (r.notes.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppLocalizations.of(context)!.sectionNotes, style: tt.labelSmall),
                      const SizedBox(height: 14),
                      _NotesContent(
                        text: r.notes,
                        onLinkTap: (url) => _confirmAndLaunch(context, url),
                      ),
                    ],
                  ),
                ),
              ],

              // Bottom padding so the last card clears the FAB / nav bar.
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ],
    )); // end SelectionArea + CustomScrollView
  }

  /// Shows a confirmation dialog, then launches [url] in the default browser.
  Future<void> _confirmAndLaunch(BuildContext context, String url) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.openLinkTitle),
        content: Text(url, maxLines: 3, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.open),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  /// Full-bleed placeholder shown in the hero slot when no image is available.
  ///
  /// Uses [RecipyColors.soft] as a warm tinted background so the empty state
  /// still feels on-brand rather than showing a stark white or grey box.
  Widget _heroPlaceholder() => Container(
        color: RecipyColors.soft,
        child: Center(
          child: Icon(
            Icons.image_outlined,
            size: 56,
            color: RecipyColors.inkSoft,
          ),
        ),
      );
}

// ── Reusable sub-widgets ──────────────────────────────────────────────────────

/// Soft card container as specified in BRAND.md §6.
///
/// Radius 18, no Material elevation — uses a pair of box shadows to give a
/// natural, paper-like depth without a hard edge.
class _SoftCard extends StatelessWidget {
  final Widget child;
  const _SoftCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: RecipyColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          // Close ambient shadow — subtle lift off the page.
          BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 2,
              offset: Offset(0, 1)),
          // Far diffuse shadow — gives the card a floating feel.
          BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 24,
              offset: Offset(0, 8)),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(22), child: child),
    );
  }
}

/// Horizontal strip of time and servings chips rendered below the title.
class _MetaStrip extends StatelessWidget {
  final Recipe recipe;
  const _MetaStrip({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (recipe.prepTimeMinutes > 0)
          _MetaChip(
            icon: Icons.schedule_outlined,
            label: AppLocalizations.of(context)!.prepTimeLabel(recipe.prepTimeMinutes),
          ),
        if (recipe.servings > 0)
          _MetaChip(
            icon: Icons.people_outline,
            label: AppLocalizations.of(context)!.servingsLabel(recipe.servings),
          ),
      ],
    );
  }
}

/// A row of outline tag chips, shown on a separate line below [_MetaStrip].
class _TagsRow extends StatelessWidget {
  final List<String> tags;
  const _TagsRow({required this.tags});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: tags.map((t) => _TagChip(label: t)).toList(),
    );
  }
}

/// Renders [text] with any http/https URLs turned into tappable inline links.
///
/// Plain text segments are rendered with [bodyMedium]; URL segments are
/// rendered in [RecipyColors.accent] and call [onLinkTap] when tapped.
class _NotesContent extends StatelessWidget {
  final String text;
  final void Function(String url) onLinkTap;

  const _NotesContent({required this.text, required this.onLinkTap});

  // Matches http:// and https:// URLs.
  static final _urlRegex = RegExp(
    r'https?://[^\s]+',
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final spans = <InlineSpan>[];
    int cursor = 0;

    for (final match in _urlRegex.allMatches(text)) {
      // Plain text before this URL.
      if (match.start > cursor) {
        spans.add(TextSpan(
          text: text.substring(cursor, match.start),
          style: tt.bodyMedium,
        ));
      }
      // The URL itself — accent colour, underlined, tappable.
      final url = match.group(0)!;
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: GestureDetector(
          onTap: () => onLinkTap(url),
          child: Text(
            url,
            style: tt.bodyMedium?.copyWith(
              color: RecipyColors.accent,
              decoration: TextDecoration.underline,
              decorationColor: RecipyColors.accent,
            ),
          ),
        ),
      ));
      cursor = match.end;
    }

    // Any remaining plain text after the last URL.
    if (cursor < text.length) {
      spans.add(TextSpan(
        text: text.substring(cursor),
        style: tt.bodyMedium,
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }
}

/// Filled pill chip for numeric metadata (time, servings).
///
/// Uses [RecipyColors.soft] fill with [RecipyColors.accent2] text to sit
/// harmoniously against the paper background.
class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: RecipyColors.soft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: RecipyColors.accent2),
          const SizedBox(width: 5),
          Text(
            label,
            style: tt.bodySmall?.copyWith(
              color: RecipyColors.accent2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Outline pill chip for free-form tags (no background fill).
///
/// Styled to be visually lighter than [_MetaChip] so tags don't compete
/// with the time/servings metadata.
class _TagChip extends StatelessWidget {
  final String label;
  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: RecipyColors.rule),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: tt.bodySmall?.copyWith(color: RecipyColors.inkSoft),
      ),
    );
  }
}

/// A single ingredient line with an accent-coloured bullet dot.
///
/// The dot is rendered as a small [BoxShape.circle] container rather than a
/// Unicode bullet so its colour and size are fully controllable.
class _IngredientRow extends StatelessWidget {
  final String text;
  const _IngredientRow({required this.text});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Accent-coloured bullet dot, vertically centred on the first
          // line of text (offset by top: 6 to align with cap-height).
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6, right: 12),
            decoration: BoxDecoration(
              color: RecipyColors.accent,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(child: Text(text, style: tt.bodyMedium)),
        ],
      ),
    );
  }
}

/// A single numbered step with an accent-coloured circle badge.
///
/// The circle badge mirrors the style used in the original screen but adopts
/// [RecipyColors.accent] instead of the M3 primary colour swatch.
class _StepRow extends StatelessWidget {
  /// 1-based step number displayed inside the badge.
  final int index;
  final String text;
  const _StepRow({required this.index, required this.text});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Numbered circle badge — accent green fill, paper-tinted text.
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.only(right: 14, top: 1),
            decoration: BoxDecoration(
              color: RecipyColors.accent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: tt.labelSmall?.copyWith(
                color: RecipyColors.paperHi,
                // Reset the large letter-spacing set by RecipyTheme for
                // eyebrow labels — numerals look odd with wide tracking.
                letterSpacing: 0,
              ),
            ),
          ),
          Expanded(child: Text(text, style: tt.bodyMedium)),
        ],
      ),
    );
  }
}

/// An app bar icon button wrapped in a frosted white circular backdrop.
///
/// When the [SliverAppBar] is expanded and a hero photo fills the background,
/// plain icon buttons can become invisible against light or busy images.
/// This widget places a semi-transparent white disc behind the icon so the
/// button is always legible regardless of what is behind it.
class _AppBarAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? iconColor;

  const _AppBarAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: iconColor ?? RecipyColors.ink),
          ),
        ),
      ),
    );
  }
}
