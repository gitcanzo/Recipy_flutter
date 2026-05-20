import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../../shared/utils/image_utils.dart';
import '../../data/recipe_repository.dart';
import '../../domain/ingredient_group.dart';
import '../../domain/recipe.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/recipy_colors.dart';
import '../../../../l10n/app_localizations.dart';

/// Screen for creating a new recipe ([recipeId] == null) or editing an
/// existing one ([recipeId] is the SQLite integer primary key).
///
/// On save the recipe is written to the local SQLite database via
/// [RecipeListNotifier].  If a new cover photo was picked it is first copied
/// into the app's documents directory so the path remains stable even if the
/// user moves the original file from the gallery.
class RecipeEditScreen extends ConsumerStatefulWidget {
  /// SQLite primary key of the recipe to edit, or null when creating new.
  final int? recipeId;

  /// Optional pre-populated recipe data used when the screen is opened from
  /// the URL import flow.  When set, fields are seeded from this recipe
  /// instead of being blank — but no [recipeId] exists yet, so saving will
  /// always insert a new row rather than updating an existing one.
  final Recipe? initialRecipe;

  const RecipeEditScreen({super.key, required this.recipeId, this.initialRecipe});

  @override
  ConsumerState<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

// ---------------------------------------------------------------------------
// Internal data structures for the mutable editor state
// ---------------------------------------------------------------------------

/// Holds the mutable editor state for a single ingredient group.
///
/// Each group owns a [TextEditingController] for its name field and a list
/// of [_ItemEntry] for its ingredient rows.  Controllers are managed here
/// (not inside child widgets) so that reordering the list never causes
/// controllers to be disposed and recreated — which would reset text values.
class _GroupEntry {
  /// Controller for the group's name text field.
  final TextEditingController nameController;

  /// Ordered list of ingredient item entries.
  List<_ItemEntry> items;

  _GroupEntry({required String name, required List<String> itemValues})
      : nameController = TextEditingController(text: name),
        items = itemValues.map((v) => _ItemEntry(value: v)).toList();

  /// Returns the current group name from the controller.
  String get name => nameController.text;

  /// Disposes all owned controllers.
  void dispose() {
    nameController.dispose();
    for (final item in items) {
      item.dispose();
    }
  }
}

/// Holds the mutable editor state for a single ingredient item row.
///
/// Owns a [TextEditingController] and an optional [FocusNode].
/// The [FocusNode] is set when a new item is added so the cursor jumps
/// to the new field automatically.
class _ItemEntry {
  final TextEditingController controller;
  final FocusNode focusNode;

  /// When true, [focusNode.requestFocus()] will be called on the next build.
  bool requestFocusOnBuild;

  _ItemEntry({required String value, bool autoFocus = false})
      : controller = TextEditingController(text: value),
        focusNode = FocusNode(),
        requestFocusOnBuild = autoFocus;

  /// Returns the current text value.
  String get value => controller.text;

  /// Disposes all owned resources.
  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

// ---------------------------------------------------------------------------
// Main state class
// ---------------------------------------------------------------------------

class _RecipeEditScreenState extends ConsumerState<RecipeEditScreen> {
  /// True when [recipeId] is null — the screen is creating a brand-new recipe.
  bool get _isNew => widget.recipeId == null;

  final _formKey = GlobalKey<FormState>();

  // One controller per simple text field.
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _prepTimeController = TextEditingController();
  final _servingsController = TextEditingController();
  final _notesController = TextEditingController();

  /// Confirmed tags shown as chips.
  List<String> _tags = [];

  /// Controller for the tag text input — cleared each time a tag is committed.
  final _tagInputController = TextEditingController();
  final _tagFocusNode = FocusNode();

  /// Mutable list of group entries.  Each entry owns its controllers.
  late List<_GroupEntry> _groupEntries;

  /// Mutable list of step controllers.
  late List<TextEditingController> _stepControllers;

  /// Focus nodes for step fields — index-aligned with [_stepControllers].
  late List<FocusNode> _stepFocusNodes;

  /// Tracks which step index should receive focus on the next build.
  int? _stepAutoFocusIndex;

  /// A newly picked image file that has not yet been copied to app storage.
  File? _pickedImage;

  /// The absolute path to the image already stored in the app's documents
  /// directory (from a previous save).
  String _existingImagePath = '';

