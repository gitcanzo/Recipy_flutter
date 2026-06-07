import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('it'),
  ];

  /// The name of the app
  ///
  /// In en, this message translates to:
  /// **'Recipy'**
  String get appTitle;

  /// Snackbar when export is attempted with empty collection
  ///
  /// In en, this message translates to:
  /// **'No recipes to export.'**
  String get noRecipesToExport;

  /// Snackbar when export throws
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(String error);

  /// Snackbar when PDF generation throws
  ///
  /// In en, this message translates to:
  /// **'PDF failed: {error}'**
  String pdfFailed(String error);

  /// Snackbar when sharing throws
  ///
  /// In en, this message translates to:
  /// **'Share failed: {error}'**
  String shareFailed(String error);

  /// Snackbar when file import throws
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importFailed(String error);

  /// Snackbar after importing exactly 1 recipe
  ///
  /// In en, this message translates to:
  /// **'1 recipe imported.'**
  String get recipeImportedOne;

  /// Snackbar after importing multiple recipes
  ///
  /// In en, this message translates to:
  /// **'{count} recipes imported.'**
  String recipesImportedMany(int count);

  /// Bottom sheet option to create a new recipe manually
  ///
  /// In en, this message translates to:
  /// **'New recipe'**
  String get newRecipeOption;

  /// Subtitle for the new recipe option
  ///
  /// In en, this message translates to:
  /// **'Fill in the details manually'**
  String get newRecipeOptionSubtitle;

  /// Bottom sheet option to import from URL
  ///
  /// In en, this message translates to:
  /// **'Import from URL'**
  String get importFromUrlOption;

  /// Subtitle for the import from URL option
  ///
  /// In en, this message translates to:
  /// **'Paste a link to a recipe page'**
  String get importFromUrlOptionSubtitle;

  /// Tooltip for the overflow menu button
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get moreActions;

  /// Menu item to export all recipes as JSON
  ///
  /// In en, this message translates to:
  /// **'Export collection'**
  String get exportCollection;

  /// Menu item to import recipes from a JSON file
  ///
  /// In en, this message translates to:
  /// **'Import from file'**
  String get importFromFile;

  /// Menu item to print/PDF all recipes
  ///
  /// In en, this message translates to:
  /// **'Print recipe book'**
  String get printRecipeBook;

  /// Hint text inside the search bar
  ///
  /// In en, this message translates to:
  /// **'Search recipes or ingredients…'**
  String get searchHint;

  /// Recipe count label when no search is active
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 recipe} other{{count} recipes}}'**
  String recipeCountAll(num count);

  /// Recipe count label when a search filter is active
  ///
  /// In en, this message translates to:
  /// **'{filtered} of {total} recipes'**
  String recipeCountFiltered(int filtered, int total);

  /// Error message when the recipe list fails to load
  ///
  /// In en, this message translates to:
  /// **'Could not load recipes: {error}'**
  String couldNotLoadRecipes(String error);

  /// Empty state headline when the collection is empty
  ///
  /// In en, this message translates to:
  /// **'No recipes yet'**
  String get noRecipesYet;

  /// Empty state sub-message when the collection is empty
  ///
  /// In en, this message translates to:
  /// **'Tap the + button to add your first recipe or import one from a URL.'**
  String get noRecipesYetSub;

  /// Empty state headline when search yields nothing
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\"'**
  String noResultsFor(String query);

  /// Empty state sub-message when search yields nothing
  ///
  /// In en, this message translates to:
  /// **'Try a different title, ingredient, or tag.'**
  String get noResultsForSub;

  /// FAB tooltip
  ///
  /// In en, this message translates to:
  /// **'Add recipe'**
  String get addRecipeTooltip;

  /// Confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete recipe?'**
  String get deleteRecipeTitle;

  /// Confirmation dialog body
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get deleteRecipeContent;

  /// Generic cancel button label
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Confirm delete button label
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Confirm open-link button label
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// Error shown on the detail screen when the recipe fails to load
  ///
  /// In en, this message translates to:
  /// **'Error loading recipe: {error}'**
  String errorLoadingRecipe(String error);

  /// Shown when no recipe matches the given ID
  ///
  /// In en, this message translates to:
  /// **'Recipe not found.'**
  String get recipeNotFound;

  /// Tooltip for the back button in the app bar
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get tooltipBack;

  /// Tooltip for the share button
  ///
  /// In en, this message translates to:
  /// **'Share recipe'**
  String get tooltipShare;

  /// Tooltip for the PDF button
  ///
  /// In en, this message translates to:
  /// **'Print / Save PDF'**
  String get tooltipPdf;

  /// Tooltip for the button that switches the recipe list to list view
  ///
  /// In en, this message translates to:
  /// **'Switch to list view'**
  String get viewModeList;

  /// Tooltip for the button that switches the recipe list to grid view
  ///
  /// In en, this message translates to:
  /// **'Switch to grid view'**
  String get viewModeGrid;

  /// Tooltip for the edit button
  ///
  /// In en, this message translates to:
  /// **'Edit recipe'**
  String get tooltipEdit;

  /// Tooltip for the delete button
  ///
  /// In en, this message translates to:
  /// **'Delete recipe'**
  String get tooltipDelete;

  /// Eyebrow label above the ingredients card
  ///
  /// In en, this message translates to:
  /// **'INGREDIENTS'**
  String get sectionIngredients;

  /// Eyebrow label above the steps card
  ///
  /// In en, this message translates to:
  /// **'METHOD'**
  String get sectionMethod;

  /// Eyebrow label above the notes card
  ///
  /// In en, this message translates to:
  /// **'NOTES'**
  String get sectionNotes;

  /// Confirmation dialog title before opening a URL
  ///
  /// In en, this message translates to:
  /// **'Open link?'**
  String get openLinkTitle;

  /// Servings chip label on detail screen
  ///
  /// In en, this message translates to:
  /// **'{count} servings'**
  String servingsLabel(int count);

  /// Prep time chip label
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String prepTimeLabel(int minutes);

  /// App bar title when creating a new recipe
  ///
  /// In en, this message translates to:
  /// **'New Recipe'**
  String get newRecipeTitle;

  /// App bar title when editing an existing recipe
  ///
  /// In en, this message translates to:
  /// **'Edit Recipe'**
  String get editRecipeTitle;

  /// Tooltip for the save icon button in the edit screen app bar
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get tooltipSave;

  /// Label for the title input field
  ///
  /// In en, this message translates to:
  /// **'Title *'**
  String get fieldTitle;

  /// Label for the description input field
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get fieldDescription;

  /// Label for the prep time input field
  ///
  /// In en, this message translates to:
  /// **'Prep time (min)'**
  String get fieldPrepTime;

  /// Label for the servings input field
  ///
  /// In en, this message translates to:
  /// **'Servings'**
  String get fieldServings;

  /// Label for the tags chip input
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get fieldTags;

  /// Hint text inside the tag input field when no tags exist
  ///
  /// In en, this message translates to:
  /// **'e.g. vegetarian, quick…'**
  String get tagsHint;

  /// Section title above the ingredients editor
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get sectionIngredientsEdit;

  /// Helper text below the ingredients section title
  ///
  /// In en, this message translates to:
  /// **'Drag groups or items to reorder. Tap + Group to add a named section.'**
  String get ingredientsReorderHint;

  /// Section title above the steps editor
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get sectionStepsEdit;

  /// Section title above the notes field
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get sectionNotesEdit;

  /// Hint text inside the notes field
  ///
  /// In en, this message translates to:
  /// **'Variations tried, sourcing tips, serving suggestions…'**
  String get notesHint;

  /// Save button label when creating a new recipe
  ///
  /// In en, this message translates to:
  /// **'Create Recipe'**
  String get buttonCreateRecipe;

  /// Save button label when editing an existing recipe
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get buttonSaveChanges;

  /// Button to add a new ingredient group
  ///
  /// In en, this message translates to:
  /// **'Add group'**
  String get buttonAddGroup;

  /// Button to add a new step
  ///
  /// In en, this message translates to:
  /// **'Add step'**
  String get buttonAddStep;

  /// Button to add a new ingredient item
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get buttonAddItem;

  /// Placeholder text inside the image picker area
  ///
  /// In en, this message translates to:
  /// **'Add cover photo'**
  String get addCoverPhoto;

  /// Hint text inside the ingredient group name field
  ///
  /// In en, this message translates to:
  /// **'Group name (optional)'**
  String get groupNameHint;

  /// Tooltip for the remove-group icon button
  ///
  /// In en, this message translates to:
  /// **'Remove group'**
  String get tooltipRemoveGroup;

  /// Tooltip for the remove-ingredient icon button
  ///
  /// In en, this message translates to:
  /// **'Remove item'**
  String get tooltipRemoveItem;

  /// Hint text inside an ingredient field
  ///
  /// In en, this message translates to:
  /// **'e.g. 200g pasta'**
  String get ingredientHint;

  /// Hint text inside a step field
  ///
  /// In en, this message translates to:
  /// **'Describe this step…'**
  String get stepHint;

  /// Tooltip for the remove-step icon button
  ///
  /// In en, this message translates to:
  /// **'Remove step'**
  String get tooltipRemoveStep;

  /// Snackbar shown when saving a recipe with a duplicate title
  ///
  /// In en, this message translates to:
  /// **'A recipe with this name already exists.'**
  String get duplicateRecipeName;

  /// Snackbar when the save operation throws
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String saveFailed(String error);

  /// App bar title for the URL import screen
  ///
  /// In en, this message translates to:
  /// **'Import from URL'**
  String get importFromUrlTitle;

  /// Instruction label above the URL field
  ///
  /// In en, this message translates to:
  /// **'Paste the URL of a recipe page:'**
  String get importFromUrlInstruction;

  /// Hint text inside the URL input field
  ///
  /// In en, this message translates to:
  /// **'https://…'**
  String get urlHint;

  /// Button label to trigger URL import
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get buttonImport;

  /// Error when the pasted URL cannot be parsed
  ///
  /// In en, this message translates to:
  /// **'Invalid URL'**
  String get urlInvalid;

  /// Error when the HTTP request fails
  ///
  /// In en, this message translates to:
  /// **'Could not reach the page: {error}'**
  String urlUnreachable(String error);

  /// Error when the server returns a non-200 status
  ///
  /// In en, this message translates to:
  /// **'Page returned HTTP {code}'**
  String urlHttpError(int code);

  /// Error when no parser strategy succeeds
  ///
  /// In en, this message translates to:
  /// **'Could not extract recipe data from this page. Try filling in the details manually.'**
  String get urlParseError;

  /// Prep time label on the recipe card
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String cardPrepTime(int minutes);

  /// Servings label on the recipe card
  ///
  /// In en, this message translates to:
  /// **'{count} serv.'**
  String cardServings(int count);

  /// Share sheet text when sharing a single recipe
  ///
  /// In en, this message translates to:
  /// **'Here\'s my recipe for {title}!'**
  String shareRecipeText(String title);

  /// Subject line when sharing the full collection
  ///
  /// In en, this message translates to:
  /// **'My Recipy collection'**
  String get shareCollectionSubject;

  /// Body text when sharing the full collection
  ///
  /// In en, this message translates to:
  /// **'Here are all my recipes exported from Recipy!'**
  String get shareCollectionText;

  /// Error when imported JSON has no recognisable recipe structure
  ///
  /// In en, this message translates to:
  /// **'JSON file does not appear to contain recipe data.'**
  String get jsonNotRecipeData;

  /// Error when imported JSON has an unexpected shape
  ///
  /// In en, this message translates to:
  /// **'Unrecognised JSON format.'**
  String get jsonUnrecognisedFormat;

  /// Source URL line in the PDF
  ///
  /// In en, this message translates to:
  /// **'Source: {url}'**
  String pdfSourceLabel(String url);

  /// Section header in the PDF
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get pdfSectionIngredients;

  /// Section header in the PDF
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get pdfSectionSteps;

  /// Notes section header in the PDF
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get pdfSectionNotes;

  /// Title on the PDF recipe book cover and header
  ///
  /// In en, this message translates to:
  /// **'My Recipe Book'**
  String get pdfBookTitle;

  /// Recipe count on the PDF cover
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 recipe} other{{count} recipes}}'**
  String pdfRecipeCount(num count);

  /// Footer text on every PDF page
  ///
  /// In en, this message translates to:
  /// **'Generated by Recipy'**
  String get pdfGeneratedBy;

  /// Table of contents header in the PDF book
  ///
  /// In en, this message translates to:
  /// **'Contents'**
  String get pdfContents;

  /// Prep time metadata in the PDF
  ///
  /// In en, this message translates to:
  /// **'Prep: {minutes} min'**
  String pdfPrepTime(int minutes);

  /// Servings metadata in the PDF
  ///
  /// In en, this message translates to:
  /// **'Serves: {count}'**
  String pdfServes(int count);

  /// Page number footer in the PDF
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {total}'**
  String pdfPageOf(int page, int total);

  /// Export bottom sheet option to save the file locally
  ///
  /// In en, this message translates to:
  /// **'Save to device'**
  String get saveToDevice;

  /// Subtitle for the save to device option
  ///
  /// In en, this message translates to:
  /// **'Save the .recipy file to your Downloads folder'**
  String get saveToDeviceSubtitle;

  /// Subtitle for the open-in-viewer option in the PDF export bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Open in the system PDF viewer'**
  String get savePdfToDeviceSubtitle;

  /// Export bottom sheet option to open the system share sheet
  ///
  /// In en, this message translates to:
  /// **'Share via…'**
  String get shareViaApp;

  /// Subtitle for the share via app option
  ///
  /// In en, this message translates to:
  /// **'Send via email, Bluetooth, or another app'**
  String get shareViaAppSubtitle;

  /// Snackbar shown after a file is saved to the device
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String savedToDevice(String path);

  /// Dialog title when a .recipy file is opened
  ///
  /// In en, this message translates to:
  /// **'Import recipe?'**
  String get importConfirmTitle;

  /// Dialog body when a single recipe is being imported
  ///
  /// In en, this message translates to:
  /// **'Add \"{title}\" to your collection?'**
  String importConfirmContentOne(String title);

  /// Dialog body when multiple recipes are being imported
  ///
  /// In en, this message translates to:
  /// **'Add {count} recipes to your collection?'**
  String importConfirmContentMany(int count);

  /// Confirmation dialog body when deleting multiple recipes
  ///
  /// In en, this message translates to:
  /// **'Delete {count} recipes? This cannot be undone.'**
  String deleteMultipleRecipesContent(int count);

  /// Tooltip for the favourite toggle button
  ///
  /// In en, this message translates to:
  /// **'Mark as favourite'**
  String get tooltipFavourite;

  /// Tooltip for the unfavourite toggle button
  ///
  /// In en, this message translates to:
  /// **'Remove from favourites'**
  String get tooltipUnfavourite;

  /// Dialog title when leaving edit screen with unsaved changes
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get discardChangesTitle;

  /// Dialog body when leaving edit screen with unsaved changes
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Are you sure you want to leave?'**
  String get discardChangesContent;

  /// Confirm discard button label
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// Filter chip label to show only favourite recipes
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get filterFavourites;

  /// Empty state headline when the favourites filter is on but no recipes are starred
  ///
  /// In en, this message translates to:
  /// **'No favourites yet'**
  String get noFavouritesYet;

  /// Empty state sub-message for the empty favourites filter
  ///
  /// In en, this message translates to:
  /// **'Tap the heart on any recipe to mark it as a favourite.'**
  String get noFavouritesYetSub;

  /// Snackbar when exactly 1 recipe was skipped during import due to a duplicate title
  ///
  /// In en, this message translates to:
  /// **'1 recipe skipped (duplicate name).'**
  String get importSkippedOne;

  /// Snackbar when multiple recipes were skipped during import due to duplicate titles
  ///
  /// In en, this message translates to:
  /// **'{count} recipes skipped (duplicate names).'**
  String importSkippedMany(int count);

  /// Snackbar when every recipe in an import file is a duplicate
  ///
  /// In en, this message translates to:
  /// **'Nothing imported — all recipes already exist.'**
  String get importAllDuplicates;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
