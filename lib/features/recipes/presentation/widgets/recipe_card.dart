import 'dart:io';
import 'package:flutter/material.dart';
import '../../domain/recipe.dart';

/// A Material card that summarises a single [Recipe] in the list grid.
///
/// Displays the cover photo (or a placeholder), title, metadata chips for
/// prep time and servings, and up to three tag chips.  Tapping calls [onTap].
class RecipeCard extends StatelessWidget {
  /// The recipe to display.
  final Recipe recipe;

  /// Called when the user taps anywhere on the card.
  final VoidCallback onTap;

  const RecipeCard({super.key, required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      /// Clip children to the card's rounded corners, important for the image.
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Cover photo ----
            _buildImage(colorScheme),

            // ---- Text content ----
            // Expanded fills the remaining cell height after the image.
            // ClipRect silently hides any overflow instead of showing the
            // debug overflow banner, which can appear at high font scales.
            Expanded(
              child: ClipRect(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Recipe title — at most 2 lines with ellipsis.
                      Text(
                        recipe.title,
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Prep time + servings row
                      if (recipe.prepTimeMinutes > 0 || recipe.servings > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              if (recipe.prepTimeMinutes > 0) ...[
                                Icon(Icons.timer_outlined,
                                    size: 14,
                                    color: colorScheme.onSurfaceVariant),
                                const SizedBox(width: 3),
                                Text(
                                  '${recipe.prepTimeMinutes} min',
                                  style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant),
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (recipe.servings > 0) ...[
                                Icon(Icons.people_outline,
                                    size: 14,
                                    color: colorScheme.onSurfaceVariant),
                                const SizedBox(width: 3),
                                Text(
                                  '${recipe.servings} serv.',
                                  style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ],
                          ),
                        ),

                      // Tag chips — capped at 3 so they don't push content out.
                      if (recipe.tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 6,
                            children: recipe.tags
                                .take(3)
                                .map((tag) => Chip(
                                      label: Text(tag,
                                          style: textTheme.labelSmall),
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                    ))
                                .toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the cover-photo section from the local file path stored in the
  /// recipe.  Falls back to a plain placeholder when no image is set or the
  /// file cannot be read (e.g. it was deleted outside the app).
  Widget _buildImage(ColorScheme colorScheme) {
    if (recipe.imagePath.isNotEmpty) {
      return Image.file(
        File(recipe.imagePath),
        height: 130,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => _placeholder(colorScheme),
      );
    }
    return _placeholder(colorScheme);
  }

  /// Plain coloured container with a food icon, shown when no image is set.
  Widget _placeholder(ColorScheme colorScheme) {
    return Container(
      height: 130,
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.restaurant,
          size: 48,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
