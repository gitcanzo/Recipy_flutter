import 'dart:io';
import 'package:flutter/material.dart';
import '../../domain/recipe.dart';
import '../../../../l10n/app_localizations.dart';

/// A recipe card designed around its cover photo.
///
/// When a photo is available the image fills the entire card and the title,
/// metadata, and tags are overlaid on a dark gradient at the bottom.  When no
/// photo is set a solid brand-tinted placeholder is shown instead, keeping the
/// grid visually consistent.
///
/// Tapping anywhere on the card calls [onTap].
class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// When true the card shows a selected overlay and a checkmark.
  final bool isSelected;

  const RecipeCard({
    super.key,
    required this.recipe,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          fit: StackFit.expand,
          children: [
            recipe.imagePath.isNotEmpty
                ? _ImageCard(recipe: recipe)
                : _PlaceholderCard(recipe: recipe),
            // Selection overlay — IgnorePointer so taps fall through to InkWell
            if (isSelected) ...[
              IgnorePointer(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Color(0x6631964B),
                  ),
                ),
              ),
              const Positioned(
                top: 8,
                right: 8,
                child: IgnorePointer(
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: Color(0xFF31964B),
                    child: Icon(Icons.check, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Image-dominant variant
// ---------------------------------------------------------------------------

/// Card body used when the recipe has a cover photo.
///
/// The image fills the entire card.  A [LinearGradient] scrim covers the lower
/// third so white text remains legible regardless of the photo's colours.
class _ImageCard extends StatelessWidget {
  final Recipe recipe;

  const _ImageCard({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ---- Cover photo ----
        Image.file(
          File(recipe.imagePath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) =>
              _PlaceholderCard(recipe: recipe),
        ),

        // ---- Gradient scrim ----
        // Fades from transparent at the top to near-black at the bottom so
        // the text overlay is always readable without darkening the whole image.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.35, 1.0],
              colors: [Colors.transparent, Color(0xCC000000)],
            ),
          ),
        ),

        // ---- Text overlay ----
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tag chips (up to 2 so they don't crowd the title)
              if (recipe.tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Wrap(
                    spacing: 4,
                    children: recipe.tags
                        .take(2)
                        .map((tag) => _GlassChip(label: tag))
                        .toList(),
                  ),
                ),

              // Recipe title
              Text(
                recipe.title,
                style: textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  shadows: [
                    const Shadow(
                      color: Color(0x99000000),
                      blurRadius: 4,
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              // Metadata row
              if (recipe.prepTimeMinutes > 0 || recipe.servings > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _MetaRow(recipe: recipe, light: true),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Placeholder variant (no photo)
// ---------------------------------------------------------------------------

/// Card body used when the recipe has no cover photo.
///
/// Uses a tinted surface background with a centred icon so the grid still
/// looks intentional rather than broken.  Title and metadata are shown below
/// the icon in a more traditional layout.
class _PlaceholderCard extends StatelessWidget {
  final Recipe recipe;

  const _PlaceholderCard({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon area
          Expanded(
            flex: 3,
            child: Center(
              child: Icon(
                Icons.restaurant,
                size: 52,
                color: colorScheme.primary.withValues(alpha: 0.4),
              ),
            ),
          ),

          // Text area
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  _MetaRow(recipe: recipe, light: false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared small widgets
// ---------------------------------------------------------------------------

/// Translucent pill chip for overlaying tags on a photo background.
class _GlassChip extends StatelessWidget {
  final String label;

  const _GlassChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white,
                letterSpacing: 0.4,
              ),
        ),
      ),
    );
  }
}

/// One-line row showing prep time and/or servings.
///
/// [light] switches the icon and text colours to white for use on dark scrim
/// backgrounds; when false the theme's [onSurfaceVariant] colour is used.
class _MetaRow extends StatelessWidget {
  final Recipe recipe;

  /// True when rendering over a dark photo scrim; false on a plain surface.
  final bool light;

  const _MetaRow({required this.recipe, required this.light});

  @override
  Widget build(BuildContext context) {
    final color = light
        ? Colors.white.withValues(alpha: 0.85)
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final style = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: color, fontSize: 11);

    return Row(
      children: [
        if (recipe.prepTimeMinutes > 0) ...[
          Icon(Icons.timer_outlined, size: 12, color: color),
          const SizedBox(width: 3),
          Text(AppLocalizations.of(context)!.cardPrepTime(recipe.prepTimeMinutes), style: style),
          const SizedBox(width: 10),
        ],
        if (recipe.servings > 0) ...[
          Icon(Icons.people_outline, size: 12, color: color),
          const SizedBox(width: 3),
          Text(AppLocalizations.of(context)!.cardServings(recipe.servings), style: style),
        ],
      ],
    );
  }
}
