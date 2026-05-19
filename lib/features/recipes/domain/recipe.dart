import 'dart:convert';
import 'ingredient_group.dart';

/// Represents a single recipe stored in the local SQLite database.
///
/// This is an immutable plain Dart class — use [copyWith] to produce modified
/// copies rather than mutating fields directly.
///
/// [id] is the SQLite auto-incremented primary key.  A value of 0 means the
/// recipe has not yet been inserted (i.e. it is being created for the first
/// time and has no row in the database yet).
class Recipe {
  /// SQLite auto-incremented primary key.  0 for unsaved recipes.
  final int id;

  /// Human-readable name of the recipe (e.g. "Spaghetti Carbonara").
  final String title;

  /// Optional short description or personal note about the recipe.
  final String description;

  /// Ordered list of ingredient groups.
  ///
  /// Most recipes will have a single unnamed group (i.e. [IngredientGroup.name]
  /// is empty), which is visually equivalent to the old flat ingredients list.
  /// Recipes with multiple components can use named groups (e.g. "Sauce",
  /// "Pasta dough").
  ///
  /// Stored as a JSON array in the `ingredients` TEXT column of SQLite.
  final List<IngredientGroup> ingredientGroups;

  /// Ordered list of preparation step strings.
  final List<String> steps;

  /// Approximate total preparation + cooking time in minutes.  0 means unset.
  final int prepTimeMinutes;

  /// Number of servings this recipe yields.  0 means unset.
  final int servings;

  /// Free-form tags used for filtering (e.g. ["vegetarian", "quick"]).
  final List<String> tags;

  /// Absolute path to the recipe's cover photo on the device's filesystem.
  /// Empty string means no photo has been saved yet.
  final String imagePath;

  /// The original URL this recipe was imported from, if any.
  /// Empty string means the recipe was created manually.
  final String sourceUrl;

  /// Free-form personal notes about the recipe (e.g. variations tried,
  /// sourcing tips, serving suggestions).  Empty string means no notes.
  final String notes;

  /// Whether the user has marked this recipe as a favourite.
  final bool isFavourite;

  /// Timestamp of when the recipe was first saved to the database.
  final DateTime createdAt;

  /// Timestamp of the most recent edit.
  final DateTime updatedAt;