  // Fields preserved from the original recipe that are not editable in the UI.
  bool _isFavourite = false;
  String _sourceUrl = '';
  DateTime? _originalCreatedAt;

  /// True while the save operation is in progress (disables the save button).
  bool _isSaving = false;

  /// True while the existing recipe is being loaded from SQLite in edit mode.
  bool _isLoading = false;

  /// True once the user has made any change that hasn't been saved yet.
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    // Initialise with one empty group and one empty step.
    _groupEntries = [_GroupEntry(name: '', itemValues: [''])];
    _stepControllers = [TextEditingController()];
    _stepFocusNodes = [FocusNode()];
    _attachDirtyListeners(entries: _groupEntries, steps: _stepControllers);

    // Any text change in the simple fields marks the form dirty and triggers
    // a rebuild so PopScope.canPop reflects the current state immediately.
    for (final c in [
      _titleController,
      _descriptionController,
      _prepTimeController,
      _servingsController,
      _notesController,
    ]) {
      c.addListener(_onTextChanged);
    }

    // Rebuild when tag focus changes so InputDecorator shows the correct
    // focused/unfocused border, and commit any pending text on focus loss.
    _tagFocusNode.addListener(() {
      if (!_tagFocusNode.hasFocus) {
        _commitTag(_tagInputController.text);
      }
      if (mounted) setState(() {});
    });

    if (!_isNew) {
      // Edit mode — load from SQLite.
      _loadRecipe();
    } else if (widget.initialRecipe != null) {
      // Import mode — seed fields from the pre-parsed recipe.
      _seedFromRecipe(widget.initialRecipe!);
    }
  }

  void _onTextChanged() {
    if (!_isDirty && mounted) setState(() => _isDirty = true);
  }

  /// Attaches [_onTextChanged] to all controllers in [entries] and [steps].
  void _attachDirtyListeners({
    required List<_GroupEntry> entries,
    required List<TextEditingController> steps,
  }) {
    for (final g in entries) {
      g.nameController.addListener(_onTextChanged);
      for (final item in g.items) {
        item.controller.addListener(_onTextChanged);
      }
    }
    for (final c in steps) {
      c.addListener(_onTextChanged);
    }
  }

  /// Seeds all form fields from [recipe] without hitting SQLite.
  ///
  /// Used when the screen is opened from the URL import flow, where the recipe
  /// has already been parsed but not yet saved.
  void _seedFromRecipe(Recipe recipe) {
    _titleController.text = recipe.title;
    _descriptionController.text = recipe.description;
    _prepTimeController.text =
        recipe.prepTimeMinutes > 0 ? '${recipe.prepTimeMinutes}' : '';
    _servingsController.text =
        recipe.servings > 0 ? '${recipe.servings}' : '';
    _tags = List<String>.from(recipe.tags);
    _notesController.text = recipe.notes;

    _groupEntries = recipe.ingredientGroups.isNotEmpty
        ? recipe.ingredientGroups
            .map((g) => _GroupEntry(
                  name: g.name,
                  itemValues: g.items.isNotEmpty ? g.items : [''],
                ))
            .toList()
        : [_GroupEntry(name: '', itemValues: [''])];

    final steps = recipe.steps.isNotEmpty ? recipe.steps : [''];
    _stepControllers =
        steps.map((s) => TextEditingController(text: s)).toList();
    _stepFocusNodes = steps.map((_) => FocusNode()).toList();

    _attachDirtyListeners(entries: _groupEntries, steps: _stepControllers);

    // Carry over any image that was downloaded during import.
    _existingImagePath = recipe.imagePath;
    // sourceUrl is preserved so the link remains visible after the user saves.
    // isFavourite is intentionally NOT carried over — an imported recipe should
    // never start as a favourite; that is a personal preference of the importer.
    _sourceUrl = recipe.sourceUrl;
    _originalCreatedAt = recipe.createdAt;
  }

