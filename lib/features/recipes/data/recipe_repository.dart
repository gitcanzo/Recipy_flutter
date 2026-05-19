import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../domain/recipe.dart';

// ---------------------------------------------------------------------------
// Riverpod providers
// ---------------------------------------------------------------------------

/// Provides the single shared [RecipeRepository] instance for the app's
/// lifetime.  Not auto-disposed so the SQLite connection stays open.
final recipeRepositoryProvider = Provider<RecipeRepository>(
  (ref) => RecipeRepository(),
);

/// Holds recipes parsed from an incoming file intent that are waiting for the
/// user to confirm before being imported.  Set by main.dart, consumed and
/// cleared by RecipeListScreen.
final pendingImportProvider =
    StateProvider<List<Recipe>>((ref) => const []);

/// Exposes the recipe list as a reactive [AsyncValue].
///
/// Backed by [RecipeListNotifier] so any write (add / update / delete /
/// import) pushes an updated list to all watching widgets automatically.
/// SQLite does not emit change streams natively, so we manually refresh
/// after every mutation.
final recipeListProvider =
    StateNotifierProvider<RecipeListNotifier, AsyncValue<List<Recipe>>>((ref) {
  return RecipeListNotifier(ref.watch(recipeRepositoryProvider));
});

// ---------------------------------------------------------------------------
// State notifier
// ---------------------------------------------------------------------------

/// Owns the in-memory recipe list and propagates mutations to the UI.
///
/// Every public method writes to SQLite first via [RecipeRepository], then
/// calls [_refresh] to re-query and emit the updated list.
class RecipeListNotifier extends StateNotifier<AsyncValue<List<Recipe>>> {
  final RecipeRepository _repo;

  RecipeListNotifier(this._repo) : super(const AsyncValue.loading()) {
    // Populate the list as soon as the notifier is created.
    _refresh();
  }