  const Recipe({
    this.id = 0,
    required this.title,
    this.description = '',
    required this.ingredientGroups,
    required this.steps,
    this.prepTimeMinutes = 0,
    this.servings = 0,
    this.tags = const [],
    this.imagePath = '',
    this.sourceUrl = '',
    this.notes = '',
    this.isFavourite = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Convenience getter — flattens all group items into a single list.
  ///
  /// Useful for search indexing and export formats that don't support groups.
  List<String> get ingredients =>
      ingredientGroups.expand((g) => g.items).toList();

  // ---------------------------------------------------------------------------
  // SQLite serialisation
  // ---------------------------------------------------------------------------

  /// Creates a [Recipe] from a SQLite column-value map returned by sqflite.
  ///
  /// The `ingredients` TEXT column may contain two formats:
  /// 1. Legacy flat array:  `["200g pasta", "2 eggs"]`
  ///    → wrapped in a single unnamed [IngredientGroup] for backward compat.
  /// 2. Group array:  `[{"name":"Sauce","items":["…"]}, …]`
  ///    → decoded directly as [IngredientGroup] objects.
  factory Recipe.fromSqlite(Map<String, dynamic> row) {
    final ingredientGroups =
        _decodeIngredientGroups(row['ingredients'] as String? ?? '[]');

    return Recipe(
      id: row['id'] as int,
      title: row['title'] as String,
      description: row['description'] as String? ?? '',
      ingredientGroups: ingredientGroups,
      steps: List<String>.from(
          jsonDecode(row['steps'] as String? ?? '[]') as List),
      prepTimeMinutes: row['prepTime'] as int? ?? 0,
      servings: row['servings'] as int? ?? 0,
      tags: List<String>.from(
          jsonDecode(row['tags'] as String? ?? '[]') as List),
      imagePath: row['imagePath'] as String? ?? '',
      sourceUrl: row['sourceUrl'] as String? ?? '',
      notes: row['notes'] as String? ?? '',
      isFavourite: (row['isFavourite'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(row['createdAt'] as String),
      updatedAt: DateTime.parse(row['updatedAt'] as String),
    );
  }

  /// Decodes the `ingredients` column value into a list of [IngredientGroup]s.
  ///
  /// Handles both the legacy flat-string-array format and the new
  /// group-object format so old data is not broken by the schema change.
  static List<IngredientGroup> _decodeIngredientGroups(String json) {
    final dynamic decoded = jsonDecode(json);
    if (decoded is! List || decoded.isEmpty) {
      return [IngredientGroup.unnamed([])];
    }

    // Detect format from the first element.
    if (decoded.first is String) {
      // Legacy format — flat list of strings.
      return [IngredientGroup.unnamed(List<String>.from(decoded))];
    }

    // New format — list of group objects.
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(IngredientGroup.fromJson)
        .toList();
  }

  /// Converts this recipe to a column-value map for SQLite insert / update.
  ///
  /// The [id] field is omitted when 0 so SQLite can auto-assign it on INSERT.
  /// [ingredientGroups] is encoded as a JSON array of group objects in the
  /// existing `ingredients` column — no schema migration needed.
  Map<String, dynamic> toSqlite() {
    return {
      if (id != 0) 'id': id,
      'title': title,
      'description': description,
      'ingredients': jsonEncode(ingredientGroups.map((g) => g.toJson()).toList()),
      'steps': jsonEncode(steps),
      'prepTime': prepTimeMinutes,
      'servings': servings,
      'tags': jsonEncode(tags),
      'imagePath': imagePath,
      'sourceUrl': sourceUrl,
      'notes': notes,
      'isFavourite': isFavourite ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // ---------------------------------------------------------------------------
  // JSON serialisation (used for export / import)
  // ---------------------------------------------------------------------------

  /// Creates a [Recipe] from a JSON map (export file format).
  ///
  /// Handles both the legacy `ingredients` flat-array format and the new
  /// `ingredientGroups` format for cross-version import compatibility.
  /// The [id] is intentionally ignored on import to avoid ID collisions.
  factory Recipe.fromJson(Map<String, dynamic> json) {
    List<IngredientGroup> groups;

    if (json.containsKey('ingredientGroups')) {
      // New export format.
      groups = (json['ingredientGroups'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(IngredientGroup.fromJson)
          .toList();
    } else {
      // Legacy export format — flat string array.
      groups = [
        IngredientGroup.unnamed(
            List<String>.from(json['ingredients'] as List? ?? []))
      ];
    }

    return Recipe(
      // id is not read from JSON; always starts at 0 (unsaved).
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      ingredientGroups: groups.isEmpty
          ? [IngredientGroup.unnamed([])]
          : groups,
      steps: List<String>.from(json['steps'] as List? ?? []),
      prepTimeMinutes: json['prepTimeMinutes'] as int? ?? 0,
      servings: json['servings'] as int? ?? 0,
      tags: List<String>.from(json['tags'] as List? ?? []),
      imagePath: '', // Image paths are device-specific; don't import them.
      sourceUrl: json['sourceUrl'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      isFavourite: json['isFavourite'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  /// Converts this recipe to a JSON-serialisable map for export.
  ///
  /// Uses the new `ingredientGroups` key so the format is forward-compatible.
  /// [imagePath] is excluded because file paths are device-specific.
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'ingredientGroups':
          ingredientGroups.map((g) => g.toJson()).toList(),
      'steps': steps,
      'prepTimeMinutes': prepTimeMinutes,
      'servings': servings,
      'tags': tags,
      'sourceUrl': sourceUrl,
      'notes': notes,
      'isFavourite': isFavourite,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  /// Returns a copy of this recipe with the specified fields replaced.
  ///
  /// Useful in edit screens where only one or two fields change at a time.
  Recipe copyWith({
    int? id,
    String? title,
    String? description,
    List<IngredientGroup>? ingredientGroups,
    List<String>? steps,
    int? prepTimeMinutes,
    int? servings,
    List<String>? tags,
    String? imagePath,
    String? sourceUrl,
    String? notes,
    bool? isFavourite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Recipe(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      ingredientGroups: ingredientGroups ?? this.ingredientGroups,
      steps: steps ?? this.steps,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
      servings: servings ?? this.servings,
      tags: tags ?? this.tags,
      imagePath: imagePath ?? this.imagePath,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      notes: notes ?? this.notes,
      isFavourite: isFavourite ?? this.isFavourite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
