import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../data/recipe_repository.dart';
import '../../domain/recipe.dart';
import '../../../../core/router/app_router.dart';

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

  const RecipeEditScreen({super.key, required this.recipeId});

  @override
  ConsumerState<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends ConsumerState<RecipeEditScreen> {
  /// True when [recipeId] is null — the screen is creating a brand-new recipe.
  bool get _isNew => widget.recipeId == null;

  final _formKey = GlobalKey<FormState>();

  // One controller per simple text field.
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _prepTimeController = TextEditingController();
  final _servingsController = TextEditingController();
  final _tagsController = TextEditingController();

  /// Ordered list of ingredient strings shown in the dynamic list editor.
  /// Starts with one blank row so the user can immediately type.
  List<String> _ingredients = [''];

  /// Ordered list of step strings shown in the dynamic list editor.
  List<String> _steps = [''];

  /// A newly picked image file that has not yet been copied to app storage.
  /// Null means the user has not chosen a new image in this session.
  File? _pickedImage;

  /// The absolute path to the image already stored in the app's documents
  /// directory (from a previous save).  Preserved when the user edits without
  /// changing the photo.
  String _existingImagePath = '';

  /// True while the save operation is in progress (disables the save button).
  bool _isSaving = false;

  /// True while the existing recipe is being loaded from SQLite in edit mode.
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (!_isNew) _loadRecipe();
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
        _tagsController.text = recipe.tags.join(', ');
        _ingredients =
            recipe.ingredients.isNotEmpty ? recipe.ingredients : [''];
        _steps = recipe.steps.isNotEmpty ? recipe.steps : [''];
        _existingImagePath = recipe.imagePath;
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _prepTimeController.dispose();
    _servingsController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  /// Opens the device gallery so the user can pick a cover photo.
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null && mounted) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  /// Copies [_pickedImage] into the app's documents directory and returns
  /// the stable absolute path.
  ///
  /// Storing the copy (rather than the gallery path) ensures the image
  /// remains available even if the user clears their gallery or moves the
  /// original file.
  Future<String> _copyImageToAppDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(dir.path, 'recipe_images'));
    if (!imagesDir.existsSync()) imagesDir.createSync(recursive: true);

    // Use a timestamp-based filename to avoid collisions between recipes.
    final ext = p.extension(_pickedImage!.path).isNotEmpty
        ? p.extension(_pickedImage!.path)
        : '.jpg';
    final filename = '${DateTime.now().millisecondsSinceEpoch}$ext';
    final dest = File(p.join(imagesDir.path, filename));
    await _pickedImage!.copy(dest.path);
    return dest.path;
  }

  /// Validates the form, optionally copies the image, then writes to SQLite.
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      // Copy the newly picked image; otherwise keep the existing path.
      String imagePath = _existingImagePath;
      if (_pickedImage != null) {
        imagePath = await _copyImageToAppDir();
      }

      // Parse comma-separated tags, trimming whitespace and dropping blanks.
      final tags = _tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      // Drop any blank rows the user left in the ingredient / step lists.
      final ingredients =
          _ingredients.where((i) => i.trim().isNotEmpty).toList();
      final steps = _steps.where((s) => s.trim().isNotEmpty).toList();

      final now = DateTime.now();
      final recipe = Recipe(
        id: widget.recipeId ?? 0,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        ingredients: ingredients,
        steps: steps,
        prepTimeMinutes: int.tryParse(_prepTimeController.text) ?? 0,
        servings: int.tryParse(_servingsController.text) ?? 0,
        tags: tags,
        imagePath: imagePath,
        sourceUrl: '',
        createdAt: now,
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
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New Recipe' : 'Edit Recipe'),
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
                  tooltip: 'Save',
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
                  // Cover photo picker
                  _buildImagePicker(),
                  const SizedBox(height: 16),

                  // Title (required)
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title *',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
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
                          decoration: const InputDecoration(
                            labelText: 'Prep time (min)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _servingsController,
                          decoration: const InputDecoration(
                            labelText: 'Servings',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Tags
                  TextFormField(
                    controller: _tagsController,
                    decoration: const InputDecoration(
                      labelText: 'Tags (comma-separated)',
                      hintText: 'e.g. vegetarian, quick, Italian',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Ingredients list
                  Text('Ingredients',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _buildListEditor(
                    items: _ingredients,
                    hint: 'e.g. 200g pasta',
                    onChanged: (items) =>
                        setState(() => _ingredients = items),
                  ),
                  const SizedBox(height: 24),

                  // Steps list
                  Text('Steps',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _buildListEditor(
                    items: _steps,
                    hint: 'Describe this step…',
                    multiline: true,
                    onChanged: (items) => setState(() => _steps = items),
                  ),
                  const SizedBox(height: 32),

                  // Bottom save button
                  FilledButton(
                    onPressed: _isSaving ? null : _save,
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                    child:
                        Text(_isNew ? 'Create Recipe' : 'Save Changes'),
                  ),
                ],
              ),
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helper widget builders
  // ---------------------------------------------------------------------------

  /// Builds the cover-photo picker area.
  ///
  /// Shows the newly picked local file, the previously saved image, or a
  /// placeholder if no image exists.  Tapping opens the gallery.
  Widget _buildImagePicker() {
    Widget imageWidget;

    if (_pickedImage != null) {
      // Freshly picked — load directly from disk.
      imageWidget = Image.file(_pickedImage!,
          height: 200, width: double.infinity, fit: BoxFit.cover);
    } else if (_existingImagePath.isNotEmpty) {
      // Previously saved — load from the app's documents directory.
      imageWidget = Image.file(File(_existingImagePath),
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) =>
              _imagePlaceholder());
    } else {
      imageWidget = _imagePlaceholder();
    }

    return GestureDetector(
      onTap: _pickImage,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: imageWidget,
      ),
    );
  }

  /// Placeholder shown when no cover photo is set.
  Widget _imagePlaceholder() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text('Add cover photo',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  /// Builds a dynamic ordered list editor for ingredients or steps.
  ///
  /// Each item is a [TextFormField] with a delete button.  An "Add item"
  /// button at the bottom appends a new blank row.  [multiline] makes each
  /// field expand vertically (used for steps).
  Widget _buildListEditor({
    required List<String> items,
    required String hint,
    required ValueChanged<List<String>> onChanged,
    bool multiline = false,
  }) {
    return Column(
      children: [
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step number or bullet prefix.
                Padding(
                  padding: const EdgeInsets.only(top: 14, right: 8),
                  child: Text(
                    multiline ? '${index + 1}.' : '•',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                Expanded(
                  child: TextFormField(
                    initialValue: entry.value,
                    decoration: InputDecoration(
                      hintText: hint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: multiline ? null : 1,
                    minLines: multiline ? 2 : 1,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (v) {
                      final updated = List<String>.from(items);
                      updated[index] = v;
                      onChanged(updated);
                    },
                  ),
                ),
                // Disable the delete button when only one row remains so the
                // user cannot accidentally remove all rows.
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: items.length > 1
                      ? () {
                          final updated = List<String>.from(items)
                            ..removeAt(index);
                          onChanged(updated);
                        }
                      : null,
                ),
              ],
            ),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => onChanged([...items, '']),
            icon: const Icon(Icons.add),
            label: const Text('Add item'),
          ),
        ),
      ],
    );
  }
}
