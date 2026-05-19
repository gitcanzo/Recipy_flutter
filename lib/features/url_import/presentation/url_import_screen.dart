import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/url_import_service.dart';
import '../../../core/router/app_router.dart';
import '../../../l10n/app_localizations.dart';

/// Screen that lets the user paste a recipe URL and import it.
///
/// Flow:
/// 1. User pastes a URL and taps "Import".
/// 2. [UrlImportService] fetches the page and attempts to parse it.
/// 3. On success the user is pushed to [RecipeEditScreen] pre-populated with
///    the parsed data (via GoRouter's `extra` parameter) so they can review
///    and complete all fields before saving — exactly like creating a recipe
///    from scratch but with the fields already filled in.
/// 4. If parsing fails, an error card is shown and the user can try a
///    different URL or enter the recipe manually.
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

  /// Error message from the most recent failed import attempt, or null.
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  /// Fetches and parses the URL currently in [_urlController].
  ///
  /// On success pushes to [AppRoutes.recipeNew] with the parsed [Recipe] as
  /// GoRouter `extra` so [RecipeEditScreen] can seed its form fields without
  /// an additional database round-trip.
  Future<void> _import() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isImporting = true;
      _error = null;
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

    setState(() => _isImporting = false);

    // Navigate to the edit screen pre-populated with the parsed recipe.
    // The user reviews every field before tapping "Save" — no separate
    // preview step needed.
    context.push(AppRoutes.recipeNew, extra: result.recipe);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.importFromUrlTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- URL input row ----
          Text(
            AppLocalizations.of(context)!.importFromUrlInstruction,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.urlHint,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.link),
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
                    : Text(AppLocalizations.of(context)!.buttonImport),
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
        ],
      ),
    );
  }
}
