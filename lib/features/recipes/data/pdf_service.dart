import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../domain/ingredient_group.dart';
import '../domain/recipe.dart';

/// Provides a singleton [PdfService] instance for the app's lifetime.
final pdfServiceProvider = Provider<PdfService>((ref) => PdfService());

/// Localised string labels passed into [PdfService] by the UI layer.
class PdfLabels {
  final String sectionIngredients;
  final String sectionSteps;
  final String sectionNotes;
  final String bookTitle;
  final String generatedBy;
  final String contents;
  final String Function(int minutes) prepTime;
  final String Function(int count) serves;
  final String Function(int page, int total) pageOf;
  final String Function(int count) recipeCount;
  final String Function(String url) sourceLabel;

  const PdfLabels({
    required this.sectionIngredients,
    required this.sectionSteps,
    required this.sectionNotes,
    required this.bookTitle,
    required this.generatedBy,
    required this.contents,
    required this.prepTime,
    required this.serves,
    required this.pageOf,
    required this.recipeCount,
    required this.sourceLabel,
  });
}

/// Generates PDF documents for individual recipes and full recipe books.
///
/// Two entry points:
/// - [previewRecipe] — shows the system print/preview dialog for one recipe.
/// - [previewBook]   — shows the system print/preview dialog for all recipes.
///
/// The [printing] package's [Printing.layoutPdf] call handles the preview UI,
/// sharing, and actual printing on every supported platform (Android, iOS,
/// Windows, macOS, Linux, Web) without any platform-specific code here.
class PdfService {
  // ---------------------------------------------------------------------------
  // Brand colours (matching AppTheme seed #31964B — forest green)
  // ---------------------------------------------------------------------------

  /// Primary green used for headings, dividers, and step badges.
  static const _green = PdfColor.fromInt(0xFF31964B);

  /// A lighter tint of the primary green used for alternating row backgrounds
  /// and section headers so the palette stays coherent throughout the PDF.
  static const _greenLight = PdfColor.fromInt(0xFFE8F5EC);

  /// Dark near-black used for body text — softer than pure black on paper.
  static const _textDark = PdfColor.fromInt(0xFF1A1A1A);

  /// Medium grey for secondary text (metadata, source URLs, page numbers).
  static const _textGrey = PdfColor.fromInt(0xFF666666);

  // ---------------------------------------------------------------------------
  // Public entry points
  // ---------------------------------------------------------------------------

  /// Returns true on desktop platforms where [Printing.layoutPdf] is
  /// unsupported or undesirable — we open the PDF in the system viewer instead.
  bool get _useSystemViewer =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  /// Generates a PDF for [recipe] and opens it.
  ///
  /// On mobile/web, uses [Printing.layoutPdf] to show the native print dialog.
  /// On desktop (macOS, Windows, Linux), saves to a temp file and opens it in
  /// the default PDF viewer (e.g. Preview on macOS, Adobe/Edge on Windows).
  Future<void> previewRecipe(Recipe recipe, {required PdfLabels labels}) async {
    if (_useSystemViewer) {
      final doc = await _buildRecipeDoc(recipe, PdfPageFormat.a4, labels);
      await _openInSystemViewer(doc, _safeFilename(recipe.title));
    } else {
      await Printing.layoutPdf(
        name: _safeFilename(recipe.title),
        onLayout: (format) async {
          final doc = await _buildRecipeDoc(recipe, format, labels);
          return doc.save();
        },
      );
    }
  }

  /// Generates a recipe book PDF for all [recipes] and opens it.
  ///
  /// The book includes a cover page, a table of contents, and one page (or
  /// more for long recipes) per recipe.  Desktop platforms open in the system
  /// PDF viewer; mobile shows the native print dialog.
  Future<void> previewBook(List<Recipe> recipes, {required PdfLabels labels}) async {
    if (_useSystemViewer) {
      final doc = await _buildBookDoc(recipes, PdfPageFormat.a4, labels);
      await _openInSystemViewer(doc, 'Recipy_Book');
    } else {
      await Printing.layoutPdf(
        name: 'Recipy_Book',
        onLayout: (format) async {
          final doc = await _buildBookDoc(recipes, format, labels);
          return doc.save();
        },
      );
    }
  }

