import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import '../../recipes/domain/recipe.dart';

/// The result of a URL import attempt.
///
/// On success [recipe] is non-null and [error] is null.
/// On failure [error] describes what went wrong and [recipe] is null.
class ImportResult {
  /// The partially-populated recipe parsed from the page.  The user will
  /// review and edit this before saving.
  final Recipe? recipe;

  /// Human-readable error message shown when parsing fails.
  final String? error;

  const ImportResult({this.recipe, this.error});

  /// Convenience constructor for a successful parse.
  const ImportResult.success(Recipe r) : recipe = r, error = null;

  /// Convenience constructor for a failed parse.
  const ImportResult.failure(String message) : recipe = null, error = message;
}

/// Fetches a web page and attempts to extract recipe information from its HTML.
///
/// Strategy (in order):
/// 1. Look for JSON-LD `<script type="application/ld+json">` blocks with
///    `@type: Recipe` — the structured-data format used by most modern recipe
///    sites (AllRecipes, Food Network, BBC Good Food, etc.).
/// 2. Fall back to heuristic HTML scraping using CSS selectors common in
///    popular WordPress recipe plugins (WP Recipe Maker, Tasty Recipes, etc.).
///
/// This is a best-effort parser. It does not execute JavaScript, so sites that
/// render content client-side will not be parsed. Users are expected to review
/// and complete the imported data before saving.
class UrlImportService {
  /// Fetches [url] and returns a partially-filled [Recipe] or an error.
  Future<ImportResult> importFromUrl(String url) async {
    // Validate that the URL is parseable before making a network request.
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      return const ImportResult.failure('Invalid URL');
    }

    late http.Response response;
    try {
      response = await http.get(uri, headers: {
        // Some sites block requests without a browser-like user-agent.
        'User-Agent':
            'Mozilla/5.0 (compatible; Recipy/1.0; +https://recipy.app)',
      }).timeout(const Duration(seconds: 15));
    } catch (e) {
      return ImportResult.failure('Could not reach the page: $e');
    }

    if (response.statusCode != 200) {
      return ImportResult.failure(
          'Page returned HTTP ${response.statusCode}');
    }

    final document = html_parser.parse(response.body);

    // --- Strategy 1: JSON-LD structured data ---
    final jsonLdResult = _tryJsonLd(document, url);
    if (jsonLdResult != null) return ImportResult.success(jsonLdResult);

    // --- Strategy 2: Heuristic HTML scraping ---
    final heuristicResult = _tryHeuristic(document, url);
    if (heuristicResult != null) return ImportResult.success(heuristicResult);

