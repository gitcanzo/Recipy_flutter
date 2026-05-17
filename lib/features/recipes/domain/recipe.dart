import 'dart:convert';

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

  /// Ordered list of ingredient strings (e.g. ["200g pasta", "2 eggs"]).
  final List<String> ingredients;

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

  /// Timestamp of when the recipe was first saved to the database.
  final DateTime createdAt;

  /// Timestamp of the most recent edit.
  final DateTime updatedAt;

  const Recipe({
    this.id = 0,
    required this.title,
    this.description = '',
    required this.ingredients,
    required this.steps,
    this.prepTimeMinutes = 0,
    this.servings = 0,
    this.tags = const [],
    this.imagePath = '',
    this.sourceUrl = '',
    required this.createdAt,
    required this.updatedAt,
  });

  // ---------------------------------------------------------------------------
  // SQLite serialisation
  // ---------------------------------------------------------------------------

  /// Creates a [Recipe] from a SQLite column-value map returned by sqflite.
  ///
  /// [id] comes from the INTEGER PRIMARY KEY column.
  /// List fields (ingredients, steps, tags) are stored as JSON strings and
  /// decoded back to typed lists here.
  factory Recipe.fromSqlite(Map<String, dynamic> row) {
    return Recipe(
      id: row['id'] as int,
      title: row['title'] as String,
      description: row['description'] as String? ?? '',
      ingredients: List<String>.from(
          jsonDecode(row['ingredients'] as String? ?? '[]') as List),
      steps: List<String>.from(
          jsonDecode(row['steps'] as String? ?? '[]') as List),
      prepTimeMinutes: row['prepTime'] as int? ?? 0,
      servings: row['servings'] as int? ?? 0,
      tags: List<String>.from(
          jsonDecode(row['tags'] as String? ?? '[]') as List),
      imagePath: row['imagePath'] as String? ?? '',
      sourceUrl: row['sourceUrl'] as String? ?? '',
      createdAt: DateTime.parse(row['createdAt'] as String),
      updatedAt: DateTime.parse(row['updatedAt'] as String),
    );
  }

  /// Converts this recipe to a column-value map for SQLite insert / update.
  ///
  /// The [id] field is omitted when 0 so SQLite can auto-assign it on INSERT.
  /// List fields are encoded as JSON strings for storage in TEXT columns.
  Map<String, dynamic> toSqlite() {
    return {
      if (id != 0) 'id': id,
      'title': title,
      'description': description,
      'ingredients': jsonEncode(ingredients),
      'steps': jsonEncode(steps),
      'prepTime': prepTimeMinutes,
      'servings': servings,
      'tags': jsonEncode(tags),
      'imagePath': imagePath,
      'sourceUrl': sourceUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // ---------------------------------------------------------------------------
  // JSON serialisation (used for export / import)
  // ---------------------------------------------------------------------------

  /// Creates a [Recipe] from a JSON map (export file format).
  ///
  /// The [id] is intentionally ignored on import so that importing into a
  /// device with existing recipes never causes ID collisions — SQLite will
  /// assign a fresh auto-incremented ID.
  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      // id is not read from JSON; always starts at 0 (unsaved).
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      ingredients: List<String>.from(json['ingredients'] as List? ?? []),
      steps: List<String>.from(json['steps'] as List? ?? []),
      prepTimeMinutes: json['prepTimeMinutes'] as int? ?? 0,
      servings: json['servings'] as int? ?? 0,
      tags: List<String>.from(json['tags'] as List? ?? []),
      imagePath: '', // Image paths are device-specific; don't import them.
      sourceUrl: json['sourceUrl'] as String? ?? '',
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
  /// [imagePath] is excluded because file paths are device-specific and would
  /// be meaningless on the recipient's device.
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'ingredients': ingredients,
      'steps': steps,
      'prepTimeMinutes': prepTimeMinutes,
      'servings': servings,
      'tags': tags,
      'sourceUrl': sourceUrl,
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
    List<String>? ingredients,
    List<String>? steps,
    int? prepTimeMinutes,
    int? servings,
    List<String>? tags,
    String? imagePath,
    String? sourceUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Recipe(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
      servings: servings ?? this.servings,
      tags: tags ?? this.tags,
      imagePath: imagePath ?? this.imagePath,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