  /// Fetches the existing recipe from SQLite and pre-fills all form fields.
  Future<void> _loadRecipe() async {
    setState(() => _isLoading = true);
    try {
      final recipe =
          await ref.read(recipeRepositoryProvider).getRecipe(widget.recipeId!);
      if (recipe != null && mounted) {
        _titleController.text = recipe.title;
        _descriptionController.text = recipe.description;
        _prepTimeController.text =
            recipe.prepTimeMinutes > 0 ? '${recipe.prepTimeMinutes}' : '';
        _servingsController.text =
            recipe.servings > 0 ? '${recipe.servings}' : '';
        _tags = List<String>.from(recipe.tags);
        _notesController.text = recipe.notes;

        // Dispose old entries before replacing.
        for (final g in _groupEntries) {
          g.dispose();
        }
        _groupEntries = recipe.ingredientGroups.isNotEmpty
            ? recipe.ingredientGroups
                .map((g) => _GroupEntry(
                      name: g.name,
                      itemValues: g.items.isNotEmpty ? g.items : [''],
                    ))
                .toList()
            : [_GroupEntry(name: '', itemValues: [''])];

        for (final c in _stepControllers) {
          c.dispose();
        }
        for (final f in _stepFocusNodes) {
          f.dispose();
        }
        final steps =
            recipe.steps.isNotEmpty ? recipe.steps : [''];
        _stepControllers =
            steps.map((s) => TextEditingController(text: s)).toList();
        _stepFocusNodes = steps.map((_) => FocusNode()).toList();

        _existingImagePath = recipe.imagePath;
        _isFavourite = recipe.isFavourite;
        _sourceUrl = recipe.sourceUrl;
        _originalCreatedAt = recipe.createdAt;
        _attachDirtyListeners(entries: _groupEntries, steps: _stepControllers);
        // Reset dirty flag — loading existing data is not a user change.
        _isDirty = false;
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _titleController,
      _descriptionController,
      _prepTimeController,
      _servingsController,
      _notesController,
    ]) {
      c.removeListener(_onTextChanged);
    }
    _titleController.dispose();
    _descriptionController.dispose();
    _prepTimeController.dispose();
    _servingsController.dispose();
    _tagInputController.dispose();
    _tagFocusNode.dispose();
    _notesController.dispose();
    for (final g in _groupEntries) {
      g.dispose();
    }
    for (final c in _stepControllers) {
      c.dispose();
    }
    for (final f in _stepFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Image helpers
  // ---------------------------------------------------------------------------

  /// Opens the device gallery so the user can pick a cover photo.
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null && mounted) {
      setState(() {
        _isDirty = true;
        _pickedImage = File(picked.path);
      });
    }
  }