  /// Queries SQLite and emits the result.
  Future<void> _refresh() async {
    state = const AsyncValue.loading();
    try {
      final recipes = await _repo.getAllRecipes();
      state = AsyncValue.data(recipes);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Inserts a new recipe and refreshes the list.  Returns the new row ID.
  Future<int> addRecipe(Recipe recipe) async {
    final id = await _repo.insertRecipe(recipe);
    await _refresh();
    return id;
  }

  /// Updates an existing recipe and refreshes the list.
  Future<void> updateRecipe(Recipe recipe) async {
    await _repo.updateRecipe(recipe);
    await _refresh();
  }

  /// Deletes a recipe by its integer primary key and refreshes the list.
  Future<void> deleteRecipe(int id) async {
    await _repo.deleteRecipe(id);
    await _refresh();
  }

  /// Bulk-inserts recipes imported from a JSON file and refreshes the list.
  ///
  /// Each recipe is treated as a brand-new entry — existing IDs in the import
  /// data are ignored and SQLite assigns fresh auto-incremented IDs to avoid
  /// collisions with existing recipes.
  Future<void> importRecipes(List<Recipe> recipes) async {
    await _repo.insertMany(recipes);
    await _refresh();
  }

  /// Toggles the favourite flag on a recipe and refreshes the list.
  Future<void> toggleFavourite(int id, bool newValue) async {
    await _repo.setFavourite(id, newValue);
    await _refresh();
  }

  /// Re-queries the database and emits the latest list.  Call this when the
  /// app returns to the foreground or after an out-of-band database write.
  Future<void> refresh() => _refresh();
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

/// Handles all SQLite CRUD operations for recipes.
///
/// The database file is created once inside the app's documents directory and
/// opened lazily on first access.  All public methods are async.
class RecipeRepository {
  /// Cached open database.  Null until the first call to [_db].
  Database? _database;

  /// Returns the open database, initialising it on first access.
  Future<Database> get _db async {
    _database ??= await _openDb();
    return _database!;
  }

  /// Opens (or creates) the SQLite database file.
  ///
  /// List-typed fields (ingredients, steps, tags) are stored as JSON strings
  /// in TEXT columns.  This keeps the schema simple without needing junction
  /// tables, which would add complexity without meaningful benefit here.
  Future<Database> _openDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'recipy.db');

    return openDatabase(
      dbPath,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE recipes (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            title       TEXT    NOT NULL,
            description TEXT    NOT NULL DEFAULT '',
            ingredients TEXT    NOT NULL DEFAULT '[]',
            steps       TEXT    NOT NULL DEFAULT '[]',
            prepTime    INTEGER NOT NULL DEFAULT 0,
            servings    INTEGER NOT NULL DEFAULT 0,
            tags        TEXT    NOT NULL DEFAULT '[]',
            imagePath   TEXT    NOT NULL DEFAULT '',
            sourceUrl   TEXT    NOT NULL DEFAULT '',
            notes       TEXT    NOT NULL DEFAULT '',
            isFavourite INTEGER NOT NULL DEFAULT 0,
            createdAt   TEXT    NOT NULL,
            updatedAt   TEXT    NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              "ALTER TABLE recipes ADD COLUMN notes TEXT NOT NULL DEFAULT ''");
        }
        if (oldVersion < 3) {
          await db.execute(
              "ALTER TABLE recipes ADD COLUMN isFavourite INTEGER NOT NULL DEFAULT 0");
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // CRUD
  // ---------------------------------------------------------------------------

  /// Returns all recipes ordered by most recently updated first.
  Future<List<Recipe>> getAllRecipes() async {
    final db = await _db;
    final rows = await db.rawQuery('SELECT * FROM recipes ORDER BY LOWER(title) ASC');
    return rows.map(Recipe.fromSqlite).toList();
  }

  /// Fetches a single recipe by its integer primary key.
  ///
  /// Returns `null` if no row with [id] exists.
  Future<Recipe?> getRecipe(int id) async {
    final db = await _db;
    final rows =
        await db.query('recipes', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Recipe.fromSqlite(rows.first);
  }

  /// Inserts [recipe] into the database and returns the auto-generated row ID.
  ///
  /// The [createdAt] and [updatedAt] timestamps are always set to now on
  /// insert, overriding whatever the recipe object carries.
  Future<int> insertRecipe(Recipe recipe) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    final map = recipe.toSqlite();
    map
      ..remove('id') // Let SQLite assign the ID.
      ..['createdAt'] = now
      ..['updatedAt'] = now;
    return db.insert('recipes', map);
  }

  /// Bulk-inserts a list of recipes inside a single transaction for efficiency.
  ///
  /// Every row gets a fresh timestamp and a new auto-incremented ID.
  Future<void> insertMany(List<Recipe> recipes) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      for (final recipe in recipes) {
        final map = recipe.toSqlite();
        map
          ..remove('id')
          ..['createdAt'] = now
          ..['updatedAt'] = now;
        await txn.insert('recipes', map);
      }
    });
  }

  /// Overwrites the row identified by [recipe.id] with the new field values.
  ///
  /// Only [updatedAt] is refreshed; [createdAt] is preserved from the
  /// original row.
  Future<void> updateRecipe(Recipe recipe) async {
    final db = await _db;
    final map = recipe.toSqlite();
    map['updatedAt'] = DateTime.now().toIso8601String();
    await db.update('recipes', map, where: 'id = ?', whereArgs: [recipe.id]);
  }

  /// Updates only the isFavourite flag for the recipe with [id].
  Future<void> setFavourite(int id, bool value) async {
    final db = await _db;
    await db.update(
      'recipes',
      {'isFavourite': value ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Permanently deletes the recipe row with the given [id].
  ///
  /// Does NOT delete the associated image file from disk — image cleanup
  /// must be handled by the caller when needed.
  Future<void> deleteRecipe(int id) async {
    final db = await _db;
    await db.delete('recipes', where: 'id = ?', whereArgs: [id]);
  }
}
