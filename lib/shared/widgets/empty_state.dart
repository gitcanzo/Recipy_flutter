import 'package:flutter/material.dart';

/// A generic empty-state placeholder used when a list has no items.
///
/// Shows a centered icon, a headline, and an optional sub-message. Pass an
/// [onAction] callback and [actionLabel] to render a call-to-action button
/// (e.g. "Add your first recipe").
class EmptyState extends StatelessWidget {
  /// Large icon displayed above the message.
  final IconData icon;

  /// Short headline explaining the empty state.
  final String message;

  /// Optional secondary text with more context or instructions.
  final String? subMessage;

  /// Label for the optional action button. Requires [onAction] to be set.
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (subMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                subMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