  /// Copies [_pickedImage] into the app's documents directory and returns
  /// the stable absolute path.
  ///
  /// Storing the copy ensures the image remains available even if the user
  /// clears their gallery or moves the original file.
  Future<String> _copyImageToAppDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(dir.path, 'recipe_images'));
    if (!imagesDir.existsSync()) imagesDir.createSync(recursive: true);
    final destPath = p.join(imagesDir.path, '${DateTime.now().millisecondsSinceEpoch}.jpg');
    final compressed = await compressImage(_pickedImage!, destPath);
    return compressed.path;
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  /// Validates the form, optionally copies the image, then writes to SQLite.
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Duplicate-name check: compare case-insensitively against all existing
    // recipes, excluding the recipe currently being edited (by its own ID).
    final existingRecipes =
        ref.read(recipeListProvider).valueOrNull ?? const [];
    final newTitle = _titleController.text.trim().toLowerCase();
    final isDuplicate = existingRecipes.any((r) =>
        r.title.trim().toLowerCase() == newTitle &&
        r.id != (widget.recipeId ?? 0));
    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!.duplicateRecipeName)),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String imagePath = _existingImagePath;
      if (_pickedImage != null) {
        imagePath = await _copyImageToAppDir();
      }

      // Commit any text still in the tag input field (user may not have typed
      // a comma before saving).
      final pendingTag = _tagInputController.text.trim();
      final tags = [
        ..._tags,
        if (pendingTag.isNotEmpty) pendingTag,
      ];

      // Read current values from all controllers, drop blank rows/groups.
      final groups = _groupEntries
          .map((g) => IngredientGroup(
                name: g.name.trim(),
                items: g.items
                    .map((i) => i.value.trim())
                    .where((v) => v.isNotEmpty)
                    .toList(),
              ))
          .where((g) => g.items.isNotEmpty)
          .toList();

      final finalGroups = groups.isEmpty
          ? [IngredientGroup(name: '', items: [])]
          : groups;

      final steps = _stepControllers
          .map((c) => c.text.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final now = DateTime.now();
      final recipe = Recipe(
        id: widget.recipeId ?? 0,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        ingredientGroups: finalGroups,
        steps: steps,
        prepTimeMinutes: int.tryParse(_prepTimeController.text) ?? 0,
        servings: int.tryParse(_servingsController.text) ?? 0,
        tags: tags,
        imagePath: imagePath,
        // Preserve fields that are not editable in the form.
        // For new recipes these default to false / '' / now.
        sourceUrl: _sourceUrl,
        isFavourite: _isFavourite,
        notes: _notesController.text.trim(),
        // Preserve the original creation timestamp on edits; use now for new.
        createdAt: _originalCreatedAt ?? now,
        updatedAt: now,
      );

      final notifier = ref.read(recipeListProvider.notifier);
      if (_isNew) {
        final newId = await notifier.addRecipe(recipe);
        if (mounted) context.go('${AppRoutes.recipes}/$newId');
      } else {
        await notifier.updateRecipe(recipe);
        if (mounted) context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.saveFailed(e.toString()))));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Group mutations
  // ---------------------------------------------------------------------------

  /// Appends a new unnamed group with one blank item.
  void _addGroup() {
    setState(() {
      _isDirty = true;
      _groupEntries.add(_GroupEntry(name: '', itemValues: ['']));
    });
  }

  /// Removes the group at [index].  Disabled when only one group remains.
  void _removeGroup(int index) {
    if (_groupEntries.length <= 1) return;
    setState(() {
      _isDirty = true;
      _groupEntries.removeAt(index).dispose();
    });
  }

  /// Handles drag-reorder at the group level.
  void _onGroupReorder(int oldIndex, int newIndex) {
    setState(() {
      _isDirty = true;
      if (newIndex > oldIndex) newIndex--;
      _groupEntries.insert(newIndex, _groupEntries.removeAt(oldIndex));
    });
  }

  // ---------------------------------------------------------------------------
  // Item mutations
  // ---------------------------------------------------------------------------

  /// Appends a blank item to the group at [groupIndex] and requests focus.
  void _addItem(int groupIndex) {
    setState(() {
      _isDirty = true;
      final entry = _ItemEntry(value: '', autoFocus: true);
      entry.controller.addListener(_onTextChanged);
      _groupEntries[groupIndex].items.add(entry);
    });
  }

  /// Removes the item at [itemIndex] from the group at [groupIndex].
  void _removeItem(int groupIndex, int itemIndex) {
    setState(() {
      _isDirty = true;
      _groupEntries[groupIndex].items.removeAt(itemIndex).dispose();
    });
  }

  /// Handles drag-reorder of items within a group.
  void _onItemReorder(int groupIndex, int oldIndex, int newIndex) {
    setState(() {
      _isDirty = true;
      if (newIndex > oldIndex) newIndex--;
      final items = _groupEntries[groupIndex].items;
      items.insert(newIndex, items.removeAt(oldIndex));
    });
  }

  // ---------------------------------------------------------------------------
  // Step mutations
  // ---------------------------------------------------------------------------

  /// Appends a blank step and auto-focuses the new field.
  void _addStep() {
    setState(() {
      _isDirty = true;
      final c = TextEditingController()..addListener(_onTextChanged);
      _stepControllers.add(c);
      _stepFocusNodes.add(FocusNode());
      _stepAutoFocusIndex = _stepControllers.length - 1;
    });
  }

  /// Removes the step at [index].
  void _removeStep(int index) {
    setState(() {
      _isDirty = true;
      _stepControllers.removeAt(index).dispose();
      _stepFocusNodes.removeAt(index).dispose();
      if (_stepAutoFocusIndex != null && _stepAutoFocusIndex! >= index) {
        _stepAutoFocusIndex = null;
      }
    });
  }

  /// Handles drag-reorder of steps.
  void _onStepReorder(int oldIndex, int newIndex) {
    setState(() {
      _isDirty = true;
      if (newIndex > oldIndex) newIndex--;
      _stepControllers.insert(newIndex, _stepControllers.removeAt(oldIndex));
      _stepFocusNodes.insert(newIndex, _stepFocusNodes.removeAt(oldIndex));
    });
  }

  // ---------------------------------------------------------------------------
  // Discard-changes guard
  // ---------------------------------------------------------------------------

  bool get _hasUnsavedChanges => _isDirty;

  /// Shows the discard-changes dialog and pops if the user confirms.
  Future<void> _confirmDiscard() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.discardChangesTitle),
        content: Text(l10n.discardChangesContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.discard),
          ),
        ],
      ),
    );
    if ((confirmed ?? false) && mounted) context.pop();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? AppLocalizations.of(context)!.newRecipeTitle : AppLocalizations.of(context)!.editRecipeTitle),
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.check),
                  tooltip: AppLocalizations.of(context)!.tooltipSave,
                  onPressed: _save,
                ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildImagePicker(),
                  const SizedBox(height: 16),

                  // Title (required)
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.fieldTitle,
                      border: const OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.fieldDescription,
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 12),

                  // Prep time + servings side by side
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _prepTimeController,
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.fieldPrepTime,
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _servingsController,
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.fieldServings,
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Tags — chip input: typing a comma commits the current
                  // text as a chip; existing chips can be deleted with ×.
                  _buildTagsInput(),
                  const SizedBox(height: 24),

                  // ── Ingredients ──────────────────────────────────────────
                  Text(AppLocalizations.of(context)!.sectionIngredientsEdit,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(context)!.ingredientsReorderHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  _buildGroupsEditor(),
                  const SizedBox(height: 24),

                  // ── Steps ────────────────────────────────────────────────
                  Text(AppLocalizations.of(context)!.sectionStepsEdit,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _buildStepsEditor(),
                  const SizedBox(height: 24),

                  // ── Notes ────────────────────────────────────────────────
                  Text(AppLocalizations.of(context)!.sectionNotesEdit,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.notesHint,
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: null,
                    minLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 32),

                  // Bottom save button
                  FilledButton(
                    onPressed: _isSaving ? null : _save,
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                    child: Text(_isNew ? AppLocalizations.of(context)!.buttonCreateRecipe : AppLocalizations.of(context)!.buttonSaveChanges),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tags chip-input
  // ---------------------------------------------------------------------------

  /// Trims [text], and adds it as a chip if non-empty and not a duplicate.
  void _commitTag(String text) {
    final value = text.trim();
    if (value.isEmpty) return;
    if (_tags.any((t) => t.toLowerCase() == value.toLowerCase())) {
      _tagInputController.clear();
      return;
    }
    setState(() {
      _isDirty = true;
      _tags.add(value);
    });
    _tagInputController.clear();
    // Keep focus in the input so the user can type the next tag immediately.
    _tagFocusNode.requestFocus();
  }

  /// Builds the tags field: existing tags as deletable chips followed by a
  /// text input that commits a chip when the user types a comma or presses
  /// the Enter/Done keyboard action.
  ///
  /// The outer [GestureDetector] ensures tapping anywhere inside the decorated
  /// box (including on the chips area) re-focuses the text input, so the user
  /// can always tap back in to add more tags after interacting elsewhere.
  Widget _buildTagsInput() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _tagFocusNode.requestFocus,
      child: InputDecorator(
        isFocused: _tagFocusNode.hasFocus,
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context)!.fieldTags,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // One chip per committed tag.
            for (final tag in _tags)
              Chip(
                label: Text(tag),
                onDeleted: () => setState(() { _isDirty = true; _tags.remove(tag); }),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            // Inline text input — sizing tricks so it flows inside the Wrap.
            IntrinsicWidth(
              child: TextField(
                controller: _tagInputController,
                focusNode: _tagFocusNode,
                decoration: InputDecoration(
                  hintText: _tags.isEmpty ? AppLocalizations.of(context)!.tagsHint : null,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                ),
                textInputAction: TextInputAction.done,
                onChanged: (value) {
                  // Commit whenever a comma is typed; strip the comma itself.
                  if (value.contains(',')) {
                    final parts = value.split(',');
                    // Everything before the last comma is a complete tag.
                    for (final part in parts.sublist(0, parts.length - 1)) {
                      _commitTag(part);
                    }
                    // Leave whatever came after the last comma in the field.
                    _tagInputController.value = TextEditingValue(
                      text: parts.last,
                      selection: TextSelection.collapsed(
                          offset: parts.last.length),
                    );
                  }
                },
                // Commit on Enter / Done keyboard action.
                onSubmitted: _commitTag,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Ingredients editor
  // ---------------------------------------------------------------------------

  /// Builds the groups editor: a reorderable list of [_GroupCard]s followed
  /// by an "+ Add group" button.
  Widget _buildGroupsEditor() {
    return Column(
      children: [
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorder: _onGroupReorder,
          children: [
            for (int gi = 0; gi < _groupEntries.length; gi++)
              _GroupCard(
                // Stable key based on object identity — survives reorders
                // without disposing controllers.
                key: ObjectKey(_groupEntries[gi]),
                entry: _groupEntries[gi],
                groupIndex: gi,
                totalGroups: _groupEntries.length,
                onAddItem: () => _addItem(gi),
                onRemoveItem: (ii) => _removeItem(gi, ii),
                onItemReorder: (oi, ni) => _onItemReorder(gi, oi, ni),
                onRemoveGroup:
                    _groupEntries.length > 1 ? () => _removeGroup(gi) : null,
              ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addGroup,
            icon: const Icon(Icons.add),
            label: Text(AppLocalizations.of(context)!.buttonAddGroup),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Steps editor
  // ---------------------------------------------------------------------------

  /// Builds the reorderable steps list.
  Widget _buildStepsEditor() {
    // Consume and clear the auto-focus index after building.
    final autoFocusIndex = _stepAutoFocusIndex;

    return Column(
      children: [
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorder: _onStepReorder,
          children: [
            for (int i = 0; i < _stepControllers.length; i++)
              _StepRow(
                key: ObjectKey(_stepControllers[i]),
                index: i,
                controller: _stepControllers[i],
                focusNode: _stepFocusNodes[i],
                autoFocus: autoFocusIndex == i,
                totalSteps: _stepControllers.length,
                onRemove: _stepControllers.length > 1
                    ? () => _removeStep(i)
                    : null,
              ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addStep,
            icon: const Icon(Icons.add),
            label: Text(AppLocalizations.of(context)!.buttonAddStep),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Image picker
  // ---------------------------------------------------------------------------

  /// Builds the cover-photo picker area.
  ///
  /// When a photo is set (either newly picked or carried over from the
  /// existing recipe / URL import), a small delete button is shown in the
  /// top-right corner so the user can remove it.
  Widget _buildImagePicker() {
    final bool hasImage =
        _pickedImage != null || _existingImagePath.isNotEmpty;

    Widget imageWidget;
    if (_pickedImage != null) {
      imageWidget = Image.file(_pickedImage!,
          height: 200, width: double.infinity, fit: BoxFit.cover);
    } else if (_existingImagePath.isNotEmpty) {
      imageWidget = Image.file(File(_existingImagePath),
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => _imagePlaceholder());
    } else {
      imageWidget = _imagePlaceholder();
    }

    return Stack(
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageWidget,
          ),
        ),
        // Delete button — only visible when a photo is set.
        if (hasImage)
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => setState(() {
                _isDirty = true;
                _pickedImage = null;
                _existingImagePath = '';
              }),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(6),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
      ],
    );
  }

  /// Placeholder shown when no cover photo is set.
  Widget _imagePlaceholder() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: RecipyColors.soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add_photo_alternate_outlined,
              size: 48, color: RecipyColors.inkSoft),
          const SizedBox(height: 8),
          Text(AppLocalizations.of(context)!.addCoverPhoto,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _GroupCard
// ---------------------------------------------------------------------------

/// A card representing a single ingredient group.
///
/// Receives a [_GroupEntry] (which owns all [TextEditingController]s) so
/// that reordering the group list never disposes and recreates controllers —
/// preventing text values from being reset.
class _GroupCard extends StatelessWidget {
  final _GroupEntry entry;
  final int groupIndex;
  final int totalGroups;
  final VoidCallback onAddItem;
  final ValueChanged<int> onRemoveItem;
  final void Function(int oldIndex, int newIndex) onItemReorder;

  /// Null when this is the only group (disables the remove button).
  final VoidCallback? onRemoveGroup;

  const _GroupCard({
    required super.key,
    required this.entry,
    required this.groupIndex,
    required this.totalGroups,
    required this.onAddItem,
    required this.onRemoveItem,
    required this.onItemReorder,
    required this.onRemoveGroup,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: RecipyColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: RecipyColors.rule),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Group header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      // Controller is owned by _GroupEntry — survives rebuilds.
                      controller: entry.nameController,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.groupNameHint,
                        hintStyle: tt.bodySmall
                            ?.copyWith(color: RecipyColors.inkSoft),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: tt.titleSmall?.copyWith(
                        color: RecipyColors.accent2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (onRemoveGroup != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: AppLocalizations.of(context)!.tooltipRemoveGroup,
                      color: RecipyColors.inkSoft,
                      onPressed: onRemoveGroup,
                      visualDensity: VisualDensity.compact,
                    ),
                  // Group-level drag handle — only shown when multiple groups.
                  if (totalGroups > 1)
                    ReorderableDragStartListener(
                      index: groupIndex,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.drag_indicator,
                            color: RecipyColors.inkSoft),
                      ),
                    ),
                ],
              ),
            ),

            const Divider(height: 1, color: RecipyColors.rule),

            // ── Item list ─────────────────────────────────────────────────
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: onItemReorder,
              children: [
                for (int ii = 0; ii < entry.items.length; ii++)
                  _IngredientItemRow(
                    // ObjectKey on the _ItemEntry so identity survives reorder.
                    key: ObjectKey(entry.items[ii]),
                    itemEntry: entry.items[ii],
                    itemIndex: ii,
                    totalItems: entry.items.length,
                    onRemove: entry.items.length > 1
                        ? () => onRemoveItem(ii)
                        : null,
                  ),
              ],
            ),

            // "+ Add item" button.
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: TextButton.icon(
                onPressed: onAddItem,
                icon: const Icon(Icons.add, size: 18),
                label: Text(AppLocalizations.of(context)!.buttonAddItem),
                style: TextButton.styleFrom(
                  foregroundColor: RecipyColors.accent,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _IngredientItemRow
// ---------------------------------------------------------------------------

/// A single ingredient item row with a text field, delete button, and drag
/// handle.
///
/// Uses the [TextEditingController] and [FocusNode] from [itemEntry] so that
/// reordering the list never resets text values or loses focus state.
class _IngredientItemRow extends StatefulWidget {
  final _ItemEntry itemEntry;
  final int itemIndex;
  final int totalItems;
  final VoidCallback? onRemove;

  const _IngredientItemRow({
    required super.key,
    required this.itemEntry,
    required this.itemIndex,
    required this.totalItems,
    required this.onRemove,
  });

  @override
  State<_IngredientItemRow> createState() => _IngredientItemRowState();
}

class _IngredientItemRowState extends State<_IngredientItemRow> {
  @override
  void initState() {
    super.initState();
    // Request focus after the frame if this item was freshly added.
    if (widget.itemEntry.requestFocusOnBuild) {
      widget.itemEntry.requestFocusOnBuild = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.itemEntry.focusNode.requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Accent bullet dot matching the detail screen style.
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: RecipyColors.accent,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: TextField(
              controller: widget.itemEntry.controller,
              focusNode: widget.itemEntry.focusNode,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.ingredientHint,
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, size: 18),
            color: RecipyColors.inkSoft,
            onPressed: widget.onRemove,
            visualDensity: VisualDensity.compact,
            tooltip: AppLocalizations.of(context)!.tooltipRemoveItem,
          ),
          // Per-item drag handle.
          ReorderableDragStartListener(
            index: widget.itemIndex,
            child: const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.drag_handle,
                  color: RecipyColors.inkSoft, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _StepRow
// ---------------------------------------------------------------------------

/// A single step row with a controller-backed text field, delete button, and
/// drag handle.
///
/// Receives its [TextEditingController] and [FocusNode] from the parent state
/// so reordering doesn't reset values.
class _StepRow extends StatefulWidget {
  final int index;
  final TextEditingController controller;
  final FocusNode focusNode;

  /// When true, this field requests focus after the first frame.
  final bool autoFocus;
  final int totalSteps;
  final VoidCallback? onRemove;

  const _StepRow({
    required super.key,
    required this.index,
    required this.controller,
    required this.focusNode,
    required this.autoFocus,
    required this.totalSteps,
    required this.onRemove,
  });

  @override
  State<_StepRow> createState() => _StepRowState();
}

class _StepRowState extends State<_StepRow> {
  @override
  void initState() {
    super.initState();
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.focusNode.requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14, right: 8),
            child: Text(
              '${widget.index + 1}.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.stepHint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: null,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: widget.onRemove,
            tooltip: AppLocalizations.of(context)!.tooltipRemoveStep,
          ),
          // Step drag handle.
          ReorderableDragStartListener(
            index: widget.index,
            child: const Padding(
              padding: EdgeInsets.only(top: 12, right: 4),
              child: Icon(Icons.drag_handle, color: RecipyColors.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}
