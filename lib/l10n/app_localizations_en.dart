// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Recipy';

  @override
  String get noRecipesToExport => 'No recipes to export.';

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String pdfFailed(String error) {
    return 'PDF failed: $error';
  }

  @override
  String shareFailed(String error) {
    return 'Share failed: $error';
  }

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get recipeImportedOne => '1 recipe imported.';

  @override
  String recipesImportedMany(int count) {
    return '$count recipes imported.';
  }

  @override
  String get newRecipeOption => 'New recipe';

  @override
  String get newRecipeOptionSubtitle => 'Fill in the details manually';

  @override
  String get importFromUrlOption => 'Import from URL';

  @override
  String get importFromUrlOptionSubtitle => 'Paste a link to a recipe page';

  @override
  String get moreActions => 'More actions';

  @override
  String get exportCollection => 'Export collection';

  @override
  String get importFromFile => 'Import from file';

  @override
  String get printRecipeBook => 'Print recipe book';

  @override
  String get searchHint => 'Search recipes or ingredients…';

  @override
  String recipeCountAll(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString recipes',
      one: '1 recipe',
    );
    return '$_temp0';
  }

  @override
  String recipeCountFiltered(int filtered, int total) {
    return '$filtered of $total recipes';
  }

  @override
  String couldNotLoadRecipes(String error) {
    return 'Could not load recipes: $error';
  }

  @override
  String get noRecipesYet => 'No recipes yet';

  @override
  String get noRecipesYetSub =>
      'Tap the + button to add your first recipe or import one from a URL.';

  @override
  String noResultsFor(String query) {
    return 'No results for \"$query\"';
  }

  @override
  String get noResultsForSub => 'Try a different title, ingredient, or tag.';

  @override
  String get addRecipeTooltip => 'Add recipe';

  @override
  String get deleteRecipeTitle => 'Delete recipe?';

  @override
  String get deleteRecipeContent => 'This cannot be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get open => 'Open';

  @override
  String errorLoadingRecipe(String error) {
    return 'Error loading recipe: $error';
  }

  @override
  String get recipeNotFound => 'Recipe not found.';

  @override
  String get tooltipBack => 'Back';

  @override
  String get tooltipShare => 'Share recipe';

  @override
  String get tooltipPdf => 'Print / Save PDF';

  @override
  String get tooltipEdit => 'Edit recipe';

  @override
  String get tooltipDelete => 'Delete recipe';

  @override
  String get sectionIngredients => 'INGREDIENTS';

  @override
  String get sectionMethod => 'METHOD';

  @override
  String get sectionNotes => 'NOTES';

  @override
  String get openLinkTitle => 'Open link?';

  @override
  String servingsLabel(int count) {
    return '$count servings';
  }

  @override
  String prepTimeLabel(int minutes) {
    return '$minutes min';
  }

  @override
  String get newRecipeTitle => 'New Recipe';

  @override
  String get editRecipeTitle => 'Edit Recipe';

  @override
  String get tooltipSave => 'Save';

  @override
  String get fieldTitle => 'Title *';

  @override
  String get fieldDescription => 'Description';

  @override
  String get fieldPrepTime => 'Prep time (min)';

  @override
  String get fieldServings => 'Servings';

  @override
  String get fieldTags => 'Tags';

  @override
  String get tagsHint => 'e.g. vegetarian, quick…';

  @override
  String get sectionIngredientsEdit => 'Ingredients';

  @override
  String get ingredientsReorderHint =>
      'Drag groups or items to reorder. Tap + Group to add a named section.';

  @override
  String get sectionStepsEdit => 'Steps';

  @override
  String get sectionNotesEdit => 'Notes';

  @override
  String get notesHint =>
      'Variations tried, sourcing tips, serving suggestions…';

  @override
  String get buttonCreateRecipe => 'Create Recipe';

  @override
  String get buttonSaveChanges => 'Save Changes';

  @override
  String get buttonAddGroup => 'Add group';

  @override
  String get buttonAddStep => 'Add step';

  @override
  String get buttonAddItem => 'Add item';

  @override
  String get addCoverPhoto => 'Add cover photo';

  @override
  String get groupNameHint => 'Group name (optional)';

  @override
  String get tooltipRemoveGroup => 'Remove group';

  @override
  String get tooltipRemoveItem => 'Remove item';

  @override
  String get ingredientHint => 'e.g. 200g pasta';

  @override
  String get stepHint => 'Describe this step…';

  @override
  String get tooltipRemoveStep => 'Remove step';

  @override
  String get duplicateRecipeName => 'A recipe with this name already exists.';

  @override
  String saveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get importFromUrlTitle => 'Import from URL';

  @override
  String get importFromUrlInstruction => 'Paste the URL of a recipe page:';

  @override
  String get urlHint => 'https://…';

  @override
  String get buttonImport => 'Import';

  @override
  String get urlInvalid => 'Invalid URL';

  @override
  String urlUnreachable(String error) {
    return 'Could not reach the page: $error';
  }

  @override
  String urlHttpError(int code) {
    return 'Page returned HTTP $code';
  }

  @override
  String get urlParseError =>
      'Could not extract recipe data from this page. Try filling in the details manually.';

  @override
  String cardPrepTime(int minutes) {
    return '$minutes min';
  }

  @override
  String cardServings(int count) {
    return '$count serv.';
  }

  @override
  String shareRecipeText(String title) {
    return 'Here\'s my recipe for $title!';
  }

  @override
  String get shareCollectionSubject => 'My Recipy collection';

  @override
  String get shareCollectionText =>
      'Here are all my recipes exported from Recipy!';

  @override
  String get jsonNotRecipeData =>
      'JSON file does not appear to contain recipe data.';

  @override
  String get jsonUnrecognisedFormat => 'Unrecognised JSON format.';

  @override
  String pdfSourceLabel(String url) {
    return 'Source: $url';
  }

  @override
  String get pdfSectionIngredients => 'Ingredients';

  @override
  String get pdfSectionSteps => 'Steps';

  @override
  String get pdfSectionNotes => 'Notes';

  @override
  String get pdfBookTitle => 'My Recipe Book';

  @override
  String pdfRecipeCount(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString recipes',
      one: '1 recipe',
    );
    return '$_temp0';
  }

  @override
  String get pdfGeneratedBy => 'Generated by Recipy';

  @override
  String get pdfContents => 'Contents';

  @override
  String pdfPrepTime(int minutes) {
    return 'Prep: $minutes min';
  }

  @override
  String pdfServes(int count) {
    return 'Serves: $count';
  }

  @override
  String pdfPageOf(int page, int total) {
    return 'Page $page of $total';
  }

  @override
  String get saveToDevice => 'Save to device';

  @override
  String get saveToDeviceSubtitle =>
      'Save the .recipy file to your Downloads folder';

  @override
  String get shareViaApp => 'Share via…';

  @override
  String get shareViaAppSubtitle => 'Send via email, Bluetooth, or another app';

  @override
  String savedToDevice(String path) {
    return 'Saved to $path';
  }

  @override
  String get importConfirmTitle => 'Import recipe?';

  @override
  String importConfirmContentOne(String title) {
    return 'Add \"$title\" to your collection?';
  }

  @override
  String importConfirmContentMany(int count) {
    return 'Add $count recipes to your collection?';
  }

  @override
  String deleteMultipleRecipesContent(int count) {
    return 'Delete $count recipes? This cannot be undone.';
  }

  @override
  String get tooltipFavourite => 'Mark as favourite';

  @override
  String get tooltipUnfavourite => 'Remove from favourites';

  @override
  String get discardChangesTitle => 'Discard changes?';

  @override
  String get discardChangesContent =>
      'You have unsaved changes. Are you sure you want to leave?';

  @override
  String get discard => 'Discard';

  @override
  String get filterFavourites => 'Favourites';

  @override
  String get noFavouritesYet => 'No favourites yet';

  @override
  String get noFavouritesYetSub =>
      'Tap the heart on any recipe to mark it as a favourite.';
}
