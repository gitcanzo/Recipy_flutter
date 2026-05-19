/// A named group of ingredients within a recipe.
///
/// Recipes with a single unnamed group behave identically to the old
/// flat [ingredients] list, preserving backward compatibility.
///
/// Example: a lasagne recipe might have two groups:
///   - "Béchamel sauce" → ["50g butter", "500ml milk", …]
///   - "Assembly"       → ["9 lasagne sheets", "200g mozzarella", …]
class IngredientGroup {
  /// Optional display name shown above the ingredient list.
  ///
  /// An empty string means no header is rendered — used for the default
  /// single-group case where the user has not added any named groups.
  final String name;

  /// Ordered list of ingredient strings belonging to this group.
  final List<String> items;

  const IngredientGroup({
    required this.name,
    required this.items,
  });

  /// Creates a default, unnamed group from a flat ingredient list.
  ///
  /// Used when migrating older recipes that have no group structure.
  factory IngredientGroup.unnamed(List<String> items) =>
      IngredientGroup(name: '', items: List<String>.from(items));

  /// Deserialises from a JSON map stored in the SQLite `ingredients` column.
  ///
  /// Expected format:
  /// ```json
  /// { "name": "Béchamel", "items": ["50g butter", "500ml milk"] }
  /// ```
  factory IngredientGroup.fromJson(Map<String, dynamic> json) {
    return IngredientGroup(
      name: json['name'] as String? ?? '',
      items: List<String>.from(json['items'] as List? ?? []),
    );
  }

  /// Serialises to a JSON map for storage in the SQLite `ingredients` column.
  Map<String, dynamic> toJson() => {
        'name': name,
        'items': items,
      };

  /// Returns a copy with the specified fields replaced.
  IngredientGroup copyWith({String? name, List<String>? items}) {
    return IngredientGroup(
      name: name ?? this.name,
      items: items ?? this.items,
    );
  }
}
