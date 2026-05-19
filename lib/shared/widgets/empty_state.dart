import 'package:flutter/material.dart';

/// A generic empty-state placeholder used when a list has no items.
///
/// Shows a large tinted icon inside a soft circular container, a headline, and
/// an optional sub-message.  Pass an [onAction] callback and [actionLabel] to
/// render a call-to-action [FilledButton].
class EmptyState extends StatelessWidget {
  /// Large icon displayed inside the circular container.
  final IconData icon;

  /// Short headline explaining the empty state.
  final String message;

  /// Optional secondary text with more context or instructions.
  final String? subMessage;

  /// Label for the optional action button.  Requires [onAction] to be set.
  final String? actionLabel;

  /// Called when the user taps the action button.
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.subMessage,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon inside a tinted circle — more grounded than a bare icon
            // floating on a white background.
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 44,
                color: colorScheme.onPrimaryContainer,
              ),
            ),

            const SizedBox(height: 24),

            Text(
              message,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),

            if (subMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                subMessage!,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
