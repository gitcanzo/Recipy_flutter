import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../recipes/domain/ingredient_group.dart';
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
/// 1. GialloZafferano HTML parser — used when the host is giallozafferano.it.
///    Extracts grouped ingredients from the site's `<dl>` structure and strips
///    step-reference numbers from the description.
/// 2. JSON-LD structured data (`<script type="application/ld+json">` with
///    `@type: Recipe`) — the standard format used by most modern recipe sites.
/// 3. Heuristic HTML scraping using CSS selectors common in popular WordPress
///    recipe plugins (WP Recipe Maker, Tasty Recipes, etc.).
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

    // --- Strategy 1: GialloZafferano-specific parser ---
    // Runs before JSON-LD because GZ's JSON-LD provides only a flat ingredient
    // list, whereas the HTML encodes proper ingredient groups.
    if (uri.host.contains('giallozafferano.it')) {
      final gzResult = await _tryGialloZafferano(document, url);
      if (gzResult != null) return ImportResult.success(gzResult);
    }

    // --- Strategy 2: JSON-LD structured data ---
    final jsonLdResult = _tryJsonLd(document, url);
    if (jsonLdResult != null) return ImportResult.success(jsonLdResult);

    // --- Strategy 3: Heuristic HTML scraping ---
    final heuristicResult = _tryHeuristic(document, url);
    if (heuristicResult != null) return ImportResult.success(heuristicResult);

    return const ImportResult.failure(
        'Could not extract recipe data from this page. '
        'Try filling in the details manually.');
  }

  // ---------------------------------------------------------------------------
  // Strategy 1 — GialloZafferano-specific parser
  // ---------------------------------------------------------------------------

  /// Parses a recipe page from giallozafferano.it using the site's own HTML
  /// structure, which provides richer data than its JSON-LD.
  ///
  /// Ingredient groups are encoded as a `<dl class="gz-list-ingredients">` with
  /// `<dt class="gz-title-ingredients">` headers and `<dd class="gz-ingredient">`
  /// items.  A single unnamed [IngredientGroup] is used when the page has no
  /// group headers (i.e. all `<dd>` elements appear before any `<dt>`).
  ///
  /// Step paragraphs embed photo-caption references as
  /// `<span class="num-step">N</span>` nodes.  These are removed from the DOM
  /// before reading `.text` so they never appear in the imported steps.
  ///
  /// The main recipe photo is downloaded and saved locally so it is available
  /// offline like any other recipe image.
  ///
  /// Returns `null` if the page does not match the expected structure.
  Future<Recipe?> _tryGialloZafferano(Document document, String sourceUrl) async {
    // Title — GZ uses h1.gz-title-recipe or falls back to the generic h1.
    final String title =
        document.querySelector('h1.gz-title-recipe')?.text.trim() ??
            document.querySelector('h1')?.text.trim() ??
            '';
    if (title.isEmpty) return null;

    // Description — intentionally left blank for GZ imports.
    // The introductory paragraph is usually a marketing blurb and adds little
    // practical value once the recipe is saved locally.
    const String description = '';

    // Prep + cook time — extracted from the JSON-LD block that GZ includes on
    // every recipe page.
    int prepMins = 0;
    final scripts =
        document.querySelectorAll('script[type="application/ld+json"]');
    for (final script in scripts) {
      try {
        final dynamic json = jsonDecode(script.text.trim());
        final List<dynamic> items = json is List ? json : [json];
        for (final dynamic item in items) {
          if (item is Map &&
              (item['@type'] == 'Recipe' ||
                  (item['@type'] is List &&
                      (item['@type'] as List).contains('Recipe')))) {
            prepMins = _parseDuration(item['prepTime'] as String?) +
                _parseDuration(item['cookTime'] as String?);
            break;
          }
        }
      } catch (_) {
        continue;
      }
    }

    // Tags — GZ lists category links inside `.gz-list-featured-data-other`.
    // Each category is an <a> element whose text is the tag name.
    final tags = document
        .querySelectorAll('.gz-list-featured-data-other a')
        .map((e) => e.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    // Servings — GZ renders the yield as "Dosi per: N persone" inside
    // `.gz-list-featured-data`.  We scan all items and stop at the first one
    // that contains the word "Dosi" (case-insensitive) to avoid accidentally
    // picking up a time value from an earlier span.
    int servings = 0;
    for (final el
        in document.querySelectorAll('.gz-list-featured-data li')) {
      final text = el.text.trim();
      if (text.toLowerCase().contains('dosi')) {
        final match = RegExp(r'\d+').firstMatch(text);
        if (match != null) {
          servings = int.parse(match.group(0)!);
        }
        break;
      }
    }

    // Steps — `.gz-content-recipe-step p` contains each step paragraph.
    // GZ embeds photo-caption references as `<span class="num-step">N</span>`
    // inline in the step text.  Remove those DOM nodes before reading `.text`
    // so the numbers never appear in the imported content.
    final stepElements =
        document.querySelectorAll('.gz-content-recipe-step p');
    final steps = <String>[];
    for (final el in stepElements) {
      // Collect span.num-step nodes first to avoid modifying the list while
      // iterating over it.
      final numStepSpans = el.querySelectorAll('span.num-step').toList();
      for (final span in numStepSpans) {
        span.remove();
      }
      final text = el.text.trim();
      if (text.isNotEmpty) steps.add(text);
    }

    // Ingredient groups — walk the <dl> definition list, treating each <dt>
    // as the start of a new group and each <dd> as an item in the current group.
    final groups = <IngredientGroup>[];
    for (final dl
        in document.querySelectorAll('dl.gz-list-ingredients')) {
      // Current group accumulator.  Starts unnamed; a <dt> updates the name.
      String currentGroupName = '';
      List<String> currentItems = [];

      for (final node in dl.children) {
        if (node.localName == 'dt') {
          // Save the previous group when we encounter a new header — but only
          // if it has items (avoids empty groups when two <dt>s appear in a row).
          if (currentItems.isNotEmpty) {
            groups.add(IngredientGroup(
                name: currentGroupName, items: currentItems));
            currentItems = [];
          }
          currentGroupName = node.text.trim();
        } else if (node.localName == 'dd' &&
            node.classes.contains('gz-ingredient')) {
          // Ingredient text: combine the ingredient name and its quantity.
          // The name is in an <a> tag; the quantity is in a <span>.
          final name = (node.querySelector('a') ?? node).text.trim();
          final quantity = node.querySelector('span')?.text.trim() ?? '';
          // Normalise whitespace inside the quantity string (GZ uses newlines).
          final cleanQty =
              quantity.replaceAll(RegExp(r'\s+'), ' ').trim();
          final full = cleanQty.isNotEmpty ? '$name $cleanQty' : name;
          if (full.isNotEmpty) currentItems.add(full);
        }
      }
      // Flush the last group.
      if (currentItems.isNotEmpty) {
        groups.add(
            IngredientGroup(name: currentGroupName, items: currentItems));
      }
    }

    // If no groups were found the page structure may have changed; bail out
    // so the JSON-LD fallback can try instead.
    if (groups.isEmpty) return null;

    // Main recipe image — GZ puts it in `.gz-featured-image img` or the
    // JSON-LD `image` field.  Download it to local app storage so it is
    // available offline like any manually-added photo.
    final String imagePath = await _downloadGzImage(document);

    return Recipe(
      title: title,
      description: description,
      ingredientGroups: groups,
      steps: steps,
      prepTimeMinutes: prepMins,
      servings: servings,
      tags: tags,
      imagePath: imagePath,
      sourceUrl: sourceUrl,
      // Pre-fill the notes field with the source URL so it is visible and
      // clickable on the detail screen even after the user edits the recipe.
      notes: sourceUrl,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Finds the main recipe image URL on a GialloZafferano page and downloads
  /// it into the app's `recipe_images` directory.
  ///
  /// Tries selectors in order: `.gz-featured-image img[src]`, then the
  /// JSON-LD `image` field.  Returns an empty string if no image is found or
  /// if the download fails — a missing image is non-fatal.
  Future<String> _downloadGzImage(Document document) async {
    // Try the featured-image block first.
    String? imageUrl =
        document.querySelector('.gz-featured-image img')?.attributes['src'];

    // Fall back to JSON-LD image field.
    if (imageUrl == null || imageUrl.isEmpty) {
      for (final script in
          document.querySelectorAll('script[type="application/ld+json"]')) {
        try {
          final dynamic json = jsonDecode(script.text.trim());
          final List<dynamic> items = json is List ? json : [json];
          for (final dynamic item in items) {
            if (item is Map &&
                (item['@type'] == 'Recipe' ||
                    (item['@type'] is List &&
                        (item['@type'] as List).contains('Recipe')))) {
              final dynamic img = item['image'];
              if (img is String && img.isNotEmpty) {
                imageUrl = img;
              } else if (img is List && img.isNotEmpty) {
                imageUrl = img.first.toString();
              } else if (img is Map) {
                imageUrl = img['url'] as String?;
              }
              break;
            }
          }
        } catch (_) {
          continue;
        }
        if (imageUrl != null && imageUrl.isNotEmpty) break;
      }
    }

    if (imageUrl == null || imageUrl.isEmpty) return '';

    // Download the image bytes.
    try {
      final uri = Uri.tryParse(imageUrl);
      if (uri == null) return '';
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return '';

      // Derive a file extension from the URL path; default to .jpg.
      final urlPath = uri.path;
      final ext = p.extension(urlPath).isNotEmpty ? p.extension(urlPath) : '.jpg';

      // Save into the same directory used by the image picker in the edit screen.
      final dir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(dir.path, 'recipe_images'));
      if (!imagesDir.existsSync()) imagesDir.createSync(recursive: true);
      final filename = '${DateTime.now().millisecondsSinceEpoch}$ext';
      final file = File(p.join(imagesDir.path, filename));
      await file.writeAsBytes(response.bodyBytes);
      return file.path;
    } catch (_) {
      // Image download failure is non-fatal — the user can add a photo later.
      return '';
    }
  }

  // ---------------------------------------------------------------------------
  // Strategy 2 — JSON-LD
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
            ingredientGroups: [
              IngredientGroup.unnamed(
                  _extractStringList(item['recipeIngredient']))
            ],
            steps: _extractSteps(item['recipeInstructions']),
            prepTimeMinutes: prepMins + cookMins,
            servings: _parseServings(item['recipeYield']),
            // Combine category and cuisine into tags for filtering.
            tags: _extractStringList(item['recipeCategory']) +
                _extractStringList(item['recipeCuisine']),
            // Images are remote URLs; we don't download them on import.
            imagePath: '',
            sourceUrl: sourceUrl,
            notes: sourceUrl,
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
  // Strategy 3 — Heuristic HTML scraping
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
      ingredientGroups: [
        IngredientGroup.unnamed(_scrapeList(document, ingredientSelectors))
      ],
      steps: _scrapeList(document, stepSelectors),
      prepTimeMinutes: 0,
      servings: 0,
      tags: const [],
      imagePath: '',
      sourceUrl: sourceUrl,
      notes: sourceUrl,
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