  /// Saves [doc] to a temp file and opens it in the default system PDF viewer.
  Future<void> _openInSystemViewer(pw.Document doc, String name) async {
    // getTemporaryDirectory() may return a path that doesn't exist yet inside
    // the macOS sandbox — use getApplicationSupportDirectory() which is always
    // created for us, then create a 'pdfs' subfolder to keep things tidy.
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'pdfs'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final file = File(p.join(dir.path, '$name.pdf'));
    await file.writeAsBytes(await doc.save());
    final uri = Uri.file(file.path);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw Exception('Could not open PDF: ${file.path}');
    }
  }

  // ---------------------------------------------------------------------------
  // Single-recipe document
  // ---------------------------------------------------------------------------

  /// Builds a [pw.Document] containing one recipe formatted as a clean,
  /// printable recipe card.
  Future<pw.Document> _buildRecipeDoc(
      Recipe recipe, PdfPageFormat format, PdfLabels labels) async {
    final doc = pw.Document(
      title: recipe.title,
      author: 'Recipy',
    );

    // Load the cover image from disk if one exists.
    final coverImage = await _loadImage(recipe.imagePath);

    // Load a standard font so special characters render correctly on all
    // platforms — the default Helvetica subset can miss accented letters.
    final font = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();

    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(40),
        // Page footer with recipe title + page number.
        footer: (ctx) => _buildFooter(ctx, recipe.title, font, labels),
        build: (ctx) => [
          // Cover image (if available)
          if (coverImage != null) ...[
            // pw.ClipRRect causes a double.infinity assertion on Android when
            // the image has no explicit finite width.  Using pw.Container with
            // a BoxDecoration borderRadius achieves the same rounded-corner
            // effect without triggering the clip geometry calculation.
            pw.Container(
              height: 200,
              decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(8),
                image: pw.DecorationImage(
                  image: coverImage,
                  fit: pw.BoxFit.cover,
                ),
              ),
            ),
            pw.SizedBox(height: 16),
          ],

          // Recipe title
          pw.Text(
            recipe.title,
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 26,
              color: _green,
            ),
          ),
          pw.SizedBox(height: 8),

          // Metadata row: prep time, servings
          _buildMetaRow(recipe, font, labels),
          pw.SizedBox(height: 4),

          // Tags
          if (recipe.tags.isNotEmpty) ...[
            _buildTags(recipe.tags, font),
            pw.SizedBox(height: 4),
          ],

          // Description
          if (recipe.description.isNotEmpty) ...[
            pw.Text(recipe.description,
                style: pw.TextStyle(font: font, fontSize: 11, color: _textGrey)),
            pw.SizedBox(height: 4),
          ],

          // Source URL
          if (recipe.sourceUrl.isNotEmpty) ...[
            pw.Text(labels.sourceLabel(recipe.sourceUrl),
                style: pw.TextStyle(font: font, fontSize: 9, color: _textGrey)),
            pw.SizedBox(height: 4),
          ],

          pw.Divider(color: _green, thickness: 1.5),
          pw.SizedBox(height: 8),

          // Ingredients — header glued to first ingredient, rest can split freely
          ..._buildSectionWithContent(
            header: _buildSectionHeader(labels.sectionIngredients, fontBold),
            content: _buildIngredientGroupWidgets(recipe.ingredientGroups, font, fontBold),
            spacing: 6,
          ),
          pw.SizedBox(height: 16),

          // Steps — header glued to first step, rest can split freely
          ..._buildSectionWithContent(
            header: _buildSectionHeader(labels.sectionSteps, fontBold),
            content: _buildStepWidgets(recipe.steps, font, fontBold),
            spacing: 6,
          ),

          // Notes
          if (recipe.notes.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            ..._buildSectionWithContent(
              header: _buildSectionHeader(labels.sectionNotes, fontBold),
              content: [_buildNotesText(recipe.notes, font)],
              spacing: 6,
            ),
          ],
        ],
      ),
    );

    return doc;
  }

  // ---------------------------------------------------------------------------
  // Recipe book document
  // ---------------------------------------------------------------------------

  /// Builds a multi-page [pw.Document] recipe book with:
  /// - A cover page
  /// - A table of contents with accurate page numbers and clickable links
  /// - One section per recipe
  ///
  /// Page numbers in the TOC are resolved with a two-pass approach: the recipe
  /// sections are rendered to a temporary document first so we can count how
  /// many pages each recipe occupies.  Cover (1) + TOC (1) = 2 fixed pages
  /// precede the recipes, so recipe[i] starts on page 3 + sum of all previous
  /// recipe page counts.
  Future<pw.Document> _buildBookDoc(
      List<Recipe> recipes, PdfPageFormat format, PdfLabels labels) async {
    final font = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();
    final fontItalic = await PdfGoogleFonts.nunitoItalic();

    // Pre-load all cover images so we don't load them twice.
    final images = await Future.wait(
        recipes.map((r) => _loadImage(r.imagePath)));

    // ---- Pass 1: count pages per recipe ----
    // Render each recipe into its own temporary pw.Document and call save()
    // to force layout.  After save(), doc.document.pdfPageList.pages.length
    // gives the exact physical page count for that recipe — correct even when
    // long ingredient or step lists cause a MultiPage to overflow onto extra
    // pages.
    final pageCounts = <int>[];
    for (final (index, recipe) in recipes.indexed) {
      final tmp = pw.Document();
      tmp.addPage(
        pw.MultiPage(
          pageFormat: format,
          margin: const pw.EdgeInsets.all(40),
          build: (ctx) => _buildRecipePageWidgets(
              recipe, images[index], font, fontBold, fontItalic, labels),
        ),
      );
      await tmp.save(); // triggers layout; page list is now populated
      pageCounts.add(tmp.document.pdfPageList.pages.length);
    }

    // Compute the starting page number (1-based) for each recipe.
    // Pages 1 and 2 are the cover and TOC respectively.
    const fixedPages = 2;
    final startPages = <int>[];
    var running = fixedPages + 1;
    for (final count in pageCounts) {
      startPages.add(running);
      running += count;
    }

    // ---- Pass 2: build the final document ----
    final doc = pw.Document(
      title: 'My Recipe Book',
      author: 'Recipy',
    );

    // Cover page
    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.zero,
        build: (ctx) => _buildCoverPage(recipes.length, fontBold, font, labels),
      ),
    );

    // Table of contents — page numbers come from pass-1 computation.
    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(48),
        build: (ctx) =>
            _buildTocPage(recipes, startPages, fontBold, font, labels),
      ),
    );

    // Recipe sections — each title banner registers a pw.Anchor so that the
    // pw.Link in the TOC can navigate directly to it in a PDF viewer.
    for (final (index, recipe) in recipes.indexed) {
      final anchorName = 'recipe_$index';
      doc.addPage(
        pw.MultiPage(
          pageFormat: format,
          margin: const pw.EdgeInsets.all(40),
          footer: (ctx) => _buildFooter(ctx, recipe.title, font, labels),
          build: (ctx) => [
            // pw.Anchor registers the named destination used by pw.Link in
            // the TOC so PDF viewers can jump directly to this recipe.
            pw.Anchor(
              name: anchorName,
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    vertical: 6, horizontal: 10),
                decoration: const pw.BoxDecoration(color: _green),
                child: pw.Text(
                  recipe.title,
                  style: pw.TextStyle(
                      font: fontBold, fontSize: 18, color: PdfColors.white),
                ),
              ),
            ),
            pw.SizedBox(height: 10),
            ..._buildRecipePageWidgets(
                recipe, images[index], font, fontBold, fontItalic, labels)
                // Drop the first widget because pw.Anchor already renders the
                // title banner as its child above.
                .skip(1),
          ],
        ),
      );
    }

    return doc;
  }

  /// Returns the list of [pw.Widget]s that form the body of one recipe page.
  ///
  /// Extracted so the same widget list can be reused in the pass-1 page-count
  /// render and the pass-2 final document without duplication.
  List<pw.Widget> _buildRecipePageWidgets(
    Recipe recipe,
    pw.ImageProvider? coverImage,
    pw.Font font,
    pw.Font fontBold,
    pw.Font fontItalic,
    PdfLabels labels,
  ) {
    return [
      // Title banner (also used as pw.Anchor child in the final doc).
      pw.Container(
        padding:
            const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: const pw.BoxDecoration(color: _green),
        child: pw.Text(
          recipe.title,
          style: pw.TextStyle(
              font: fontBold, fontSize: 18, color: PdfColors.white),
        ),
      ),
      pw.SizedBox(height: 10),

      if (coverImage != null) ...[
        pw.Container(
          height: 160,
          decoration: pw.BoxDecoration(
            borderRadius: pw.BorderRadius.circular(6),
            image: pw.DecorationImage(
              image: coverImage,
              fit: pw.BoxFit.cover,
            ),
          ),
        ),
        pw.SizedBox(height: 10),
      ],

      _buildMetaRow(recipe, font, labels),
      pw.SizedBox(height: 4),

      if (recipe.tags.isNotEmpty) ...[
        _buildTags(recipe.tags, font),
        pw.SizedBox(height: 4),
      ],

      if (recipe.description.isNotEmpty) ...[
        pw.Text(recipe.description,
            style: pw.TextStyle(
                font: fontItalic, fontSize: 10, color: _textGrey)),
        pw.SizedBox(height: 4),
      ],

      pw.Divider(color: _green),
      pw.SizedBox(height: 6),

      ..._buildSectionWithContent(
        header: _buildSectionHeader(labels.sectionIngredients, fontBold),
        content: _buildIngredientGroupWidgets(recipe.ingredientGroups, font, fontBold),
        spacing: 4,
      ),
      pw.SizedBox(height: 12),

      ..._buildSectionWithContent(
        header: _buildSectionHeader(labels.sectionSteps, fontBold),
        content: _buildStepWidgets(recipe.steps, font, fontBold),
        spacing: 4,
      ),

      if (recipe.notes.isNotEmpty) ...[
        pw.SizedBox(height: 12),
        ..._buildSectionWithContent(
          header: _buildSectionHeader(labels.sectionNotes, fontBold),
          content: [_buildNotesText(recipe.notes, font)],
          spacing: 4,
        ),
      ],
    ];
  }

  // ---------------------------------------------------------------------------
  // Reusable PDF widget builders
  // ---------------------------------------------------------------------------

  /// Full-bleed green cover page with the book title and recipe count.
  pw.Widget _buildCoverPage(
      int recipeCount, pw.Font fontBold, pw.Font font, PdfLabels labels) {
    final date = DateFormat('MMMM yyyy').format(DateTime.now());
    return pw.Stack(
      children: [
        // Full-bleed green background.
        pw.Positioned.fill(
          child: pw.Container(color: _green),
        ),
        // Decorative light oval in the bottom-right corner.
        pw.Positioned(
          bottom: -80,
          right: -80,
          child: pw.Container(
            width: 300,
            height: 300,
            decoration: const pw.BoxDecoration(
              color: _greenLight,
              shape: pw.BoxShape.circle,
            ),
          ),
        ),
        // Content centred on the page.
        pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                labels.bookTitle,
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 36,
                  color: PdfColors.white,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Container(
                width: 60,
                height: 3,
                color: PdfColors.white,
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                labels.recipeCount(recipeCount),
                style: pw.TextStyle(
                    font: font, fontSize: 16, color: PdfColors.white),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                date,
                style: pw.TextStyle(
                    font: font, fontSize: 12, color: _greenLight),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                labels.generatedBy,
                style: pw.TextStyle(
                    font: font, fontSize: 10, color: _greenLight),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Table of contents page listing all recipe titles with clickable page
  /// number references.
  ///
  /// [startPages] contains the 1-based page number where each recipe begins,
  /// computed by the two-pass approach in [_buildBookDoc].  Each row is wrapped
  /// in a [pw.Link] targeting the [pw.Anchor] at the start of that recipe's
  /// section, enabling in-PDF navigation in viewers that support named
  /// destinations (e.g. Adobe Reader, Chrome PDF viewer).
  pw.Widget _buildTocPage(
    List<Recipe> recipes,
    List<int> startPages,
    pw.Font fontBold,
    pw.Font font,
    PdfLabels labels,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(labels.contents,
            style:
                pw.TextStyle(font: fontBold, fontSize: 24, color: _green)),
        pw.SizedBox(height: 4),
        pw.Divider(color: _green, thickness: 1.5),
        pw.SizedBox(height: 8),
        ...recipes.asMap().entries.map((entry) {
          final index = entry.key;
          final recipe = entry.value;
          final anchorName = 'recipe_$index';
          final pageNum = startPages[index];
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 3),
            // pw.Link makes the entire row tappable in PDF viewers that support
            // internal navigation (e.g. Adobe Reader, Chrome PDF viewer).
            child: pw.Link(
              destination: anchorName,
              child: pw.Row(
                children: [
                  // Display number (1-based) in green
                  pw.SizedBox(
                    width: 28,
                    child: pw.Text(
                      '${index + 1}.',
                      style: pw.TextStyle(
                          font: fontBold, fontSize: 11, color: _green),
                    ),
                  ),
                  // Recipe title — does not expand; dots fill the gap
                  pw.Text(recipe.title,
                      style: pw.TextStyle(
                          font: font, fontSize: 11, color: _green)),
                  pw.SizedBox(width: 6),
                  // Dot leader filling available space
                  pw.Expanded(
                    child: pw.Text(
                      '.' * 120,
                      maxLines: 1,
                      overflow: pw.TextOverflow.clip,
                      style: pw.TextStyle(
                          font: font,
                          fontSize: 11,
                          color: _textGrey,
                          letterSpacing: 1.5),
                    ),
                  ),
                  pw.SizedBox(width: 6),
                  // Page number pre-computed in pass 1
                  pw.Text(
                    '$pageNum',
                    style: pw.TextStyle(
                        font: fontBold, fontSize: 11, color: _green),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  /// Renders notes text with URLs turned into clickable pw.UrlLink spans.
  pw.Widget _buildNotesText(String notes, pw.Font font) {
    final urlRegex = RegExp(r'https?://[^\s]+', caseSensitive: false);
    final spans = <pw.InlineSpan>[];
    int cursor = 0;
    for (final match in urlRegex.allMatches(notes)) {
      if (match.start > cursor) {
        spans.add(pw.TextSpan(
          text: notes.substring(cursor, match.start),
          style: pw.TextStyle(font: font, fontSize: 11, color: _textDark),
        ));
      }
      final url = match.group(0)!;
      spans.add(pw.WidgetSpan(
        child: pw.UrlLink(
          destination: url,
          child: pw.Text(
            url,
            style: pw.TextStyle(
              font: font,
              fontSize: 11,
              color: PdfColors.blue,
              decoration: pw.TextDecoration.underline,
            ),
          ),
        ),
      ));
      cursor = match.end;
    }
    if (cursor < notes.length) {
      spans.add(pw.TextSpan(
        text: notes.substring(cursor),
        style: pw.TextStyle(font: font, fontSize: 11, color: _textDark),
      ));
    }
    if (spans.isEmpty) {
      return pw.Text(notes,
          style: pw.TextStyle(font: font, fontSize: 11, color: _textDark));
    }
    return pw.RichText(text: pw.TextSpan(children: spans));
  }

  /// Green section header kept together with the next widget via pw.Wrap
  /// to prevent the header appearing alone at the bottom of a page.
  pw.Widget _buildSectionHeader(String title, pw.Font fontBold) {
    return pw.Container(
      padding:
          const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: const pw.BoxDecoration(color: _greenLight),
      child: pw.Text(
        title,
        style:
            pw.TextStyle(font: fontBold, fontSize: 13, color: _green),
      ),
    );
  }

  /// Prep time and servings on one line with small icons replaced by labels.
  pw.Widget _buildMetaRow(Recipe recipe, pw.Font font, PdfLabels labels) {
    final parts = <String>[];
    if (recipe.prepTimeMinutes > 0) {
      parts.add(labels.prepTime(recipe.prepTimeMinutes));
    }
    if (recipe.servings > 0) {
      parts.add(labels.serves(recipe.servings));
    }
    if (parts.isEmpty) return pw.SizedBox();
    return pw.Text(
      parts.join('   •   '),
      style: pw.TextStyle(font: font, fontSize: 10, color: _textGrey),
    );
  }

  /// Wrapping row of tag chips.
  pw.Widget _buildTags(List<String> tags, pw.Font font) {
    return pw.Wrap(
      spacing: 4,
      runSpacing: 4,
      children: tags
          .map(
            (tag) => pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 7, vertical: 2),
              decoration: pw.BoxDecoration(
                color: _greenLight,
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(color: _green, width: 0.5),
              ),
              child: pw.Text(tag,
                  style: pw.TextStyle(
                      font: font, fontSize: 9, color: _green)),
            ),
          )
          .toList(),
    );
  }

  /// Returns a [pw.NewPage] guard followed by the header + first content item
  /// and then the remaining items individually.
  ///
  /// The [pw.NewPage] with [freeSpace] triggers a page break when fewer than
  /// 80pt remain on the current page — enough space for the header, spacing,
  /// and at least one line of content.  This prevents the header from appearing
  /// alone at the bottom of a page without locking all section content together.
  List<pw.Widget> _buildSectionWithContent({
    required pw.Widget header,
    required List<pw.Widget> content,
    required double spacing,
  }) {
    if (content.isEmpty) return [header];
    return [
      pw.NewPage(freeSpace: 80),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [header, pw.SizedBox(height: spacing), content.first],
      ),
      ...content.skip(1),
    ];
  }

  /// Returns ingredient rows as a flat list of widgets (for use with
  /// [_buildSectionWithContent] so each row can split across pages freely).
  List<pw.Widget> _buildIngredientGroupWidgets(
      List<IngredientGroup> groups, pw.Font font, pw.Font fontBold) {
    final widgets = <pw.Widget>[];
    int rowIndex = 0;

    for (final group in groups) {
      if (group.items.isEmpty) continue;
      if (group.name.isNotEmpty) {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 6, bottom: 2),
          child: pw.Text(group.name,
              style: pw.TextStyle(font: fontBold, fontSize: 11, color: _green)),
        ));
      }
      for (final item in group.items) {
        final isEven = rowIndex.isEven;
        rowIndex++;
        widgets.add(pw.Container(
          color: isEven ? _greenLight : PdfColors.white,
          padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 6,
                height: 6,
                margin: const pw.EdgeInsets.only(top: 3, right: 8),
                decoration: const pw.BoxDecoration(
                    color: _green, shape: pw.BoxShape.circle),
              ),
              pw.Expanded(
                child: pw.Text(item,
                    style: pw.TextStyle(
                        font: font, fontSize: 11, color: _textDark)),
              ),
            ],
          ),
        ));
      }
    }
    return widgets;
  }

  /// Returns step rows as a flat list of widgets (for use with
  /// [_buildSectionWithContent] so each step can split across pages freely).
  List<pw.Widget> _buildStepWidgets(
      List<String> steps, pw.Font font, pw.Font fontBold) {
    return steps.asMap().entries.map((entry) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 22,
              height: 22,
              margin: const pw.EdgeInsets.only(right: 8, top: 1),
              decoration: const pw.BoxDecoration(
                  color: _green, shape: pw.BoxShape.circle),
              alignment: pw.Alignment.center,
              child: pw.Text('${entry.key + 1}',
                  style: pw.TextStyle(
                      font: fontBold, fontSize: 9, color: PdfColors.white)),
            ),
            pw.Expanded(
              child: pw.Text(entry.value,
                  style:
                      pw.TextStyle(font: font, fontSize: 11, color: _textDark)),
            ),
          ],
        ),
      );
    }).toList();
  }

  /// Footer shown at the bottom of every page: recipe title on the left,
  /// "page X of Y" on the right.
  pw.Widget _buildFooter(
      pw.Context ctx, String title, pw.Font font, PdfLabels labels) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(title,
            style:
                pw.TextStyle(font: font, fontSize: 8, color: _textGrey)),
        pw.Text(
          labels.pageOf(ctx.pageNumber, ctx.pagesCount),
          style: pw.TextStyle(font: font, fontSize: 8, color: _textGrey),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Loads a recipe image from [path] and returns a [pw.ImageProvider], or
  /// null if no path is set or the file no longer exists on disk.
  Future<pw.ImageProvider?> _loadImage(String path) async {
    if (path.isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    try {
      final bytes = await file.readAsBytes();
      return pw.MemoryImage(bytes);
    } catch (_) {
      // If the image can't be read (permissions, corruption, etc.) we simply
      // omit it rather than crashing the PDF generation.
      return null;
    }
  }

  /// Writes [content] to a temporary file and returns the [File].
  ///
  /// Used when the caller needs a physical file (e.g. for sharing via
  /// [share_plus]) rather than just the in-memory bytes.
  Future<File> writeTempPdf(String filename, List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, filename));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Converts a recipe title to a safe filename by replacing characters that
  /// are invalid in file names with underscores.
  String _safeFilename(String title) {
    return title
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
  }
}