    return const ImportResult.failure(
        'Could not extract recipe data from this page. '
        'Try filling in the details manually.');
  }

  // ---------------------------------------------------------------------------
  // Strategy 1 — JSON-LD
  // ---------------------------------------------------------------------------

  /// Scans all `<script type="application/ld+json">` blocks in [document] and
  /// returns a [Recipe] when a block with `@type: Recipe` is found.
  ///
  /// Returns `null` if no suitable block is found or all blocks fail to parse.
  Recipe? _tryJsonLd(Document document, String sourceUrl) {
    final scripts =
        document.querySelectorAll('script[type="application/ld+json"]');

    for (final script in scripts) {
      try {
        // dart:convert's jsonDecode handles both JSON objects and arrays.
        final dynamic json = jsonDecode(script.text.trim());

        // The LD+JSON payload may be a single object or a list; normalise.
        final List<dynamic> items = json is List ? json : [json];

        for (final dynamic item in items) {
          if (item is! Map) continue;

          // @type can be a plain string or a list of strings.
          final dynamic type = item['@type'];
          final bool isRecipe = type == 'Recipe' ||
              (type is List && type.contains('Recipe'));
          if (!isRecipe) continue;

          // Sum prep + cook times; either may be absent.
          final int prepMins = _parseDuration(item['prepTime'] as String?);
          final int cookMins = _parseDuration(item['cookTime'] as String?);

          return Recipe(
            title: item['name'] as String? ?? '',
            description: item['description'] as String? ?? '',
            ingredients: _extractStringList(item['recipeIngredient']),
            steps: _extractSteps(item['recipeInstructions']),
            prepTimeMinutes: prepMins + cookMins,
            servings: _parseServings(item['recipeYield']),
            // Combine category and cuisine into tags for filtering.
            tags: _extractStringList(item['recipeCategory']) +
                _extractStringList(item['recipeCuisine']),
            // Images are remote URLs; we don't download them on import.
            imagePath: '',
            sourceUrl: sourceUrl,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }
      } catch (_) {
        // If one JSON-LD block is malformed, move on to the next.
        continue;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Strategy 2 — Heuristic HTML scraping
  // ---------------------------------------------------------------------------

  /// Tries common CSS selectors used by popular WordPress recipe plugins and
  /// schema.org `itemprop` attributes to extract ingredients and steps.
  ///
  /// Returns `null` only if even a page title cannot be found.
  Recipe? _tryHeuristic(Document document, String sourceUrl) {
    // Use the first <h1> or the <title> tag as the recipe name.
    final String title = document.querySelector('h1')?.text.trim() ??
        document.querySelector('title')?.text.trim() ??
        '';

    if (title.isEmpty) return null;

    // Ordered list of ingredient selectors to try, most-specific first.
    final ingredientSelectors = [
      '.wprm-recipe-ingredient',
      '.tasty-recipes-ingredients li',
      '.recipe-ingredients li',
      '[itemprop="recipeIngredient"]',
    ];

    // Ordered list of step selectors to try, most-specific first.
    final stepSelectors = [
      '.wprm-recipe-instruction-text',
      '.tasty-recipes-instructions li',
      '.recipe-instructions li',
      '[itemprop="recipeInstructions"] li',
    ];

    return Recipe(
      title: title,
      description: '',
      ingredients: _scrapeList(document, ingredientSelectors),
      steps: _scrapeList(document, stepSelectors),
      prepTimeMinutes: 0,
      servings: 0,
      tags: const [],
      imagePath: '',
      sourceUrl: sourceUrl,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // Helper utilities
  // ---------------------------------------------------------------------------

  /// Flattens a JSON value that may be a string, a list of strings, or null
  /// into a `List<String>`, trimming whitespace from each element.
  List<String> _extractStringList(dynamic value) {
    if (value == null) return [];
    if (value is String) return [value.trim()];
    if (value is List) {
      return value
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [];
  }

  /// Extracts step text from `recipeInstructions`, which may be:
  /// - A plain string
  /// - A list of strings
  /// - A list of HowToStep objects (`{ "@type": "HowToStep", "text": "..." }`)
  /// - A list of HowToSection objects that nest HowToStep lists
  List<String> _extractSteps(dynamic value) {
    if (value == null) return [];
    if (value is String) return [value.trim()];
    if (value is List) {
      final result = <String>[];
      for (final dynamic item in value) {
        if (item is String) {
          result.add(item.trim());
        } else if (item is Map) {
          // HowToStep stores the instruction text in the 'text' field.
          final String? text = item['text'] as String?;
          if (text != null && text.isNotEmpty) result.add(text.trim());

          // HowToSection wraps multiple steps under 'itemListElement'.
          final dynamic nested = item['itemListElement'];
          if (nested is List) result.addAll(_extractSteps(nested));
        }
      }
      return result;
    }
    return [];
  }

  /// Parses an ISO 8601 duration string (e.g. `PT1H30M`) into total minutes.
  ///
  /// Returns 0 if the string is null or cannot be parsed.
  int _parseDuration(String? iso) {
    if (iso == null || iso.isEmpty) return 0;
    int minutes = 0;
    final RegExpMatch? hoursMatch = RegExp(r'(\d+)H').firstMatch(iso);
    final RegExpMatch? minsMatch = RegExp(r'(\d+)M').firstMatch(iso);
    if (hoursMatch != null) minutes += int.parse(hoursMatch.group(1)!) * 60;
    if (minsMatch != null) minutes += int.parse(minsMatch.group(1)!);
    return minutes;
  }

  /// Extracts a numeric servings count from the `recipeYield` field, which
  /// may be a string like "4 servings", a bare number string, or a list.
  int _parseServings(dynamic value) {
    if (value == null) return 0;
    final String raw =
        value is List ? value.first.toString() : value.toString();
    final RegExpMatch? match = RegExp(r'\d+').firstMatch(raw);
    return match != null ? int.parse(match.group(0)!) : 0;
  }

  /// Tries each selector in [selectors] in order and returns the text content
  /// of all matching elements from the first selector that yields any results.
  List<String> _scrapeList(Document doc, List<String> selectors) {
    for (final String selector in selectors) {
      final elements = doc.querySelectorAll(selector);
      if (elements.isNotEmpty) {
        return elements
            .map((e) => e.text.trim())
            .where((t) => t.isNotEmpty)
            .toList();
      }
    }
    return [];
  }
}
