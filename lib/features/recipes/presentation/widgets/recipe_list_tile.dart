import 'package:flutter/material.dart';
import '../../domain/recipe.dart';
import '../../../../l10n/app_localizations.dart';

/// A single-row list tile for the recipe list view.
///
/// Shows the recipe title on the first line and a compact metadata row
/// (prep time · servings · first two tags) on the second line.
/// Tapping anywhere calls [onTap]; long-pressing calls [onLongPress].
/// When [isSelected] is true a green overlay and a checkmark are shown,
/// mirroring the selection state of [RecipeCard] in grid view.
class RecipeListTile extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;

  const RecipeListTile({
    super.key,
    required this.recipe,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    // Build the subtitle string: "20 min · 4 servings · pasta, quick"
    final parts = <String>[
      if (recipe.prepTimeMinutes > 0)
        l10n.cardPrepTime(recipe.prepTimeMinutes),
      if (recipe.servings > 0) l10n.cardServings(recipe.servings),
      ...recipe.tags.take(2),
    ];
    final subtitle = parts.join(' · ');

    return Stack(
      children: [
        // The tile itself — Material so InkWell ripple clips correctly.
        Material(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.12)
              : colorScheme.surface,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe.title,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Checkmark shown only during selection mode.
                  if (isSelected)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: colorScheme.primary,
                        child: const Icon(
                          Icons.check,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // Thin divider at the bottom of each row, matching standard list UX.
        const Positioned(
          left: 16,
          right: 0,
          bottom: 0,
          child: Divider(height: 1, thickness: 0.5),
        ),
      ],
    );
  }
}
