// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'Recipy';

  @override
  String get noRecipesToExport => 'Nessuna ricetta da esportare.';

  @override
  String exportFailed(String error) {
    return 'Esportazione fallita: $error';
  }

  @override
  String pdfFailed(String error) {
    return 'PDF fallito: $error';
  }

  @override
  String shareFailed(String error) {
    return 'Condivisione fallita: $error';
  }

  @override
  String importFailed(String error) {
    return 'Importazione fallita: $error';
  }

  @override
  String get recipeImportedOne => '1 ricetta importata.';

  @override
  String recipesImportedMany(int count) {
    return '$count ricette importate.';
  }

  @override
  String get newRecipeOption => 'Nuova ricetta';

  @override
  String get newRecipeOptionSubtitle => 'Inserisci i dettagli manualmente';

  @override
  String get importFromUrlOption => 'Importa da URL';

  @override
  String get importFromUrlOptionSubtitle =>
      'Incolla il link a una pagina di ricetta';

  @override
  String get moreActions => 'Altre azioni';

  @override
  String get exportCollection => 'Esporta raccolta';

  @override
  String get importFromFile => 'Importa da file';

  @override
  String get printRecipeBook => 'Stampa libro di ricette';

  @override
  String get searchHint => 'Cerca ricette o ingredienti…';

  @override
  String recipeCountAll(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString ricette',
      one: '1 ricetta',
    );
    return '$_temp0';
  }

  @override
  String recipeCountFiltered(int filtered, int total) {
    return '$filtered di $total ricette';
  }

  @override
  String couldNotLoadRecipes(String error) {
    return 'Impossibile caricare le ricette: $error';
  }

  @override
  String get noRecipesYet => 'Nessuna ricetta';

  @override
  String get noRecipesYetSub =>
      'Tocca + per aggiungere la tua prima ricetta o importane una da un URL.';

  @override
  String noResultsFor(String query) {
    return 'Nessun risultato per \"$query\"';
  }

  @override
  String get noResultsForSub => 'Prova un titolo, ingrediente o tag diverso.';

  @override
  String get addRecipeTooltip => 'Aggiungi ricetta';

  @override
  String get deleteRecipeTitle => 'Eliminare la ricetta?';

  @override
  String get deleteRecipeContent =>
      'Questa operazione non può essere annullata.';

  @override
  String get cancel => 'Annulla';

  @override
  String get delete => 'Elimina';

  @override
  String get open => 'Apri';

  @override
  String errorLoadingRecipe(String error) {
    return 'Errore nel caricamento della ricetta: $error';
  }

  @override
  String get recipeNotFound => 'Ricetta non trovata.';

  @override
  String get tooltipBack => 'Indietro';

  @override
  String get tooltipShare => 'Condividi ricetta';

  @override
  String get tooltipPdf => 'Stampa / Salva PDF';

  @override
  String get tooltipEdit => 'Modifica ricetta';

  @override
  String get tooltipDelete => 'Elimina ricetta';

  @override
  String get sectionIngredients => 'INGREDIENTI';

  @override
  String get sectionMethod => 'PROCEDIMENTO';

  @override
  String get sectionNotes => 'NOTE';

  @override
  String get openLinkTitle => 'Aprire il link?';

  @override
  String servingsLabel(int count) {
    return '$count porzioni';
  }

  @override
  String prepTimeLabel(int minutes) {
    return '$minutes min';
  }

  @override
  String get newRecipeTitle => 'Nuova ricetta';

  @override
  String get editRecipeTitle => 'Modifica ricetta';

  @override
  String get tooltipSave => 'Salva';

  @override
  String get fieldTitle => 'Titolo *';

  @override
  String get fieldDescription => 'Descrizione';

  @override
  String get fieldPrepTime => 'Tempo di preparazione (min)';

  @override
  String get fieldServings => 'Porzioni';

  @override
  String get fieldTags => 'Tag';

  @override
  String get tagsHint => 'es. vegetariano, veloce…';

  @override
  String get sectionIngredientsEdit => 'Ingredienti';

  @override
  String get ingredientsReorderHint =>
      'Trascina gruppi o elementi per riordinarli. Tocca + Gruppo per aggiungere una sezione.';

  @override
  String get sectionStepsEdit => 'Procedimento';

  @override
  String get sectionNotesEdit => 'Note';

  @override
  String get notesHint =>
      'Varianti provate, consigli sugli ingredienti, suggerimenti di servizio…';

  @override
  String get buttonCreateRecipe => 'Crea ricetta';

  @override
  String get buttonSaveChanges => 'Salva modifiche';

  @override
  String get buttonAddGroup => 'Aggiungi gruppo';

  @override
  String get buttonAddStep => 'Aggiungi passaggio';

  @override
  String get buttonAddItem => 'Aggiungi ingrediente';

  @override
  String get addCoverPhoto => 'Aggiungi foto di copertina';

  @override
  String get groupNameHint => 'Nome del gruppo (opzionale)';

  @override
  String get tooltipRemoveGroup => 'Rimuovi gruppo';

  @override
  String get tooltipRemoveItem => 'Rimuovi ingrediente';

  @override
  String get ingredientHint => 'es. 200g di pasta';

  @override
  String get stepHint => 'Descrivi questo passaggio…';

  @override
  String get tooltipRemoveStep => 'Rimuovi passaggio';

  @override
  String get duplicateRecipeName => 'Esiste già una ricetta con questo nome.';

  @override
  String saveFailed(String error) {
    return 'Salvataggio fallito: $error';
  }

  @override
  String get importFromUrlTitle => 'Importa da URL';

  @override
  String get importFromUrlInstruction =>
      'Incolla l\'URL di una pagina di ricetta:';

  @override
  String get urlHint => 'https://…';

  @override
  String get buttonImport => 'Importa';

  @override
  String get urlInvalid => 'URL non valido';

  @override
  String urlUnreachable(String error) {
    return 'Impossibile raggiungere la pagina: $error';
  }

  @override
  String urlHttpError(int code) {
    return 'La pagina ha restituito HTTP $code';
  }

  @override
  String get urlParseError =>
      'Impossibile estrarre i dati della ricetta da questa pagina. Prova a inserire i dettagli manualmente.';

  @override
  String cardPrepTime(int minutes) {
    return '$minutes min';
  }

  @override
  String cardServings(int count) {
    return '$count porz.';
  }

  @override
  String shareRecipeText(String title) {
    return 'Ecco la mia ricetta per $title!';
  }

  @override
  String get shareCollectionSubject => 'La mia raccolta Recipy';

  @override
  String get shareCollectionText =>
      'Ecco tutte le mie ricette esportate da Recipy!';

  @override
  String get jsonNotRecipeData =>
      'Il file JSON non sembra contenere dati di ricette.';

  @override
  String get jsonUnrecognisedFormat => 'Formato JSON non riconosciuto.';

  @override
  String pdfSourceLabel(String url) {
    return 'Fonte: $url';
  }

  @override
  String get pdfSectionIngredients => 'Ingredienti';

  @override
  String get pdfSectionSteps => 'Procedimento';

  @override
  String get pdfSectionNotes => 'Note';

  @override
  String get pdfBookTitle => 'Il mio libro di ricette';

  @override
  String pdfRecipeCount(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString ricette',
      one: '1 ricetta',
    );
    return '$_temp0';
  }

  @override
  String get pdfGeneratedBy => 'Generato da Recipy';

  @override
  String get pdfContents => 'Indice';

  @override
  String pdfPrepTime(int minutes) {
    return 'Prep: $minutes min';
  }

  @override
  String pdfServes(int count) {
    return 'Porzioni: $count';
  }

  @override
  String pdfPageOf(int page, int total) {
    return 'Pagina $page di $total';
  }

  @override
  String get saveToDevice => 'Salva sul dispositivo';

  @override
  String get saveToDeviceSubtitle =>
      'Salva il file .recipy nella cartella Download';

  @override
  String get shareViaApp => 'Condividi con…';

  @override
  String get shareViaAppSubtitle =>
      'Invia tramite email, Bluetooth o un\'altra app';

  @override
  String savedToDevice(String path) {
    return 'Salvato in $path';
  }

  @override
  String get importConfirmTitle => 'Importare la ricetta?';

  @override
  String importConfirmContentOne(String title) {
    return 'Aggiungere \"$title\" alla tua raccolta?';
  }

  @override
  String importConfirmContentMany(int count) {
    return 'Aggiungere $count ricette alla tua raccolta?';
  }

  @override
  String deleteMultipleRecipesContent(int count) {
    return 'Eliminare $count ricette? Questa operazione non può essere annullata.';
  }

  @override
  String get tooltipFavourite => 'Aggiungi ai preferiti';

  @override
  String get tooltipUnfavourite => 'Rimuovi dai preferiti';

  @override
  String get discardChangesTitle => 'Annullare le modifiche?';

  @override
  String get discardChangesContent =>
      'Hai modifiche non salvate. Vuoi davvero uscire?';

  @override
  String get discard => 'Annulla modifiche';

  @override
  String get filterFavourites => 'Preferiti';

  @override
  String get noFavouritesYet => 'Nessun preferito';

  @override
  String get noFavouritesYetSub =>
      'Tocca il cuore su una ricetta per aggiungerla ai preferiti.';

  @override
  String get importSkippedOne => '1 ricetta saltata (nome duplicato).';

  @override
  String importSkippedMany(int count) {
    return '$count ricette saltate (nomi duplicati).';
  }

  @override
  String get importAllDuplicates =>
      'Nessuna ricetta importata — esistono già tutte.';
}
