// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Afrikaans (`af`).
class AppLocalizationsAf extends AppLocalizations {
  AppLocalizationsAf([String locale = 'af']) : super(locale);

  @override
  String get languageMenuTooltip => 'Taal';

  @override
  String get languageSystem => 'Stelsel';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageAfrikaans => 'Afrikaans';

  @override
  String get agentBackTooltip => 'Terug';

  @override
  String get agentThemeTooltip => 'Tema';

  @override
  String get agentLogOutTooltip => 'Teken uit';

  @override
  String get agoJustNow => 'net nou';

  @override
  String agoMinutes(int minutes) {
    return '$minutes min gelede';
  }

  @override
  String agoHours(int hours) {
    return '$hours uur gelede';
  }

  @override
  String agoDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dae gelede',
      one: '1 dag gelede',
    );
    return '$_temp0';
  }

  @override
  String syncSendingTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Stuur $count vasleggings…',
      one: 'Stuur 1 vaslegging…',
    );
    return '$_temp0';
  }

  @override
  String get syncSendingSubtitle => 'Werk gerus voort — jy hoef nie te wag nie';

  @override
  String syncAttentionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items het jou aandag nodig',
      one: '1 item het jou aandag nodig',
    );
    return '$_temp0';
  }

  @override
  String get syncAttentionSubtitle =>
      'Dit stuur nie vanself nie — tik om te sien';

  @override
  String syncHeldTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vasleggings wag op hierdie foon',
      one: '1 vaslegging wag op hierdie foon',
    );
    return '$_temp0';
  }

  @override
  String get syncHeldSubtitle => 'Dit stuur vanself · niks gaan verlore nie';

  @override
  String get syncAllSentTitle => 'Alles is gestuur';

  @override
  String get syncNothingWaiting => 'Niks wag nie';

  @override
  String syncLastSent(String ago) {
    return 'Laas gestuur $ago';
  }

  @override
  String get kitStepperFewer => 'Een minder';

  @override
  String get kitStepperMore => 'Een meer';

  @override
  String get captureCancelTooltip => 'Kanselleer';

  @override
  String get captureErrorChip => 'Fout';

  @override
  String captureError(String error) {
    return 'Kon nie ’n foto neem nie: $error';
  }

  @override
  String get captureButton => 'Maak kamera oop';

  @override
  String get captureGalleryButton => 'Kies uit galery';

  @override
  String photoFieldDefaultHint(String label) {
    return 'Raam die $label binne die gidslyne, van rand tot rand.';
  }

  @override
  String get photoFieldAdd => 'Voeg foto by';

  @override
  String get photoFieldCaptured => 'Vasgelê';

  @override
  String get photoFieldRetake => 'Neem weer';

  @override
  String get loginInvalidCredentials => 'Verkeerde e-pos of wagwoord';

  @override
  String get loginBackTooltip => 'Terug na welkom';

  @override
  String get loginKicker => 'WELKOM TERUG';

  @override
  String get loginSignIn => 'Teken in';

  @override
  String get loginSubtitle => 'Gebruik jou TradeIQ-werkrekening.';

  @override
  String get loginEmailLabel => 'E-pos';

  @override
  String get loginEmailHint => 'jy@maatskappy.com';

  @override
  String get loginEmailRequired => 'E-pos is verpligtend';

  @override
  String get loginPasswordLabel => 'Wagwoord';

  @override
  String get loginPasswordHint => 'Tik jou wagwoord in';

  @override
  String get loginShowPassword => 'Wys wagwoord';

  @override
  String get loginHidePassword => 'Versteek wagwoord';

  @override
  String get loginPasswordRequired => 'Wagwoord is verpligtend';

  @override
  String get loginRememberMe => 'Onthou my';

  @override
  String get loginForgotPassword => 'Wagwoord vergeet?';

  @override
  String get loginPasswordResetUnavailable =>
      'Wagwoordherstel is nog nie beskikbaar nie.';

  @override
  String get todayTitle => 'Vandag';

  @override
  String get todayLoadErrorTitle => 'Kon nie jou roete laai nie';

  @override
  String get todayLoadErrorDetail => 'Jy kan steeds self ’n besoek begin.';

  @override
  String get todayNoRouteTitle => 'Geen roete vir vandag beplan nie';

  @override
  String get todayNoPlanDetail =>
      'Geen roeteplan vir vandag nie. Jy kan steeds self ’n winkel kies.';

  @override
  String get todayEmptyPlanDetail =>
      'Vandag se roeteplan het nog geen stoppe nie.';

  @override
  String get todayYourRouteHeading => 'Jou roete';

  @override
  String get todayVisitAnotherStore =>
      'Besoek ’n winkel wat nie op my roete is nie';

  @override
  String todayStoresOfTotal(int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: ' van $total winkels',
      one: ' van 1 winkel',
    );
    return '$_temp0';
  }

  @override
  String todayStoresLeft(int count) {
    return '$count oor';
  }

  @override
  String get todayRouteDone => 'Roete klaar';

  @override
  String get todayDistancesOff =>
      'Afstande word nie gewys nie — hierdie foon sê nie waar dit is nie.';

  @override
  String get todayStopDoneTag => 'KLAAR';

  @override
  String get todayStopNextTag => 'VOLGENDE';

  @override
  String get todayPickStore => 'Kies ’n winkel om te besoek';

  @override
  String get todayNextUpHeading => 'Volgende stop';

  @override
  String get todayRestOfDayHeading => 'Die res van die dag';

  @override
  String get todayStoresRingLabel => 'Winkels';

  @override
  String todayStopNumber(String number) {
    return 'Stop $number';
  }

  @override
  String get todayCheckInHere => 'Meld hier aan';

  @override
  String get pickerTitle => 'Kies ’n winkel';

  @override
  String get pickerSubtitle => 'Tik op ’n winkel om ’n besoek te begin';

  @override
  String get pickerAddStore => 'Voeg ’n winkel by';

  @override
  String get pickerScopeMine => 'My gebiede';

  @override
  String get pickerScopeAll => 'Alle winkels';

  @override
  String pickerScopeMineSummary(int count) {
    return '$count in jou gebiede · tik op Alle winkels om elke winkel te sien';
  }

  @override
  String pickerScopeAllSummary(int count) {
    return 'Al $count winkels vir hierdie kliënt';
  }

  @override
  String get pickerLoadErrorTitle => 'Kon nie jou winkels laai nie';

  @override
  String get pickerRetry => 'Probeer weer';

  @override
  String get myWorkTitle => 'My werk';

  @override
  String get myWorkSubtitle => 'Alles wat jy vasgelê het';

  @override
  String get myWorkSyncNow => 'Probeer nou stuur';

  @override
  String get myWorkLoadErrorTitle => 'Kon nie jou werk lees nie';

  @override
  String get myWorkNeedsYouHeading => 'Het jou nodig';

  @override
  String get myWorkWaitingHeading => 'Wag om gestuur te word';

  @override
  String get myWorkSentHeading => 'Gestuur';

  @override
  String get myWorkEmpty => 'Nog niks vasgelê nie';

  @override
  String get myWorkFooter =>
      'Vasleggings stuur vanself wanneer jy sein het. Niks gaan verlore nie.';

  @override
  String myWorkSendingTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Stuur $count items…',
      one: 'Stuur 1 item…',
    );
    return '$_temp0';
  }

  @override
  String get myWorkSendingSubtitle => 'Jy hoef nie hiervoor te wag nie';

  @override
  String myWorkFailedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items sal nie stuur nie',
      one: '1 item sal nie stuur nie',
    );
    return '$_temp0';
  }

  @override
  String get myWorkFailedSubtitle => 'Alles anders is veilig';

  @override
  String myWorkHeldTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items wag op hierdie foon',
      one: '1 item wag op hierdie foon',
    );
    return '$_temp0';
  }

  @override
  String get myWorkHeldSubtitle => 'Dit stuur vanself';

  @override
  String get myWorkStateSent => 'Gestuur';

  @override
  String get myWorkStateFailed => 'Misluk';

  @override
  String get myWorkStateWaiting => 'Wag';

  @override
  String get syncErrorWaitingForVisit => 'Wag dat die besoek eers gestuur word';

  @override
  String get syncErrorNoConnection => 'Geen verbinding nie';

  @override
  String get syncErrorSignedOut => 'Uitgeteken — teken weer in';

  @override
  String get syncErrorTooLarge => 'Te groot om te stuur';

  @override
  String get syncErrorServerProblem => 'Bedienerprobleem — sal weer probeer';

  @override
  String syncErrorRejected(int status) {
    return 'Deur die bediener geweier ($status)';
  }

  @override
  String get syncErrorCouldNotSend => 'Kon nie stuur nie';

  @override
  String get syncItemCheckIn => 'Aanmelding';

  @override
  String get syncItemSubmittedVisit => 'Ingediende besoek';

  @override
  String get syncItemStockCount => 'Voorraadtelling';

  @override
  String get syncItemVisibility => 'Sigbaarheid & uitstalling';

  @override
  String get syncItemPricing => 'Pryse';

  @override
  String get syncItemCompetitive => 'Mededinging';

  @override
  String get syncItemCapability => 'Spanvermoë';

  @override
  String get syncItemRisks => 'Risiko’s';

  @override
  String get syncItemActionPlan => 'Aksieplan';

  @override
  String get syncItemScore => 'Telling';

  @override
  String get syncItemPhoto => 'Foto';

  @override
  String get syncItemOrder => 'Bestelling';

  @override
  String get visitStartingTitle => 'Besoek begin';

  @override
  String get visitTitle => 'Besoek';

  @override
  String visitOutletLoadFailed(String error) {
    return 'Kon nie die winkel laai nie: $error';
  }

  @override
  String get visitOutletNotFound => 'Winkel nie gevind nie';

  @override
  String visitReadFailed(String error) {
    return 'Kon nie hierdie besoek lees nie: $error';
  }

  @override
  String get visitInStoreJustNow => 'Net nou aangemeld';

  @override
  String visitInStoreMinutes(int minutes) {
    return '$minutes min in die winkel';
  }

  @override
  String visitInStoreHours(int hours) {
    return '${hours}h in die winkel';
  }

  @override
  String visitInStoreDays(int days) {
    return '${days}d in die winkel';
  }

  @override
  String get visitAuditHeading => 'Die oudit';

  @override
  String get visitAnyOrderHint =>
      'Enige volgorde. Alles stoor soos jy gaan, selfs sonder sein.';

  @override
  String visitFinishToSubmit(String sections) {
    return 'Voltooi $sections om in te dien';
  }

  @override
  String visitSectionsAnd(String first, String second) {
    return '$first en $second';
  }

  @override
  String get visitSubmitButton => 'Dien besoek in';

  @override
  String get visitSectionSavesAsYouGo => 'Stoor soos jy gaan';

  @override
  String get visitSectionDoneBack => 'Klaar · terug na besoek';

  @override
  String visitProgressOfSections(int total) {
    return ' van $total afdelings';
  }

  @override
  String get visitReadyToSubmit => 'Gereed om in te dien';

  @override
  String visitStillRequired(int count) {
    return 'Nog $count verpligtend';
  }

  @override
  String get visitSectionsCaptured => 'Afdelings vasgelê';

  @override
  String get visitScoreCalculatedOnSubmit => 'Word bereken wanneer jy indien';

  @override
  String get visitSectionNotStarted => 'Nie begin nie';

  @override
  String get visitSectionOptional => 'Opsioneel';

  @override
  String get visitRequiredToSubmitBadge => 'VERPLIGTEND OM IN TE DIEN';

  @override
  String get visitRequiredToSubmit => 'Verpligtend om in te dien';

  @override
  String get visitRequiredShort => 'NODIG';

  @override
  String get visitSectionOutletInfo => 'Winkelinligting';

  @override
  String get visitSectionStock => 'Voorraad & beskikbaarheid';

  @override
  String get visitSectionVisibility => 'Sigbaarheid & uitstalling';

  @override
  String get visitSectionPricing => 'Pryse & promosies';

  @override
  String get visitSectionCompetitive => 'Mededinging';

  @override
  String get visitSectionCapability => 'Spanvermoë';

  @override
  String get visitSectionRisks => 'Risiko’s';

  @override
  String get visitSectionActionPlan => 'Aksieplan';

  @override
  String get visitSectionScore => 'Telling';

  @override
  String get visitCheckInFinding => 'Soek jou…';

  @override
  String get visitCheckInWithinHint =>
      'Meld aan binne 50 m van die winkel. Dit bewys die besoek het plaasgevind.';

  @override
  String get visitRetry => 'Probeer weer';

  @override
  String get visitBackToRoute => 'Terug na roete';

  @override
  String get visitTooFarTitle => 'Jy’s te ver weg';

  @override
  String get visitTooFarBody =>
      'Gaan nader en probeer weer. Niks is verlore nie — die besoek het nog nie begin nie.';

  @override
  String visitTooFarDistance(int meters) {
    return '$meters m weg · moet 50 m of nader wees';
  }

  @override
  String get visitTooFarFraudNote =>
      'Hierdie poging word aangeteken. Om van ver af weer te probeer is self ’n bedrogsein — stap eerder nader.';

  @override
  String get visitNoLocationTitle => 'Kan nie jou ligging kry nie';

  @override
  String get visitCheckInFailedTitle => 'Kon nie die besoek begin nie';

  @override
  String get visitCheckInFailedNothingLost =>
      'Niks is verlore nie — die besoek het nog nie begin nie.';

  @override
  String submitSubtitleInStore(String outlet, int minutes) {
    return '$outlet · $minutes min in die winkel';
  }

  @override
  String get submitOfflineNote =>
      'Geen sein nie? Jy kan steeds indien — dit stoor op die foon en stuur vanself.';

  @override
  String get submitIntro =>
      'Kyk dit na voordat dit na jou bestuurder gaan — jy kan dit daarna nie verander nie.';

  @override
  String get submitWillRaiseHeading => 'Dit skep hierdie take';

  @override
  String submitAccusation(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Jy sê vir die bestuurder $count dinge is verkeerd in hierdie winkel. Dit kom uit wat jy vasgelê het — niks word bygevoeg nie. Enigiets wat reeds oop is, word nie twee keer geskep nie.',
      one:
          'Jy sê vir die bestuurder een ding is verkeerd in hierdie winkel. Dit kom uit wat jy vasgelê het — niks word bygevoeg nie. As dit reeds oop is, word dit nie twee keer geskep nie.',
    );
    return '$_temp0';
  }

  @override
  String submitSectionsComplete(int done, int total) {
    return '$done van $total afdelings voltooi';
  }

  @override
  String submitTaskForManager(String priority) {
    return 'Taak vir die bestuurder · $priority';
  }

  @override
  String submitPriority(String priority) {
    String _temp0 = intl.Intl.selectLogic(priority, {
      'critical': 'kritiek',
      'high': 'hoog',
      'normal': 'normaal',
      'low': 'laag',
      'other': '$priority',
    });
    return '$_temp0';
  }

  @override
  String get submitNothingToRaise =>
      'Niks om te skep nie. Niks uit voorraad, geen risiko’s nie — hierdie winkel is in goeie toestand.';

  @override
  String submitNotConfirmedLine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count afdelings kon nie bevestig word nie — die bestuurder word vertel',
      one: '1 afdeling kon nie bevestig word nie — die bestuurder word vertel',
    );
    return '$_temp0';
  }

  @override
  String submitCantConfirmTask(String section) {
    return '$section kon nie bevestig word nie';
  }

  @override
  String get submitCantConfirmTaskLine =>
      'Die bestuurder word vertel · nie bevestig nie';

  @override
  String submitTaskSemanticsUrgent(String title, String line) {
    return 'Dringend. $title. $line';
  }

  @override
  String submitTaskSemanticsRoutine(String title, String line) {
    return 'Roetine. $title. $line';
  }

  @override
  String submitCantConfirmSemantics(String section, String reason) {
    return 'Nie bevestig nie. $section. $reason';
  }

  @override
  String get submitPrimarySemantics =>
      'Stuur hierdie besoek aan jou bestuurder';

  @override
  String submitCapturedSemantics(int done, int total, String line) {
    return '$done van $total afdelings voltooi. $line';
  }

  @override
  String get submitNothingToRaiseHeadline => 'Niks om aan te meld nie';

  @override
  String get submitGateBack => 'Gaan terug en verander iets';

  @override
  String get outcomeTitle => 'Besoek ingedien';

  @override
  String get outcomeNextStore => 'Volgende winkel';

  @override
  String get outcomeSending => 'Jou besoek word gestuur…';

  @override
  String get outcomeHeldTitle => 'Jou besoek is veilig op hierdie foon';

  @override
  String get outcomeHeldBodyUnreachable =>
      'Kon nie die bediener bereik nie. Dit stuur vanself sodra jy weer sein het — jy kan die app toemaak.';

  @override
  String get outcomeHeldBodyNoSignal =>
      'Geen sein nie. Dit stuur vanself sodra jy weer sein het — jy kan die app toemaak.';

  @override
  String get outcomeScoredWhenSends => 'Word getel sodra dit stuur';

  @override
  String get outcomeScoredOnServer =>
      'Word op die bediener uitgewerk, nie op die foon nie';

  @override
  String get outcomeNoGuess =>
      'Jou regte telling — die een wat jou bestuurder sien — verskyn sodra dit die bediener bereik.';

  @override
  String ratingBand(String band) {
    String _temp0 = intl.Intl.selectLogic(band, {
      'green': 'Gesond',
      'amber': 'Dophou',
      'other': 'Gaping',
    });
    return '$_temp0';
  }

  @override
  String outcomeDeltaSame(int previous) {
    return 'Dieselfde as jou vorige besoek hier ($previous).';
  }

  @override
  String outcomeDeltaUp(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count punte hoër',
      one: '1 punt hoër',
    );
    return '$_temp0';
  }

  @override
  String outcomeDeltaDown(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count punte laer',
      one: '1 punt laer',
    );
    return '$_temp0';
  }

  @override
  String outcomeDeltaFromLast(int previous) {
    return 'as jou vorige besoek hier ($previous).';
  }

  @override
  String get outcomeHowScored => 'Hoe dit getel is';

  @override
  String get outcomePerfectStoreScore => 'Perfekte-winkel-telling';

  @override
  String get outcomeDimensionAvailability => 'Beskikbaarheid';

  @override
  String get outcomeDimensionVisibility => 'Sigbaarheid';

  @override
  String get outcomeDimensionDisplay => 'Uitstalling';

  @override
  String get outcomeDimensionPricing => 'Pryse';

  @override
  String get outcomeDimensionCompetitive => 'Rakaandeel';

  @override
  String get outcomeDimensionSalesCapability => 'Spanvermoë';

  @override
  String get outcomeUnmeasurableCompetitive =>
      'Geen mededinger op die rak nie — dit tel nie teen jou nie.';

  @override
  String get outcomeUnmeasurableSalesCapability =>
      'Geen personeel aan diens nie — dit tel nie teen jou nie.';

  @override
  String get s1Title => 'Winkel-aanmelding';

  @override
  String get s1ConfirmedAtCheckin => 'Bevestig by aanmelding';

  @override
  String get s1CheckedIn => 'Aangemeld';

  @override
  String get s1NotRecorded => 'Nie aangeteken nie';

  @override
  String get s1Geofence => 'Geoheining';

  @override
  String get s1Passed => 'Geslaag';

  @override
  String s2LoadFailed(String error) {
    return 'Kon nie SKU’s laai nie: $error';
  }

  @override
  String get s2NoSkus => 'Geen SKU’s is vir hierdie kliënt opgestel nie.';

  @override
  String s2ContextSelling(String velocity) {
    return 'Verkoop ~$velocity/dag';
  }

  @override
  String s2ContextSellingOutOfStock(String velocity, int days) {
    return 'Verkoop ~$velocity/dag · uit voorraad ${days}d';
  }

  @override
  String get s2ContextNoHistory => 'Nog geen verkoopgeskiedenis nie';

  @override
  String s2ContextNoHistoryOutOfStock(int days) {
    return 'Nog geen verkoopgeskiedenis nie · uit voorraad ${days}d';
  }

  @override
  String s2Rrp(String price) {
    return 'AKP $price';
  }

  @override
  String get s2OutOfStockRaisesTask =>
      'Uit voorraad — dit skep ’n taak vir die bestuurder';

  @override
  String get s2ShoppersSwitch =>
      '70% van kopers kies ’n ander handelsmerk as die produk ontbreek.';

  @override
  String get s2SaveStock => 'Stoor voorraad';

  @override
  String get s2StockSaved => 'Voorraad gestoor — wag om gestuur te word';

  @override
  String get s2UnitsOnShelf => 'Eenhede op die rak';

  @override
  String get s2Cancel => 'Kanselleer';

  @override
  String get s2Set => 'Stel';

  @override
  String get s10ComputeFailed =>
      'Kon nie die telkaart bereken nie. Probeer herlaai.';

  @override
  String get s10DimensionScores => 'Tellings per dimensie';

  @override
  String get s10WeightedTotal => 'Geweegde totaal';

  @override
  String get s10Finalize => 'Finaliseer telkaart';

  @override
  String get s10Refresh => 'Herlaai';

  @override
  String get s10Queued => 'Telkaart wag om gestuur te word';

  @override
  String get s10DimensionAvailability => 'Beskikbaarheid';

  @override
  String get s10DimensionVisibility => 'Sigbaarheid';

  @override
  String get s10DimensionDisplay => 'Uitstalling';

  @override
  String get s10DimensionPricing => 'Pryse';

  @override
  String get s10DimensionCompetitive => 'Mededinging';

  @override
  String get s10DimensionSalesCapability => 'Verkoopvermoë';

  @override
  String get s34BrandingPoster => 'Plakkaat';

  @override
  String get s34BrandingShelfStrip => 'Rakstrook';

  @override
  String get s34BrandingWobbler => 'Wiebelkaart';

  @override
  String get s34BrandingLabel => 'Handelsmerk-elemente teenwoordig';

  @override
  String get s34PlanogramLabel => 'Planogram-nakoming %';

  @override
  String get s34FacingsLabel => 'Aantal fronte';

  @override
  String get s34CleanlinessLabel => 'Netheidstelling';

  @override
  String get s34HighTrafficLabel => 'Ligging met baie voetverkeer';

  @override
  String get s34PhotoLabel => 'Rakfoto';

  @override
  String get s34PhotoHelper =>
      'Opsioneel. Bewys vir hierdie afdeling, en oefendata vir outomatiese uitstaltelling.';

  @override
  String get s34SaveButton => 'Stoor sigbaarheid';

  @override
  String get s34Saved => 'Sigbaarheid gestoor — wag om gestuur te word';

  @override
  String s5LoadError(String error) {
    return 'Kon nie SKU’s laai nie: $error';
  }

  @override
  String get s5NoSkus => 'Geen SKU’s is vir hierdie kliënt opgestel nie.';

  @override
  String get s5ActualPriceLabel => 'Werklike prys';

  @override
  String get s5PromoActiveLabel => 'Promosie aktief';

  @override
  String get s5CommsRatingLabel => 'Kommunikasie-gradering (1-5)';

  @override
  String get s5PhotoLabel => 'Rakprysfoto';

  @override
  String get s5PhotoHelper =>
      'Opsioneel. Bewys vir die pryse wat jy ingevoer het, en oefendata vir outomatiese pryslees.';

  @override
  String get s5SaveButton => 'Stoor pryse';

  @override
  String get s5Saved => 'Pryse gestoor — wag om gestuur te word';

  @override
  String s6CompetitorTitle(int number) {
    return 'Mededinger $number';
  }

  @override
  String get s6SkuLabel => 'Mededinger-SKU';

  @override
  String get s6SkuHint => 'Wat die mededinger verkoop';

  @override
  String get s6PriceLabel => 'Mededinger se prys';

  @override
  String get s6PosmLabel => 'Soort POSM';

  @override
  String get s6PosmHint => 'Plakkaat, wiebelkaart, gondola…';

  @override
  String get s6FacingsLabel => 'Fronte op die rak';

  @override
  String get s6FacingsHelp => 'Hoeveel rakspasie hierdie mededinger het';

  @override
  String get s6PromoterLabel => 'Promotor teenwoordig';

  @override
  String get s6AddButton => 'Voeg mededinger by';

  @override
  String get s6SaveButton => 'Stoor mededinging';

  @override
  String get s6Saved => 'Mededingerinligting gestoor — wag om gestuur te word';

  @override
  String get s7TrainingProductKnowledge => 'Produkkennis';

  @override
  String get s7TrainingMerchandising => 'Uitstalwerk';

  @override
  String get s7TrainingPosSystems => 'POS-stelsels';

  @override
  String get s7HeadcountLabel => 'Aantal personeel bevestig';

  @override
  String get s7HeadcountHint => 'Verteenwoordigers op die vloer';

  @override
  String get s7TrainingLabel => 'Opleiding van verteenwoordigers voltooi';

  @override
  String get s7QuizLabel => 'Vasvratelling (0-100)';

  @override
  String get s7SaveButton => 'Stoor vermoë';

  @override
  String get s7Saved => 'Vermoë gestoor — wag om gestuur te word';

  @override
  String get s8SeverityCritical => 'Kritiek';

  @override
  String get s8SeverityHigh => 'Hoog';

  @override
  String get s8SeverityNormal => 'Normaal';

  @override
  String s8RiskTitle(int number) {
    return 'Risiko $number';
  }

  @override
  String get s8FlagTypeLabel => 'Soort vlag';

  @override
  String get s8FlagTypeHint => 'Wat gemerk is';

  @override
  String get s8SeverityLabel => 'Erns';

  @override
  String get s8NoteLabel => 'Nota';

  @override
  String get s8NoteHint => 'Opsionele besonderhede';

  @override
  String get s8AddButton => 'Merk ’n risiko';

  @override
  String get s8SaveButton => 'Stoor risiko’s';

  @override
  String get s8Saved =>
      'Risiko’s gestoor — wag om gestuur te word; opvolgtake word outomaties geskep';

  @override
  String s8SeverityNote(String severity) {
    String _temp0 = intl.Intl.selectLogic(severity, {
      'critical':
          'Kritieke risiko — as jy dit stoor, word ’n opvolgtaak geskep',
      'other': 'Hoë risiko — as jy dit stoor, word ’n opvolgtaak geskep',
    });
    return '$_temp0';
  }

  @override
  String get s9PriorityCritical => 'Kritiek';

  @override
  String get s9PriorityHigh => 'Hoog';

  @override
  String get s9PriorityNormal => 'Normaal';

  @override
  String get s9Intro =>
      'Risiko’s wat in S8 gemerk is, skep outomaties take met ’n SLA. Voeg ekstra take hieronder by.';

  @override
  String get s9FindingTypeLabel => 'Soort bevinding';

  @override
  String get s9FindingTypeHint => 'Wat reggemaak moet word';

  @override
  String get s9RequiredFixLabel => 'Nodige regstelling';

  @override
  String get s9RequiredFixHint => 'Die regstellende aksie';

  @override
  String get s9PriorityLabel => 'Prioriteit';

  @override
  String get s9AddButton => 'Voeg taak by';

  @override
  String get s9Saved => 'Taak wag om gestuur te word';

  @override
  String get errorSessionExpired =>
      'Jou sessie het verval. Teken asseblief weer in.';

  @override
  String get errorUnreachable =>
      'Kon nie die bediener bereik nie. Kyk of jy verbinding het en probeer weer.';

  @override
  String get errorGeneric => 'Iets het fout gegaan. Probeer asseblief weer.';

  @override
  String get checkInLocationPermissionDenied =>
      'Toestemming vir ligging is geweier';

  @override
  String get checkInLocationServicesDisabled => 'Liggingdienste is afgeskakel';

  @override
  String get checkInLocationTimedOut =>
      'Dit het te lank geneem. Maak seker ligging is aan vir TradeIQ, en probeer weer.';

  @override
  String checkInLocationFailed(String error) {
    return 'Kon nie jou huidige ligging kry nie: $error';
  }

  @override
  String get progressConfirmedAtCheckIn => 'Bevestig by aanmelding';

  @override
  String progressSkusOfTotal(int items, int total) {
    return '$items van $total SKU’s';
  }

  @override
  String progressStockCounted(int items) {
    return '$items SKU’s getel';
  }

  @override
  String progressStockOutOfStock(int items, int outOfStock) {
    return '$items SKU’s · $outOfStock uit voorraad';
  }

  @override
  String progressSkusPriced(int items) {
    return '$items SKU’s geprys';
  }

  @override
  String get progressNoCompetitors => 'Geen op die rak nie';

  @override
  String progressCompetitors(int items) {
    String _temp0 = intl.Intl.pluralLogic(
      items,
      locale: localeName,
      other: '$items mededingers',
      one: '1 mededinger',
    );
    return '$_temp0';
  }

  @override
  String get progressCaptured => 'Vasgelê';

  @override
  String get progressNoRisks => 'Geen gemerk nie';

  @override
  String progressRisksRaised(int items) {
    return '$items gemerk';
  }

  @override
  String taskStockoutTitle(String sku) {
    return '$sku is uit voorraad';
  }

  @override
  String get taskStockoutTitleUnnamed => 'Hierdie SKU is uit voorraad';

  @override
  String get taskStockoutReason => 'Jy het nul op die rak getel';

  @override
  String taskRiskTitle(String flagType) {
    return '$flagType gemerk';
  }

  @override
  String get taskRiskTitleUntyped => 'Risiko gemerk';

  @override
  String taskRiskReason(String flagType) {
    return 'Risiko wat jy gemerk het · $flagType';
  }

  @override
  String get taskRiskReasonUntyped => 'Risiko wat jy gemerk het';

  @override
  String get taskActionPlanTitleUntitled => 'Aksie waarvoor jy gevra het';

  @override
  String get taskActionPlanReason => 'Aksieplan wat jy geskryf het';

  @override
  String reviewSkusCounted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count SKU’s getel',
      one: '1 SKU getel',
    );
    return '$_temp0';
  }

  @override
  String reviewCompetitors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mededingers',
      one: '1 mededinger',
    );
    return '$_temp0';
  }

  @override
  String reviewPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count foto’s',
      one: '1 foto',
    );
    return '$_temp0';
  }

  @override
  String get visitTemplateSectionKicker => 'Kliëntvrae';

  @override
  String visitTemplateTileDetail(String detail) {
    return 'Kliëntvrae · $detail';
  }

  @override
  String get visitTemplateSectionIntro =>
      'Word by elke besoek gevra. Beantwoord die verpligte vrae om in te dien.';

  @override
  String visitTemplateProgressAnswered(int answered, int total) {
    return '$answered van $total beantwoord';
  }

  @override
  String visitTemplateRequiredLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Nog $count verpligte vrae',
      one: 'Nog 1 verpligte vraag',
    );
    return '$_temp0';
  }

  @override
  String get visitTemplateAllRequiredAnswered =>
      'Alle verpligte vrae beantwoord';

  @override
  String get visitTemplateFieldRequired => 'Verpligtend';

  @override
  String get visitTemplateFieldRequiredError => 'Beantwoord dit voor jy indien';

  @override
  String get visitTemplateSave => 'Stoor antwoorde';

  @override
  String get visitTemplateSaved => 'Antwoorde gestoor — wag om gestuur te word';

  @override
  String get visitTemplatePhotoUnsupported =>
      'Fotovrae kan nog nie in die app beantwoord word nie';

  @override
  String get visitTemplateNoQuestions =>
      'Hierdie kliënt se sjabloon het nog geen vrae nie';

  @override
  String get locationNoticeTitle =>
      'Jou ligging word met jou bestuurder gedeel';

  @override
  String locationNoticeBody(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'elke $minutes minute',
      one: 'elke minuut',
    );
    return 'Jou bestuurder kan sien by watter winkel jy is.\n\nTerwyl TradeIQ oop is en jy ingeteken is, stuur dit $_temp0 jou ligging. As jy TradeIQ toemaak of uitteken, stop dit. Niks word in die agtergrond gestuur nie.';
  }

  @override
  String get locationNoticeAcknowledge => 'Ek verstaan, deel my ligging';

  @override
  String get locationNoticeDecline => 'Moenie deel nie';

  @override
  String get locationSharingActiveTitle =>
      'Jou ligging word met jou bestuurder gedeel';

  @override
  String get locationSharingActiveSubtitle =>
      'Net terwyl TradeIQ oop is · tik om te stop';

  @override
  String get locationSharingNoFixSubtitle =>
      'Dit is aan, maar hierdie foon gee nie vir TradeIQ ’n ligging nie';

  @override
  String get locationSharingOffTitle => 'Jou ligging word nie gedeel nie';

  @override
  String get locationSharingOffSubtitle => 'Tik om dit te verander';

  @override
  String get locationStopTitle => 'Hou op om jou ligging te deel?';

  @override
  String get locationStopBody =>
      'Jou bestuurder sal nie meer kan sien waar jy is nie. Jy kan dit later weer aanskakel.';

  @override
  String get locationStopConfirm => 'Hou op deel';

  @override
  String get locationStopCancel => 'Bly deel';

  @override
  String get backgroundLocationNoticeTitle =>
      'Ons teken jou roete tussen winkels aan';

  @override
  String backgroundLocationNoticeBody(int minutes, String start, String end) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'elke $minutes minute',
      one: 'elke minuut',
    );
    return 'Apart van die deel terwyl TradeIQ oop is, en jy mag nee sê.\n\nTradeIQ teken $_temp0 aan waar jy is, selfs wanneer dit toe is, sodat jou bestuurder jou roete tussen winkels kan sien. Net op werksdae $start–$end — nooit snags of oor naweke nie. ’n Kennisgewing bly die hele tyd op jou foon. Jy kan dit enige tyd afskakel; dit stop nie die deel waartoe jy reeds ingestem het nie.';
  }

  @override
  String get backgroundLocationNoticeAccept => 'Skakel roete-aantekening aan';

  @override
  String get backgroundLocationNoticeDecline =>
      'Nee, moenie my roete aanteken nie';

  @override
  String get backgroundLocationOfferTitle => 'Roete-aantekening is af';

  @override
  String get backgroundLocationOfferSubtitle => 'Tik om te sien wat dit doen';

  @override
  String get backgroundLocationActiveTitle =>
      'Ons teken jou roete tussen winkels aan';

  @override
  String get backgroundLocationActiveSubtitle =>
      'Net werksure · tik om te stop';

  @override
  String get backgroundLocationOutsideHoursTitle =>
      'Roete-aantekening is onderbreek';

  @override
  String backgroundLocationOutsideHoursSubtitle(String start) {
    return 'Dit begin weer op ’n werksdag om $start';
  }

  @override
  String get backgroundLocationPermissionTitle =>
      'Android het nog een toestemming nodig';

  @override
  String get backgroundLocationPermissionBody =>
      'Kies “Laat altyd toe” vir ligging op TradeIQ se instellingsblad.\n\nDit laat TradeIQ jou roete aanteken wanneer dit toe is. Alles anders werk steeds as jy liewer nie wil nie.';

  @override
  String get backgroundLocationPermissionOpenSettings =>
      'Maak TradeIQ se instellings oop';

  @override
  String get backgroundLocationPermissionNotNow => 'Nie nou nie';

  @override
  String get backgroundLocationStopTitle => 'Hou op om jou roete aan te teken?';

  @override
  String get backgroundLocationStopBody =>
      'Jou bestuurder sal nie meer jou roete tussen winkels sien nie.\n\nDie deel van jou ligging terwyl TradeIQ oop is, word nie geraak nie.';

  @override
  String get backgroundLocationStopConfirm => 'Stop roete-aantekening';

  @override
  String get backgroundLocationStopCancel => 'Hou aan aanteken';

  @override
  String get backgroundLocationNotificationTitle =>
      'TradeIQ teken jou roete aan';

  @override
  String get backgroundLocationNotificationBody =>
      'Net werksure. Skakel dit in TradeIQ af.';

  @override
  String get backgroundLocationNotificationChannel => 'Roete-aantekening';

  @override
  String get contestsTitle => 'Kompetisies';

  @override
  String get contestsSubtitle => 'Verdien punte, klim op die ranglys';

  @override
  String get contestsActiveHeading => 'Loop nou';

  @override
  String get contestsEndedHeading => 'Onlangs afgeloop';

  @override
  String contestDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Nog $count dae',
      one: 'Nog 1 dag',
    );
    return '$_temp0';
  }

  @override
  String get contestEnded => 'Afgeloop';

  @override
  String contestDateRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String get contestPrizeLabel => 'Prys';

  @override
  String get contestCountsLabel => 'Wat tel';

  @override
  String get contestEventAll => 'Alle punte';

  @override
  String get contestEventVisitSubmitted => 'Ingediende besoeke';

  @override
  String get contestEventTaskClosed => 'Afgehandelde take';

  @override
  String get contestEventScorecard => 'Telkaarte';

  @override
  String contestYourRank(int rank, int total) {
    return 'Jou posisie: $rank van $total';
  }

  @override
  String contestPoints(String points) {
    return '$points punte';
  }

  @override
  String get contestNotRanked =>
      'Jy is nie op hierdie kompetisie se ranglys nie';

  @override
  String get contestStandingsHeading => 'Ranglys';

  @override
  String get contestYouTag => 'Jy';

  @override
  String get contestsEmptyTitle => 'Tans geen kompetisies nie';

  @override
  String get contestsEmptyBody =>
      'Wanneer jou bestuurder ’n kompetisie begin, verskyn dit hier.';

  @override
  String get contestsLoadError => 'Kon nie kompetisies laai nie';

  @override
  String get contestsRetry => 'Probeer weer';

  @override
  String contestsRunningHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kompetisies loop nou',
      one: '1 kompetisie loop nou',
    );
    return '$_temp0';
  }

  @override
  String get agentNotificationsTooltip => 'Kennisgewings';

  @override
  String get notificationsTitle => 'Kennisgewings';

  @override
  String get notificationsSubtitle => 'Kies wat na hierdie foon kom';

  @override
  String get notificationsTasksLabel => 'Take wat aan jou toegewys is';

  @override
  String get notificationsTasksHelp =>
      'Wanneer jou bestuurder vir jou ’n taak gee';

  @override
  String get notificationsMessagesLabel => 'Boodskappe en aankondigings';

  @override
  String get notificationsMessagesHelp =>
      'Boodskappe aan jou of die span, en aankondigings';

  @override
  String get notificationsSlaLabel => 'Agterstallige take';

  @override
  String get notificationsSlaHelp =>
      'Wanneer een van jou take sy sperdatum oorskry';

  @override
  String get notificationsNotSetUpTitle =>
      'Kennisgewings is nog nie aangeskakel nie';

  @override
  String get notificationsNotSetUpBody =>
      'Jou keuses word gestoor en geld sodra dit aangeskakel is.';

  @override
  String get notificationsLoadErrorTitle =>
      'Kon nie jou kennisgewing-instellings laai nie';

  @override
  String get notificationsRetry => 'Probeer weer';

  @override
  String get notificationsSaveFailed =>
      'Kon dit nie stoor nie. Kyk of jy verbinding het en probeer weer.';

  @override
  String get notificationsFooter =>
      'Jy kan dit ook in jou foon se instellings afskakel.';

  @override
  String get navToday => 'Vandag';

  @override
  String get navMyWork => 'Jou werk';

  @override
  String get navMap => 'Kaart';

  @override
  String get navMe => 'Ek';

  @override
  String get todayRouteEyebrow => 'Roete';

  @override
  String get todayStopUpcoming => 'Om te doen';

  @override
  String get unitMetres => 'm';

  @override
  String get unitKilometres => 'km';

  @override
  String get skinDay => 'Dag';

  @override
  String get skinNight => 'Nag';

  @override
  String get skinVeld => 'Veld, die buitelug-skerm met hoë kontras';

  @override
  String get syncChipAllSent => 'Alles gestuur';

  @override
  String get syncChipAllSentSemantics =>
      'Al jou werk is gestuur. Dubbeltik om dit te sien.';

  @override
  String get visitClientQuestions => 'Die kliënt se vrae';

  @override
  String get visitReadFailedTitle => 'Hierdie besoek kon nie gelees word nie.';

  @override
  String get visitReadFailedBlock =>
      'Die besoek se eie vordering kon nie gelees word nie, so dit kan nog nie gestuur word nie.';

  @override
  String get visitCantConfirmProducts =>
      'Die produklys het nie gelaai nie — hierdie afdeling kan nie bevestig word nie.';

  @override
  String get visitCantConfirmTemplate =>
      'Die kliënt se vrae het nie gelaai nie — hierdie afdeling kan nie bevestig word nie.';

  @override
  String get visitCheckInEyebrow => 'Inklok';

  @override
  String get visitTooFarAttemptsRecorded =>
      'Elke poging word aangeteken saam met waar jy was.';

  @override
  String get visitTooFarClose =>
      'Jy is naby. Probeer tot by die voordeur stap.';

  @override
  String get visitTooFarWrongStore =>
      'Dit lyk na die verkeerde winkel, of die winkel se speld is verkeerd.';

  @override
  String get visitPinIsWrong => 'Die speld is verkeerd';

  @override
  String get visitPinReportedHeld =>
      'Op hierdie foon aangeteken. Dit is nog nêrens gestuur nie — daar is nêrens om dit heen te stuur nie.';

  @override
  String get visitNoGpsFixPermission =>
      'Laat ligging vir TradeIQ toe in jou foon se instellings. Jy kan dit net toelaat terwyl jy die program gebruik.';

  @override
  String get visitNoGpsFixServices =>
      'Skakel ligging aan in jou foon se instellings en probeer weer.';

  @override
  String get visitNoGpsFixTimedOut =>
      'Stap buitentoe of na ’n venster en probeer weer. Jou GPS werk steeds in vliegtuigmodus — gee dit ’n paar sekondes.';

  @override
  String get visitNoGpsFixGeneric =>
      'Stap buitentoe of na ’n venster en probeer weer.';

  @override
  String get visitCopyCode => 'Kopieer';

  @override
  String get visitCopyCodeSemantics => 'Kopieer die foutkode';

  @override
  String todayRouteSemantics(int done, int total, int left) {
    return 'Roete: $done van $total winkels klaar, $left oor.';
  }

  @override
  String todayStopSemantics(String name, String code, String state) {
    return '$name, $code, $state. Dubbeltik om hier in te klok.';
  }

  @override
  String todayDistanceMetresSemantics(int meters) {
    return '$meters meter ver';
  }

  @override
  String todayDistanceKmSemantics(num km) {
    return '$km kilometer ver';
  }

  @override
  String skinCycleLabel(String current, String next) {
    return 'Skerm: $current. Dubbeltik vir $next.';
  }

  @override
  String visitReadinessSemantics(int done, int total, int blocking) {
    return 'Vasgelê, $done van $total. $blocking afdelings word nog benodig.';
  }

  @override
  String visitScoreSemantics(String name) {
    return '$name, nog nie beskikbaar nie. Word uitgewerk wanneer die besoek stuur.';
  }

  @override
  String visitSectionSemantics(String name, String state, String detail) {
    return '$name. $state. $detail';
  }

  @override
  String visitTooFarNeedWithin(int meters) {
    return 'Jy moet binne 50 m wees. Jy is nou $meters m ver.';
  }

  @override
  String visitTooFarSemantics(int meters) {
    return 'Te ver van die winkel. Jy is $meters meter ver. Jy moet binne 50 meter wees.';
  }

  @override
  String visitErrorCodeSemantics(String code) {
    return 'Foutkode $code';
  }

  @override
  String syncChipHeld(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count op hierdie foon gehou',
      one: '1 op hierdie foon gehou',
    );
    return '$_temp0';
  }

  @override
  String syncChipHeldSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count vasleggings op hierdie foon gehou. Dubbeltik om jou werk te sien.',
      one: '1 vaslegging op hierdie foon gehou. Dubbeltik om jou werk te sien.',
    );
    return '$_temp0';
  }

  @override
  String syncChipNeedsYou(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count het jou nodig',
      one: '1 het jou nodig',
    );
    return '$_temp0';
  }

  @override
  String syncChipNeedsYouSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Het jou nodig. $count vasleggings sal nie vanself stuur nie. Dubbeltik om jou werk te sien.',
      one:
          'Het jou nodig. 1 vaslegging sal nie vanself stuur nie. Dubbeltik om jou werk te sien.',
    );
    return '$_temp0';
  }

  @override
  String visitCantConfirmCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count afdelings kan nie bevestig word nie',
      one: '1 afdeling kan nie bevestig word nie',
    );
    return '$_temp0';
  }

  @override
  String get outcomeOpenMyWork => 'Maak my werk oop';

  @override
  String outcomeHeroSemantics(int score, String band) {
    return 'Perfekte-winkel-telling, $score uit 100. $band.';
  }

  @override
  String outcomeDimensionSemantics(String name, int value) {
    return '$name, $value uit 100.';
  }

  @override
  String outcomeDimensionUnmeasuredSemantics(String name, String reason) {
    return '$name, nie gemeet nie. $reason';
  }

  @override
  String get outcomeNotMeasuredGeneric => 'Nie in hierdie besoek gemeet nie.';

  @override
  String get outcomeFirstScored => 'Eerste getelde besoek hier.';

  @override
  String get outcomeReconciledLead => 'Nou getel';

  @override
  String get outcomeReconciledTail => '— dit was';

  @override
  String outcomeReconciledSemantics(int now, int seen) {
    return 'Nou getel $now. Dit was $seen toe jy dit gesien het.';
  }

  @override
  String get outcomeReconciledReason =>
      'Dit is weer getel nadat jy dit gesien het.';

  @override
  String get outcomeNextStoreSemantics => 'Gaan aan na die volgende winkel';

  @override
  String get outcomeHeldSemantics =>
      'Gestuur. Op hierdie foon gehou totdat jy sein het.';

  @override
  String get captureOpenCameraSemantics =>
      'Maak die kamera oop om die rak te fotografeer';

  @override
  String get captureTorchHint =>
      'Gang donker? Skakel jou foon se flitslig aan voordat jy skiet.';

  @override
  String get captureStampNote =>
      'Jou foto word gemerk met die tyd en waar jy is.';

  @override
  String get captureReviewTitle => 'Kyk na die foto';

  @override
  String get captureDarkCaption => 'Donker — neem weer?';

  @override
  String get captureDarkSemantics => 'Donker — jy wil dit dalk weer neem.';

  @override
  String get captureUseIt => 'Gebruik dit';

  @override
  String get captureNoCamera =>
      'Hierdie foon het geen kamera wat ons kan bereik nie.';

  @override
  String get captureGeotagged => 'geo-gemerk';

  @override
  String get captureNoGeotag => 'geen ligging op hierdie foto nie';

  @override
  String capturePhotoMeta(String time, String tag) {
    return '$time · $tag';
  }

  @override
  String capturePhotoSemantics(String time) {
    return 'Foto geneem $time, op hierdie foon gehou.';
  }

  @override
  String get mapTitle => 'Kaart';

  @override
  String mapStoresFact(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count winkels',
      one: '1 winkel',
    );
    return '$_temp0';
  }

  @override
  String get mapRouteHeading => 'Vandag se roete';

  @override
  String get mapRouteEmptyLine => 'Geen roete vir vandag beplan nie.';

  @override
  String get mapPatchHeading => 'Die res van jou gebied';

  @override
  String get mapStateDone => 'Vandag besoek';

  @override
  String get mapStateNext => 'Volgende';

  @override
  String get mapStatePlanned => 'Op vandag se roete';

  @override
  String get mapStateTerritory => 'In jou gebied';

  @override
  String get mapStateDisputed => 'Speld word nagegaan';

  @override
  String get mapDisputedLine =>
      'Iemand het gemeld dat hierdie speld verkeerd is, so die plek op die kaart is dalk nie die winkel nie.';

  @override
  String get mapYouAreHere => 'Jy is hier';

  @override
  String get mapLocationDenied =>
      'Ligging is af vir hierdie app, so daar is geen afstande en geen kolletjie vir waar jy is nie. Die winkels is steeds reg.';

  @override
  String get mapLocationServicesOff =>
      'Ligging is op hierdie foon afgeskakel, so daar is geen afstande en geen kolletjie vir waar jy is nie. Die winkels is steeds reg.';

  @override
  String get mapLocationNoFix =>
      'Hierdie foon kry nog nie ’n ligging nie, so daar is geen afstande en geen kolletjie vir waar jy is nie. Die winkels is steeds reg.';

  @override
  String get mapTilesOffTitle => 'Geen kaart hier nie';

  @override
  String get mapTilesOffBody =>
      'Die kaart laai nie — daar is niks om dit mee te haal nie. Jou winkels is hieronder gelys, en die lys het geen verbinding nodig nie.';

  @override
  String get mapVeldNote =>
      'Die kaart is af in helder son. Jou winkels is hieronder gelys, naaste eerste.';

  @override
  String get mapEmptyTitle => 'Nog geen winkels nie';

  @override
  String get mapEmptyBody =>
      'Daar is geen roete vir vandag nie en geen winkel in jou gebied nie. ’n Bestuurder ken albei toe.';

  @override
  String get mapLoadErrorTitle => 'Jou winkels het nie gelaai nie';

  @override
  String get mapLoadErrorDetail =>
      'Ons kon nie by die bediener uitkom nie. Jou dag werk steeds — kies ’n winkel en teken in.';

  @override
  String mapShowingNearest(int shown, int total) {
    return 'Wys die $shown naaste van $total winkels.';
  }

  @override
  String mapShowingFirst(int shown, int total) {
    return 'Wys $shown van $total winkels.';
  }

  @override
  String get mapCheckInAgain => 'Teken weer in';

  @override
  String get mapVisitedTodayLine => 'Jy het vandag hier ingeteken.';

  @override
  String mapCircleAtDoor(String name) {
    return 'Teken in by $name';
  }

  @override
  String mapPinHint(String name, String state) {
    return '$name, $state. Dubbeltik vir wat jy hier kan doen.';
  }

  @override
  String get mapLegendLabel => 'Wat die spelde beteken';

  @override
  String get sheetClose => 'Maak toe';

  @override
  String get askTitle => 'Vra TradeIQ';

  @override
  String get askHistoryAction => 'Geskiedenis';

  @override
  String askHistoryActionCount(int count) {
    return 'Geskiedenis · $count';
  }

  @override
  String get askComposerLabel => 'Vra ’n vraag';

  @override
  String get askComposerHint => 'Span, voorraad, rak, mededingers';

  @override
  String get askComposerRephrase => 'Vra weer, of stel dit anders';

  @override
  String get askSend => 'Stuur hierdie vraag';

  @override
  String get askSendUnavailable =>
      'Stuur, nie beskikbaar nie, het ’n verbinding nodig';

  @override
  String get askSendNothingTyped =>
      'Stuur, nie beskikbaar nie, nog niks getik nie';

  @override
  String get askStop => 'Stop die antwoord';

  @override
  String get askQuestionSent => 'Vraag gestuur';

  @override
  String get askYourQuestion => 'Jou vraag';

  @override
  String get askEmptyHeadline => 'Vra oor jou gebied.';

  @override
  String get askEmptyBody =>
      'Ek lees jou verkope-, voorraad-, rak- en mededingerdata en verduidelik wat ek kry. Ek kan niks verander nie.';

  @override
  String get askTryOneOfThese => 'Probeer een van hierdie';

  @override
  String get askReadOnlyFootnote =>
      'Slegs-lees. Niks wat jy hier vra verander jou data nie.';

  @override
  String get askExampleTeam => 'Hoe vaar my span vandeesmaand?';

  @override
  String get askExampleTeamReads => 'lees besoekgeskiedenis en punktelkaarte';

  @override
  String get askExampleStock =>
      'Watter winkels raak aanhoudend sonder voorraad?';

  @override
  String get askExampleStockReads => 'lees voorraad op rak, swakste eerste';

  @override
  String get askExampleShelf => 'Wat is ons rakaandeel jaar tot datum?';

  @override
  String get askExampleShelfReads => 'lees rakoudits en foto’s';

  @override
  String get askExampleFraud => 'Wys my enige besoeke wat verdag lyk.';

  @override
  String get askExampleFraudReads => 'lees gemerkte besoeke en GPS';

  @override
  String get askSuggestionsGroup => 'Vier voorbeeldvrae';

  @override
  String askSuggestionSemantic(String question, String reads) {
    return 'Vra: $question Dit $reads';
  }

  @override
  String get askNotEnabledHeadline => 'Nog nie aangeskakel nie.';

  @override
  String get askNotEnabledBody =>
      'Vra TradeIQ word geleidelik uitgerol — praat met jou TradeIQ-kontak om ingesluit te word.';

  @override
  String get askStepsLookingUp => 'Besig om op te soek';

  @override
  String get askStepsWriting => 'Besig om die antwoord te skryf';

  @override
  String get askStepsStillWorking => 'Hierdie een neem ’n rukkie';

  @override
  String get askStepsStarting => 'Lees jou vraag';

  @override
  String askStepsStillWorkingOn(String label) {
    return 'Werk nog aan $label.';
  }

  @override
  String get askStopShort => 'Stop';

  @override
  String get askNavFloor => 'Vloer';

  @override
  String get askNavWork => 'Werk';

  @override
  String get askNavAsk => 'Vra';

  @override
  String get askNavMenu => 'Kieslys';

  @override
  String get askStepsLive => 'Besig';

  @override
  String askStepsUnavailable(String label) {
    return '$label — nie beskikbaar nie';
  }

  @override
  String askStepsDidNotFinish(String label) {
    return '$label — het nie klaargemaak nie';
  }

  @override
  String askStepsMore(int count) {
    return 'Nog $count';
  }

  @override
  String askStepsChecked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bronne nagegaan',
      one: '1 bron nagegaan',
    );
    return '$_temp0';
  }

  @override
  String askStepsUnavailableCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nie beskikbaar nie',
      one: '1 nie beskikbaar nie',
    );
    return '$_temp0';
  }

  @override
  String get askStepsNoneAnswered => 'Geen bron het geantwoord nie';

  @override
  String get askStepsShow => 'wys die stappe';

  @override
  String get askStepsHide => 'versteek die stappe';

  @override
  String askStepsSemantic(String summary, String action) {
    return '$summary, $action';
  }

  @override
  String askStepProgress(int index, int total, String label) {
    return 'Stap $index van $total, $label';
  }

  @override
  String get askCallout => 'Wat dit verklaar';

  @override
  String get askSources => 'Bronne';

  @override
  String get askSourcesNothingUsable =>
      'Die soektog het niks bruikbaars opgelewer nie.';

  @override
  String askSourcesGroup(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Bronne, $count items',
      one: 'Bronne, 1 item',
    );
    return '$_temp0';
  }

  @override
  String askSourceSemantic(int index, String domain, String title) {
    return 'Webbron $index, $domain, $title, maak in blaaier oop';
  }

  @override
  String get askSourceOpensInBrowser => 'maak in blaaier oop';

  @override
  String get askSourceUnreachable =>
      'Kon nie ’n blaaier oopmaak nie. Hou lank om die adres te kopieer.';

  @override
  String get askSourceCopied => 'Adres gekopieer';

  @override
  String askShowAllSources(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Wys al $count bronne',
      one: 'Wys 1 bron',
    );
    return '$_temp0';
  }

  @override
  String askShowAll(int count) {
    return 'Wys al $count';
  }

  @override
  String get askNoticeLookupBudget =>
      'Ek het opgeraak aan opsoeke vir hierdie vraag, so hierdie antwoord is dalk onvolledig.';

  @override
  String get askNoticeTimeBudget =>
      'Ek het tyd opgeraak op hierdie vraag, so hierdie antwoord is dalk onvolledig.';

  @override
  String get askNoticeToolCallRefused =>
      'Ek het opgehou voor die opsoeke wat ek beplan het, so hierdie antwoord is dalk onvolledig.';

  @override
  String get askNoticeGeneral => 'Hierdie antwoord is dalk onvolledig.';

  @override
  String get askNoticeNarrower => 'Vra ’n nouer opvolgvraag om verder te gaan.';

  @override
  String askNoticeSemantic(String reason, String advice) {
    return 'Let wel: hierdie antwoord is dalk onvolledig. $reason $advice';
  }

  @override
  String get askFigures => 'Syfers vir hierdie antwoord';

  @override
  String get askWorstFirst => 'Swakste eerste';

  @override
  String get askOverTime => 'Oor tyd';

  @override
  String get askUnsupportedView =>
      'Hierdie antwoord bevat ’n aansig wat jou weergawe van die program nog nie kan teken nie. Die opsomming hierbo geld steeds.';

  @override
  String get askUnprovenancedFigures =>
      'Syfers word nie gewys vir antwoorde wat die web gebruik het nie, want hierdie weergawe van die program kan nie sê watter van buite af kom nie.';

  @override
  String get askLoadingFigures => 'Laai syfers';

  @override
  String get askLoading => 'Laai';

  @override
  String askNotEnoughToPlot(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Nie genoeg data om te teken nie — $count tydperke is teruggegee.',
      one: 'Nie genoeg data om te teken nie — 1 tydperk is teruggegee.',
      zero: 'Nie genoeg data om te teken nie — niks is teruggegee nie.',
    );
    return '$_temp0';
  }

  @override
  String askNoComparisonData(String label) {
    return 'geen data vir $label nie';
  }

  @override
  String get askChartSolidLine => 'soliede lyn';

  @override
  String get askChartDashedLine => 'streeplyn';

  @override
  String askLegend(String entries) {
    return 'Sleutel: $entries';
  }

  @override
  String askLegendEntry(String name, String channel) {
    return '$name, $channel';
  }

  @override
  String askBarSemantic(String name, String value, int index, int total) {
    return '$name, $value, posisie $index van $total';
  }

  @override
  String get askBarWorst => 'swakste';

  @override
  String get askOutsideData => 'Data van buite';

  @override
  String askOutsideRead(String date) {
    return 'gelees $date';
  }

  @override
  String askOutsidePublisher(String publisher, String date) {
    return '$publisher, gelees $date. Nie TradeIQ-data nie, en nie by enige totaal hierbo getel nie.';
  }

  @override
  String askOutsideUnnamed(String date) {
    return 'Van buite TradeIQ gelees op $date. Nie TradeIQ-data nie, en nie by enige totaal hierbo getel nie.';
  }

  @override
  String askOutsideStale(int days) {
    return '$days dae oud';
  }

  @override
  String get askOutsideFigure => 'syfer van buite';

  @override
  String get askTryAgain => 'Probeer weer';

  @override
  String get askStopped => 'Gestop.';

  @override
  String get askStoppedSemantic => 'Gestop. Die antwoord is onvolledig.';

  @override
  String get askAskAgain => 'Vra weer';

  @override
  String get askFailedTwice =>
      'Dit het twee keer misluk. Dit is dalk die verbinding eerder as die vraag.';

  @override
  String askErrorSemantic(String message) {
    return 'Fout. $message';
  }

  @override
  String get askOffline => 'Geen verbinding nie — Vra TradeIQ het een nodig.';

  @override
  String get askSessionEnded =>
      'Jou sessie het geëindig. Teken in om weer te vra.';

  @override
  String get askSessionEndedSemantic =>
      'Jou sessie het geëindig. Teken in om weer te vra. Jou antwoorde is steeds op die skerm.';

  @override
  String get askSignIn => 'Teken in';

  @override
  String get askHeld => 'Gehou';

  @override
  String get askHistoryTitle => 'Hierdie gesprek';

  @override
  String askHistorySubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Op hierdie toestel gehou totdat jy die skerm verlaat. $count vrae.',
      one: 'Op hierdie toestel gehou totdat jy die skerm verlaat. 1 vraag.',
    );
    return '$_temp0';
  }

  @override
  String askHistoryLimit(int count) {
    return 'slegs die laaste $count word saam met ’n nuwe vraag gestuur';
  }

  @override
  String get askHistoryEmpty => 'Nog niks nie.';

  @override
  String get askHistoryEmptyBody =>
      'Jou vrae sal hier gelys word terwyl jy op hierdie skerm is.';

  @override
  String askHistoryRowSemantic(String time, String question) {
    return 'Gevra om $time: $question Gaan na hierdie antwoord.';
  }

  @override
  String get askNow => 'nou';

  @override
  String get askStartOver => 'Begin ’n nuwe gesprek';

  @override
  String get askStartOverTitle => 'Begin ’n nuwe gesprek?';

  @override
  String askStartOverBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Hierdie een word nie gestoor nie. Die $count vrae en hul antwoorde gaan weg.',
      one:
          'Hierdie een word nie gestoor nie. Die 1 vraag en sy antwoord gaan weg.',
    );
    return '$_temp0';
  }

  @override
  String get askCarryOn => 'Gaan voort';

  @override
  String get askStartOverConfirm => 'Begin oor';

  @override
  String get askStartOverMidTurnTitle => '’n Vraag word nog beantwoord.';

  @override
  String get askStartOverMidTurnBody => 'Om oor te begin sal dit stop.';

  @override
  String get askKeepWaiting => 'Hou aan wag';

  @override
  String get askStopAndStartOver => 'Stop en begin oor';

  @override
  String get askShowFullQuestion => 'Wys die hele vraag';

  @override
  String askFollowUpSemantic(String question) {
    return 'Vra: $question';
  }

  @override
  String get askFollowUpDisabled =>
      'nie beskikbaar terwyl die antwoord geskryf word nie';

  @override
  String askSeconds(String seconds) {
    return '${seconds}s';
  }

  @override
  String askPoints(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'pte',
      one: 'pt',
    );
    return '$_temp0';
  }

  @override
  String get askAnswer => 'Antwoord';

  @override
  String get askOpenFullView => 'Maak volle aansig oop';

  @override
  String askOpenFullViewOf(String name) {
    return 'Maak die volle aansig van $name oop';
  }

  @override
  String get askQuestionCopied => 'Vraag gekopieer';

  @override
  String get askTileNoData => 'Niks in hierdie tydperk gemeet nie';

  @override
  String get askPillarSales => 'Verkope';

  @override
  String get askPillarStock => 'Voorraad';

  @override
  String get askPillarVisibility => 'Sigbaarheid';

  @override
  String get askPillarCompetition => 'Mededinging';

  @override
  String get askPillarFigures => 'Pilaarsyfers';

  @override
  String get askPillarNoFigures =>
      'Geen syfers is vir hierdie tydperk teruggestuur nie.';

  @override
  String askPillarComparedWith(String label) {
    return 'Verandering word teen $label gemeet.';
  }

  @override
  String get askMetricOsa => 'Beskikbaarheid op die rak';

  @override
  String get askMetricShareOfShelf => 'Rakaandeel';

  @override
  String get askMetricVisibility => 'Sigbaarheidsnakoming';

  @override
  String get askMetricPrice => 'Prysnakoming';

  @override
  String get askMetricAttainment => 'Bereiking';

  @override
  String get askMetricRateOfSale => 'Verkoopstempo';

  @override
  String get askMetricOutletsWithStockout => 'Winkels met ’n uitverkoping';

  @override
  String get askMetricOutOfStockLines => 'Uitverkoopte lyne';

  @override
  String get askMetricLinesObserved => 'Lyne waargeneem';

  @override
  String get askMetricCompetitorFacings => 'Mededinger-fasette';

  @override
  String get askMetricExecutionScore => 'Uitvoeringtelling';

  @override
  String get askMetricPerfectStore => 'Perfekte-winkel-koers';

  @override
  String get askScorecardTitle => 'Agent-telkaart';

  @override
  String askScorecardScored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count besoeke met ’n telling',
      one: '1 besoek met ’n telling',
    );
    return '$_temp0';
  }

  @override
  String get askScorecardAverage => 'Gemiddelde telling';

  @override
  String get askScorecardTeam => 'Spangemiddeld';

  @override
  String get askScorecardNoTeam =>
      'Geen ander agent het in hierdie tydperk ’n besoek met ’n telling nie.';

  @override
  String get askScorecardVisits => 'Besoeke';

  @override
  String get askScorecardOutlets => 'Winkels';

  @override
  String get askScorecardVsTeam => 'teen die span';

  @override
  String get askMapTitle => 'Winkels met uitverkopings';

  @override
  String askMapCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count winkels',
      one: '1 winkel',
    );
    return '$_temp0';
  }

  @override
  String get askMapUnreadable =>
      'Die winkelliggings vir hierdie antwoord kon nie gelees word nie. Die opsomming hierbo geld steeds.';

  @override
  String askMapPin(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lyne',
      one: '1 lyn',
    );
    return '$name, $_temp0 uit voorraad';
  }

  @override
  String get askMapNotInVeld =>
      'Kaarte word nie in Veld geteken nie. Die winkels word eerder gelys.';

  @override
  String get visitPinTooFarToReport =>
      'Dit is te ver om die speld van hier af aan te meld. Vra jou bestuurder om hierdie winkel reg te stel.';

  @override
  String get pinDisputeEyebrow => 'Die speld is verkeerd';

  @override
  String get pinDisputeTitle => 'Meld die speld aan en begin die besoek';

  @override
  String get pinDisputeEvidenceEyebrow => 'Saam met jou verslag gestuur';

  @override
  String get pinDisputeDistanceLine =>
      'van waar die app hierdie winkel het, pas nou gemeet';

  @override
  String pinDisputeDistanceSemantics(int meters) {
    return 'Jy is $meters meter van waar die app hierdie winkel het.';
  }

  @override
  String get pinDisputePositionLine =>
      'Waar jy staan, soos jou foon dit aangeteken het';

  @override
  String get pinDisputePhotoLine => 'Jou foto van die winkelfront';

  @override
  String get pinDisputeExplain =>
      'Die besoek begin buite die heining en bly gevlag. Jou bestuurder sien waar jy was en kan die speld skuif. Jy kan nie self die vlag verwyder nie.';

  @override
  String get pinDisputeNoteLabel => 'Wat is fout met die speld? (opsioneel)';

  @override
  String get pinDisputeNoteHint =>
      'bv. die speld is by die depot, die winkel is in Hoofweg';

  @override
  String get pinDisputeAddPhoto => 'Voeg ’n foto van die winkelfront by';

  @override
  String get pinDisputeRetakePhoto => 'Neem die foto weer';

  @override
  String get pinDisputePhotoAdded =>
      'Winkelfront-foto bygevoeg. Dit word saam met die besoek gestuur.';

  @override
  String get pinDisputePhotoLabel => 'Winkelfront';

  @override
  String get pinDisputePhotoHint =>
      'Staan ver genoeg terug om die winkelnaam en die deur in een foto te kry.';

  @override
  String get pinDisputeSubmit => 'Begin die besoek, gevlag';

  @override
  String get pinDisputeBack => 'Terug na die afstand';

  @override
  String pinDisputeFailed(String reason) {
    return 'Die besoek kon nie begin nie: $reason';
  }

  @override
  String get visitFlagOutOfFence => 'Buite heining';

  @override
  String visitFlagMetres(int meters) {
    return '$meters m';
  }

  @override
  String visitFlagOutOfFenceSemantics(int meters) {
    return 'Buite heining, $meters meter. Dubbeltik vir besonderhede.';
  }

  @override
  String get visitFlagPinReported => 'Speld aangemeld';

  @override
  String get visitFlagPinReportedSemantics =>
      'Speld aangemeld, vir jou bestuurder om na te gaan. Dubbeltik vir besonderhede.';

  @override
  String get visitFlagSheetTitle => 'Buite die heining ingeteken';

  @override
  String visitFlagSheetBody(int meters) {
    return 'Jy was $meters m van hierdie winkel se speld af en het die speld as verkeerd aangemeld. Jou posisie en afstand is saam met die besoek gestuur. Jou bestuurder gaan dit na en kan die speld skuif; die vlag bly totdat hulle dit doen.';
  }

  @override
  String get myWorkSendNow => 'Stuur nou';

  @override
  String get myWorkSendNowBlocked => 'Niks wag om gestuur te word nie.';

  @override
  String myWorkSignedOutTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Jy is afgemeld. Meld aan en jou $count gehoue vasleggings sal stuur.',
      one: 'Jy is afgemeld. Meld aan en jou 1 gehoue vaslegging sal stuur.',
    );
    return '$_temp0';
  }

  @override
  String get myWorkSignIn => 'Meld aan';

  @override
  String get myWorkShowOlder => 'Wys ouer';

  @override
  String myWorkSentCapped(int shown, int total) {
    return 'Wys die $shown mees onlangs gestuurdes van $total';
  }

  @override
  String get myWorkEmptyBody =>
      'Alles wat jy in ’n winkel vaslê, verskyn hier totdat die bediener dit het.';

  @override
  String get myWorkLoadErrorBody =>
      'Jou werk is steeds op hierdie foon. Niks is verlore nie.';

  @override
  String get myWorkRetry => 'Probeer weer';

  @override
  String get outboxWaiting => 'Wag';

  @override
  String get outboxSending => 'Stuur tans';

  @override
  String get outboxRetrying => 'Probeer weer';

  @override
  String get outboxSent => 'Gestuur';

  @override
  String get outboxNeedsYou => 'Het jou nodig';

  @override
  String get outboxWaitingTurn => 'Wag sy beurt';

  @override
  String get outboxWaitingSentence => 'Wag vir sein';

  @override
  String get outboxSendingSentence => 'Gaan nou op';

  @override
  String get outboxSentSentence => 'Die bediener het dit';

  @override
  String outboxQueuedAt(String time) {
    return 'in ry $time';
  }

  @override
  String outboxSentAt(String time) {
    return 'gestuur $time';
  }

  @override
  String outboxLastTriedAt(String time) {
    return 'laas probeer $time';
  }

  @override
  String outboxAttempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count keer probeer',
      one: 'Een keer probeer',
      zero: 'Nog nie probeer nie',
    );
    return '$_temp0';
  }

  @override
  String get outboxSendThisNow => 'Stuur hierdie een nou';

  @override
  String get outboxDiscard => 'Gooi hierdie vaslegging weg';

  @override
  String get outboxDiscardConfirm => 'Ja, gooi dit weg';

  @override
  String get outboxDiscardKeep => 'Hou dit';

  @override
  String outboxDiscardWhatIsLost(String item) {
    return 'Hierdie $item het nie die bediener bereik nie. Gooi dit weg en dit is van hierdie foon af weg — daar is nie ’n kopie enige plek anders nie.';
  }

  @override
  String outboxDiscardTakesDependents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count vasleggings van hierdie besoek gaan saam, want hulle kan nie sonder die besoek stuur nie.',
      one:
          '1 vaslegging van hierdie besoek gaan saam, want dit kan nie sonder die besoek stuur nie.',
    );
    return '$_temp0';
  }

  @override
  String get outboxNothingToDo => 'Niks om te doen nie — die bediener het dit.';

  @override
  String get outboxRejectedNote =>
      'Die bediener het dit net so geweier, so om dit onveranderd weer te stuur sal net so misluk. Niks is vir jou verander nie.';

  @override
  String get outboxWaitingTurnNote =>
      'Hierdie stuur vanself sodra die besoek bo dit stuur. Niks is verkeerd nie.';

  @override
  String get outboxSignedOutNote =>
      'Jou sessie het geëindig. Meld aan en hierdie stuur vanself.';

  @override
  String outboxItemId(int id, String type) {
    return 'Vaslegging $id · $type';
  }

  @override
  String get pickerEmptyTitle => 'Geen winkels hier nie';

  @override
  String get pickerEmptyBodyMine =>
      'Niks is nog onder jou gebiede geliasseer nie. Skakel oor na alle winkels, of voeg die een by waar jy staan.';

  @override
  String get pickerEmptyBodyAll =>
      'Hierdie kliënt het nog geen winkels op die bediener nie. Voeg die een by waar jy staan.';

  @override
  String get pickerLoadErrorBody =>
      'Jou winkels word van die bediener af gehaal. Niks wat jy vasgelê het, word geraak nie.';

  @override
  String get pickerScopeHeading => 'Watter winkels';

  @override
  String get pickerStoresHeading => 'Winkels';

  @override
  String get syncBannerOpen => 'tik om jou werk oop te maak';

  @override
  String get commonClose => 'Maak toe';

  @override
  String pickerStartVisitSemantics(String name, String code) {
    return '$name, $code. Dubbeltik om hier ’n besoek te begin.';
  }

  @override
  String syncBannerNeedsYou(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'het jou nodig',
      one: 'het jou nodig',
    );
    return '$_temp0';
  }
}
