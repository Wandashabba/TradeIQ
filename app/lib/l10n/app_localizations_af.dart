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
  String askSourceCopiedPreview(String snippet) {
    return 'Adres gekopieer. Die bladsy sê: $snippet';
  }

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
  String get askCopyAnswer => 'Kopieer hierdie antwoord';

  @override
  String get askAnswerCopied => 'Antwoord gekopieer';

  @override
  String get askAskAgainAnswer => 'Vra hierdie vraag weer';

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
  String get askTileUpdatedTo => 'Bygewerk na';

  @override
  String get askTileUpdatedFrom => 'van';

  @override
  String askTileUpdatedAt(String time) {
    return 'Bygewerk om $time.';
  }

  @override
  String askTileWasValue(String value, String time) {
    return 'Was $value om $time.';
  }

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
  String get wordYes => 'Ja';

  @override
  String get wordNo => 'Nee';

  @override
  String get sectionSave => 'Stoor';

  @override
  String get sectionSaveAndBack => 'Stoor en gaan terug';

  @override
  String get sectionSaveFailedTitle => 'Nie gestoor nie';

  @override
  String get sectionSaveFailedBody =>
      'Jou antwoorde is nog hier — probeer weer Stoor.';

  @override
  String get sectionCantConfirm => 'Kan nie hierdie afdeling bevestig nie';

  @override
  String get sectionCantConfirmWhy => 'Hoekom nie?';

  @override
  String sectionCantConfirmLocked(String reason) {
    return 'Kan nie bevestig nie: $reason';
  }

  @override
  String get sectionCantConfirmHeld =>
      'Gehou op hierdie foon. Niks word nog hiervoor gestuur nie.';

  @override
  String get sectionCanConfirmAfterAll => 'Ek kan dit tog bevestig';

  @override
  String get sectionLockedBlock =>
      'Hierdie afdeling is gemerk as kan-nie-bevestig-nie';

  @override
  String get sectionLeaveTitle => 'Jy het ongestoorde antwoorde';

  @override
  String get sectionLeaveWithoutSaving => 'Gaan terug sonder om te stoor';

  @override
  String get sectionStayHere => 'Bly hier';

  @override
  String get sectionAddAnother => 'Voeg nog een by';

  @override
  String sectionEntryPosition(int index, int total) {
    return '$index van $total';
  }

  @override
  String sectionRemoveEntry(String name, String position) {
    return 'Verwyder $name $position';
  }

  @override
  String get sectionNotAnsweredYet => 'Nog nie beantwoord nie';

  @override
  String get sectionPhotoOpenCamera => 'Maak kamera oop';

  @override
  String get sectionPhotoOpenCameraSemantics =>
      'Maak die kamera oop om die rak te fotografeer';

  @override
  String get sectionPhotoFraming =>
      'Staan ver genoeg terug om die hele rak te kry, die pryslys ingesluit.';

  @override
  String get sectionPhotoStamped =>
      'Jou foto word gestempel met die tyd en waar jy is.';

  @override
  String get sectionPhotoTorchHint =>
      'Gang donker? Skakel jou foon se flits aan voor jy skiet.';

  @override
  String get sectionPhotoHeld =>
      'Gehou op hierdie foon · stuur saam met die besoek';

  @override
  String get sectionPhotoNoCamera =>
      'Hierdie foon het geen kamera wat ons kan bereik nie.';

  @override
  String get sectionPhotoTooLarge =>
      'Daardie foto is te groot om te stuur. Neem dit weer.';

  @override
  String get sectionPhotoFailed =>
      'Die kamera het nie die foto teruggegee nie. Probeer weer.';

  @override
  String get sectionPhotoRemoveSemantics => 'Verwyder die foto';

  @override
  String sectionPhotoSemantics(String time) {
    return 'Foto geneem $time, gehou op hierdie foon';
  }

  @override
  String get skipReasonStoreRefused => 'Die winkel wou my nie toelaat nie';

  @override
  String get skipReasonStoreRefusedConsequence =>
      'Die bestuurder word vertel die winkel het geweier';

  @override
  String get skipReasonNotStocked => 'Hulle hou dit nie aan nie';

  @override
  String get skipReasonNotStockedConsequence =>
      'Hierdie lyne word gemerk as nie-aangehou vir hierdie winkel';

  @override
  String get skipReasonEquipment => 'Die toerusting is stukkend';

  @override
  String get skipReasonEquipmentConsequence => '\'n Hersteltaak word geskep';

  @override
  String get skipReasonSomethingElse => 'Iets anders';

  @override
  String get skipReasonSomethingElseConsequence => 'Jy skryf wat gebeur het';

  @override
  String get skipReasonSave => 'Stoor rede';

  @override
  String get skipReasonChange => 'Verander rede';

  @override
  String get skipReasonCancel => 'Kanselleer';

  @override
  String get skipReasonNoteLabel => 'Wat het gebeur?';

  @override
  String get skipReasonChooseFirst => 'Kies eers ’n rede';

  @override
  String get skipReasonSayWhatHappened => 'Sê wat gebeur het';

  @override
  String s2Summary(int counted, int outOfStock, int toGo) {
    return '$counted getel · $outOfStock uit voorraad · $toGo oor';
  }

  @override
  String get s2NotCounted => 'Nie getel nie';

  @override
  String get s2OutOfStockWord => 'Uit voorraad';

  @override
  String get s2TypeCount => 'Tik ’n telling';

  @override
  String get s2OneFewer => 'Een minder';

  @override
  String get s2OneMore => 'Een meer';

  @override
  String s2PartCounted(int toGo) {
    return 'Om nou te stoor merk $toGo produkte as nie getel nie — nooit as leeg nie.';
  }

  @override
  String s2CountedOf(int counted, int total) {
    return '$counted van $total getel';
  }

  @override
  String s2StockSavedPartial(int counted, int total) {
    return '$counted van $total gestoor — die res is nie getel nie, nooit leeg nie';
  }

  @override
  String get s2JumpToUncounted => 'Spring na die eerste ongetelde';

  @override
  String get s10NotFinal =>
      'Op hierdie foon uitgewerk. Die finale telling kom terug wanneer die besoek stuur.';

  @override
  String get s10NotMeasured => 'Nie op hierdie besoek gemeet nie';

  @override
  String get s10NothingCaptured =>
      'Niks is nog op hierdie besoek vasgelê nie, so daar is geen telling om uit te werk nie.';

  @override
  String get s10NoScoreSemantics =>
      'Nog geen geweegde totaal nie. Niks is op hierdie besoek vasgelê nie.';

  @override
  String s10ScoreSemantics(String score, String band) {
    return 'Geweegde totaal $score uit 100, $band';
  }

  @override
  String get s5NoPriceYet => 'Geen prys ingevoer nie';

  @override
  String get s6NoCompetitors =>
      'Nog geen mededinger op hierdie rak nie. Voeg een by as jy dit sien.';

  @override
  String get s8NoRisks => 'Nog niks gemerk nie.';

  @override
  String get s9NoTasks => 'Nog geen ekstra take nie.';

  @override
  String s9AddedTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count take in die ry vir sinkronisasie',
      one: '1 taak in die ry vir sinkronisasie',
    );
    return '$_temp0';
  }

  @override
  String get s2TypeCountFirst => 'Tik eers ’n telling';

  @override
  String sectionEntryName(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'competitor': 'Mededinger',
      'risk': 'Risiko',
      'other': 'Taak',
    });
    return '$_temp0';
  }

  @override
  String sectionEntryNameLower(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'competitor': 'mededinger',
      'risk': 'risiko',
      'other': 'taak',
    });
    return '$_temp0';
  }

  @override
  String get sectionEntryUnnamed => 'Nog nie benoem nie';

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
  String get outboxHeld => 'Gehou';

  @override
  String get outboxHeldUntilSignIn => 'Gehou totdat jy aanmeld';

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

  @override
  String get errorTooManyAttempts =>
      'Te veel pogings. Wag ’n paar minute en probeer dan weer.';

  @override
  String get errorUpdateRequired =>
      'Hierdie weergawe van die toep is te oud. Dateer TradeIQ op om voort te gaan.';

  @override
  String get passwordRuleHelp =>
      'Ten minste 12 karakters. Drie gewone woorde is maklik om te tik en moeilik om te raai.';

  @override
  String get passwordTooShort => 'Te kort: gebruik ten minste 12 karakters.';

  @override
  String get passwordTooLong =>
      'Te lank vir ’n wagwoord hier. Gebruik minder karakters.';

  @override
  String get passwordIsEmail => 'Jou wagwoord kan nie jou e-posadres wees nie.';

  @override
  String get passwordMismatch => 'Die twee nuwe wagwoorde stem nie ooreen nie.';

  @override
  String get passwordRejected =>
      'Daardie wagwoord is nie aanvaar nie. Gebruik ten minste 12 karakters, nie jou e-posadres nie en nie ’n voor die hand liggende frase nie.';

  @override
  String get passwordShow => 'Wys wagwoorde';

  @override
  String get passwordNeedsNew => 'Kies ’n nuwe wagwoord';

  @override
  String get passwordNeedsConfirm => 'Tik die nuwe wagwoord weer';

  @override
  String get passwordFailedTitle => 'Jou wagwoord is nie verander nie';

  @override
  String get passwordOtherSessions =>
      'Ander fone wat by jou rekening aangemeld is, bly aangemeld totdat hul sessie verval, tot 12 uur. As ’n foon verlore is, vra jou bestuurder om die rekening af te skakel.';

  @override
  String get forgotTitle => 'Stel jou wagwoord terug';

  @override
  String get forgotBack => 'Terug na aanmelding';

  @override
  String get forgotIntro =>
      'Vra jou bestuurder vir ’n herstelkode. Hulle maak dit in TradeIQ en lees dit vir jou voor. Dit werk een keer, vir 15 minute.';

  @override
  String get forgotEmailLabel => 'E-pos';

  @override
  String get forgotCodeLabel => 'Herstelkode';

  @override
  String get forgotCodeHint => '8 syfers';

  @override
  String get forgotNewPasswordLabel => 'Nuwe wagwoord';

  @override
  String get forgotConfirmLabel => 'Nuwe wagwoord weer';

  @override
  String get forgotSubmit => 'Stel nuwe wagwoord';

  @override
  String get forgotNeedsEmail => 'Tik eers jou e-pos in';

  @override
  String get forgotNeedsCode => 'Tik die 8-syfer-kode van jou bestuurder in';

  @override
  String get forgotCodeRejectedTitle => 'Daardie kode het nie gewerk nie';

  @override
  String get forgotCodeRejectedBody =>
      'Dit is dalk verkeerd getik, reeds gebruik of ouer as 15 minute. Kyk ook na die e-pos. Jou bestuurder kan ’n nuwe kode maak.';

  @override
  String get forgotDoneTitle => 'Jou wagwoord is verander';

  @override
  String get forgotDoneBody => 'Meld aan met jou nuwe wagwoord.';

  @override
  String get forgotGoToSignIn => 'Gaan na aanmelding';

  @override
  String get changePasswordTitle => 'Verander wagwoord';

  @override
  String get changePasswordBack => 'Terug na instellings';

  @override
  String get changeCurrentLabel => 'Huidige wagwoord';

  @override
  String get changeNeedsCurrent => 'Tik jou huidige wagwoord in';

  @override
  String get changeWrongCurrent => 'Dit is nie jou huidige wagwoord nie.';

  @override
  String get changeDoneTitle => 'Wagwoord verander';

  @override
  String get changeDoneBody =>
      'Jy bly op hierdie foon aangemeld. Gebruik die nuwe wagwoord wanneer jy weer aanmeld.';

  @override
  String get changeDone => 'Klaar';

  @override
  String get settingsAccountHeading => 'Jou rekening';

  @override
  String get updateTitle => 'Dateer TradeIQ op';

  @override
  String get updateBody =>
      'Hierdie weergawe van die toep is te oud vir die bediener. Installeer die nuutste weergawe van waar jy TradeIQ gekry het, en maak dit dan weer oop.';

  @override
  String get updateNothingLost =>
      'Niks wat op hierdie foon gestoor is, word hierdeur uitgevee nie.';

  @override
  String get updateTryAgain => 'Probeer weer';

  @override
  String updateVersions(String current, String minimum) {
    return 'Hierdie foon het weergawe $current. Weergawe $minimum of nuwer is nodig.';
  }

  @override
  String updateVersionNoMinimum(String current) {
    return 'Hierdie foon het weergawe $current. ’n Nuwer weergawe is nodig.';
  }

  @override
  String get submitSectionsUnread =>
      'Kon nie lees watter afdelings klaar is nie';

  @override
  String get submitSectionsUnreadTask =>
      'Jou afdelings kon nie gelees word nie';

  @override
  String get submitSectionsUnreadRowLine => 'Iets ontbreek dalk op hierdie lys';

  @override
  String get submitSectionsUnreadNote =>
      '’n Afdeling wat nie bevestig kon word nie, ontbreek dalk op hierdie lys. Gaan terug en maak jou afdelings oop om seker te maak voordat jy indien.';

  @override
  String submitCapturedUnreadSemantics(String line) {
    return 'Kon nie lees watter afdelings klaar is nie. $line';
  }

  @override
  String get outcomePreviousUnknown =>
      'Jou vorige besoek hier kon nie gelaai word nie, so daar is niks om hierdie telling mee te vergelyk nie.';

  @override
  String get outboxSeeScore => 'Kyk hoe dit gevaar het';

  @override
  String get meTitle => 'Ek';

  @override
  String get meEarnedHeading => 'Wat ek verdien het';

  @override
  String get meVisitsHeading => 'My besoeke';

  @override
  String get meLedgerHeading => 'Hoe jy dit verdien het';

  @override
  String get mePointsEyebrow => 'PUNTE ALTESAAM';

  @override
  String get meAllTime => 'Van die begin af';

  @override
  String get meRankEyebrow => 'PLEK';

  @override
  String get meLoadErrorDetail =>
      'Jou werk is veilig op hierdie foon. Hierdie deel kom van die bediener en vul in sodra dit antwoord.';

  @override
  String get meNotRanked =>
      'Net veldagente word gerangskik, so jy het nie \'n plek op hierdie ranglys nie.';

  @override
  String get meNoPointsYet =>
      'Nog geen punte nie. Punte kom wanneer \'n besoek ingedien of \'n taak gesluit word.';

  @override
  String get meNoScheme => 'Geen beloning loop tans nie.';

  @override
  String meRewardProgress(String value, String total) {
    return '$value van $total';
  }

  @override
  String meRewardToGo(String remaining, String reward) {
    return '$remaining oor · $reward';
  }

  @override
  String meRewardReached(String reward) {
    return 'Beloning behaal — $reward.';
  }

  @override
  String meRewardPoints(int points) {
    String _temp0 = intl.Intl.pluralLogic(
      points,
      locale: localeName,
      other: '$points punte',
      one: '1 punt',
    );
    return '$_temp0';
  }

  @override
  String get mePointsHonesty =>
      'Punte word op die bediener bereken. Hulle kan verander as \'n besoek hersien word.';

  @override
  String get meLedgerEmpty => 'Niks het nog punte verdien nie.';

  @override
  String get meVisitsEmpty => 'Nog geen besoeke nie';

  @override
  String get meVisitsEmptyDetail =>
      'Elke winkel waar jy inklok verskyn hier — wanneer jy gegaan het, hoe lank jy gebly het, en wat dit behaal het.';

  @override
  String get meVisitsLoadError => 'Jou besoeke het nie gelaai nie';

  @override
  String get meNotScoredYet => 'Wag om gepunt te word';

  @override
  String get meVisitOpen => 'Nog oop op hierdie foon';

  @override
  String meVisitMeta(String day, String dwell, String tasks) {
    return '$day · $dwell · $tasks';
  }

  @override
  String meDwellMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get meDwellUnknown => 'tyd nie aangeteken nie';

  @override
  String meTasksRaised(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count take geopper',
      one: '1 taak geopper',
      zero: 'geen take geopper nie',
    );
    return '$_temp0';
  }

  @override
  String meCapturedCount(int captured, int total, int photos) {
    String _temp0 = intl.Intl.pluralLogic(
      photos,
      locale: localeName,
      other: '$photos foto\'s',
      one: '1 foto',
      zero: 'geen foto\'s',
    );
    return '$captured van $total afdelings · $_temp0';
  }

  @override
  String meDistanceMeters(int metres) {
    return '$metres m van die deur';
  }

  @override
  String get meDistanceUnknown => 'afstand nie gemeet nie';

  @override
  String get meOutOfFence => 'Buite die heining';

  @override
  String get meReviewed => 'Hersien';

  @override
  String get mePinReported => 'Jy het die speld as verkeerd aangemeld';

  @override
  String meOnThisPhone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vasleggings het nie gestuur nie',
      one: '1 vaslegging het nie gestuur nie',
    );
    return '$_temp0';
  }

  @override
  String get meOnThisPhoneDetail =>
      'Wys wat die bediener bereik het. Vandag se werk verskyn hier sodra dit stuur.';

  @override
  String meVisitSemantics(
    String outlet,
    String day,
    String tasks,
    String dwell,
    String score,
  ) {
    return '$outlet, $day, $dwell, $tasks, $score';
  }

  @override
  String meScoredSemantics(String score) {
    return '$score behaal';
  }

  @override
  String meRewardSemantics(String value, String total, String line) {
    return 'Vordering tot beloning: $value van $total. $line';
  }

  @override
  String meLedgerRowSemantics(String reason, String day, String points) {
    return '$reason, $day, $points';
  }

  @override
  String mePointsPlus(int points) {
    String _temp0 = intl.Intl.pluralLogic(
      points,
      locale: localeName,
      other: 'plus $points punte',
      one: 'plus 1 punt',
    );
    return '$_temp0';
  }

  @override
  String mePointsMinus(int points) {
    String _temp0 = intl.Intl.pluralLogic(
      points,
      locale: localeName,
      other: 'minus $points punte',
      one: 'minus 1 punt',
    );
    return '$_temp0';
  }

  @override
  String get meEarningsLoadError => 'Jou punte het nie gelaai nie';

  @override
  String get meReasonVisitSubmitted => 'Besoek ingedien';

  @override
  String get meReasonTaskClosed => 'Taak gesluit';

  @override
  String get meReasonScorecard => 'Telkaart';

  @override
  String get meReasonPoints => 'Punte';

  @override
  String meLedgerScoreRowSemantics(String reason, String day, String score) {
    return '$reason, $day, $score behaal';
  }

  @override
  String get meContestsDetail => 'Kyk waar jy staan';

  @override
  String get contestsBackToMe => 'Terug na Ek';

  @override
  String get contestsBackToToday => 'Terug na Vandag';

  @override
  String get contestRankEyebrow => 'Jou posisie';

  @override
  String get contestPointsEyebrow => 'Jou punte';

  @override
  String contestRankOutOf(int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'uit $total agente',
      one: 'uit 1 agent',
    );
    return '$_temp0';
  }

  @override
  String get contestNobodyRanked => 'Niemand het nog punte verdien nie.';

  @override
  String get wordOn => 'Aan';

  @override
  String get wordOff => 'Af';

  @override
  String get notificationsBackToMe => 'Terug na Ek';

  @override
  String get notificationsBackToToday => 'Terug na Vandag';

  @override
  String get notificationsHeading => 'Wat hierdie foon bereik';

  @override
  String get loginFailedTitle => 'Ons kon jou nie inteken nie';

  @override
  String get menuTitle => 'Kieslys';

  @override
  String get menuSubtitle => 'Alles wat nie in die vier oortjies pas nie.';

  @override
  String get menuThisApp => 'Hierdie program';

  @override
  String get menuThemeLight => 'Ligte tema';

  @override
  String get menuThemeDark => 'Donker tema';

  @override
  String get menuChangePassword => 'Verander wagwoord';

  @override
  String get menuSignOut => 'Teken uit';

  @override
  String get navGroupOperate => 'Bedryf';

  @override
  String get navGroupInsight => 'Insig';

  @override
  String get navGroupConfigure => 'Stel op';

  @override
  String get navTheFloor => 'Die Vloer';

  @override
  String get navExecutionOverview => 'Uitvoeringsoorsig';

  @override
  String get navHome => 'Tuis';

  @override
  String get navTasks => 'Take';

  @override
  String get navAlerts => 'Waarskuwings';

  @override
  String get navOrders => 'Bestellings';

  @override
  String get navBeatPlans => 'Roeteplanne';

  @override
  String get navDispatch => 'Versending';

  @override
  String get navMessages => 'Boodskappe';

  @override
  String get navOutlets => 'Winkels';

  @override
  String get navAskTradeIq => 'Vra TradeIQ';

  @override
  String get navReports => 'Verslae';

  @override
  String get navTrends => 'Tendense';

  @override
  String get navSalesTargets => 'Verkoopsteikens';

  @override
  String get navLeaderboard => 'Ranglys';

  @override
  String get navContests => 'Kompetisies';

  @override
  String get navFraudReview => 'Bedrogoorsig';

  @override
  String get navCampaigns => 'Veldtogte';

  @override
  String get navAlertRules => 'Waarskuwingreëls';

  @override
  String get navTerritories => 'Gebiede';

  @override
  String get navUsers => 'Gebruikers';

  @override
  String get navAuditTemplates => 'Oudit-sjablone';

  @override
  String get navIncentives => 'Aansporings';

  @override
  String get navWebhooks => 'Webhooks';

  @override
  String get navScoringConfig => 'Punte-opstelling';

  @override
  String get sessionEndedTitle => 'Jy is uitgeteken';

  @override
  String get sessionEndedBody =>
      'Alles wat jy vasgelê het, is nog op hierdie foon. Dit stuur self sodra jy inteken.';

  @override
  String get sessionEndedSignIn => 'Teken in om dit te stuur';

  @override
  String get sessionEndedNotNow => 'Nie nou nie';

  @override
  String get sessionHeldWhatIsHeld => 'Wat word gehou';

  @override
  String sessionHeldEntry(int count, String kind) {
    return '$count × $kind';
  }

  @override
  String sessionHeldWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vasleggings wag om gestuur te word.',
      one: '1 vaslegging wag om gestuur te word.',
    );
    return '$_temp0';
  }

  @override
  String get torchTryAgain => 'Probeer weer';

  @override
  String get torchStillFetching => 'Haal steeds · dit is stadiger as gewoonlik';

  @override
  String get roleFieldAgent => 'Veldagent';

  @override
  String get territoriesTitle => 'Gebiede';

  @override
  String get territoriesFact =>
      '’n Gebied groepeer winkels en die agente wat hulle bewerk.';

  @override
  String get territoriesRefresh => 'Herlaai die gebiedelys';

  @override
  String get territoriesSectionAll => 'Alle gebiede';

  @override
  String get territoriesNew => 'Nuwe gebied';

  @override
  String get territoriesEmptyHeadline => 'Nog geen gebiede nie';

  @override
  String get territoriesEmptyBody =>
      '’n Gebied groepeer winkels en die agente wat hulle bewerk. Skep een en winkels kan daaraan toegeken word.';

  @override
  String territoryOutlets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count winkels',
      one: '1 winkel',
      zero: 'Geen winkels',
    );
    return '$_temp0';
  }

  @override
  String territoryAgents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count agente',
      one: '1 agent',
      zero: 'Geen agente',
    );
    return '$_temp0';
  }

  @override
  String get territoryCoveredWord => 'Gedek';

  @override
  String territoryCoveredPercent(int percent) {
    return '$percent% gedek';
  }

  @override
  String get territoryCoverageLoading => 'Dekking laai';

  @override
  String get territoryCoverageFailed => 'Dekking het nie gelaai nie';

  @override
  String get territoryCoverageNoOutlets => 'Nog geen winkels om te dek nie';

  @override
  String get territoryUnassigned => 'Nie toegeken nie';

  @override
  String get territoryUnassignedLine =>
      'Niemand bewerk hierdie gebied nog nie.';

  @override
  String get territoryCoverageCluster => 'Dekking vir hierdie gebied';

  @override
  String get territoryOutletsWord => 'Winkels';

  @override
  String get territoryAgentsWord => 'Agente';

  @override
  String territoryVisitedOf(int visited, int total) {
    return '$visited van $total besoek in hierdie venster';
  }

  @override
  String territoryVisitedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count besoek',
      one: '1 besoek',
      zero: 'Geen besoek',
    );
    return '$_temp0';
  }

  @override
  String get territoryOpenMap => 'Maak die kaart oop';

  @override
  String get territoryAssign => 'Ken ’n agent toe';

  @override
  String territoryAssignTitle(String territory) {
    return 'Ken toe aan $territory';
  }

  @override
  String get territoryAssignSubtitle =>
      'Kies ’n veldagent om hierdie gebied te bewerk.';

  @override
  String get territoryFieldAgents => 'Veldagente';

  @override
  String get territoryAgentPicked => 'Gekies';

  @override
  String get territoryAgentInactive => 'Nie meer aktief nie';

  @override
  String get territoryAssignBlocked => 'Kies eers ’n veldagent.';

  @override
  String get territoryAssignBack => 'Terug na dekking';

  @override
  String territoryAssignDone(String territory) {
    return 'Toegeken aan $territory.';
  }

  @override
  String get territoryAssignFailed =>
      'Daardie agent is nie toegeken nie. Niks het verander nie.';

  @override
  String get territoryNoAgentsHeadline => 'Nog geen veldagente nie';

  @override
  String get territoryNoAgentsBody =>
      'Voeg ’n veldagent onder Gebruikers by, en ken hom of haar dan hier toe.';

  @override
  String get territoryNewTitle => 'Nuwe gebied';

  @override
  String get territoryNewFact =>
      '’n Kode is wat die kantoor aanhaal. Dit moet uniek wees vir hierdie kliënt.';

  @override
  String get territoryBackToList => 'Terug na gebiede';

  @override
  String get territoryNameLabel => 'Naam';

  @override
  String get territoryNameHelp =>
      'Wat mense hierdie streek noem — Gauteng-Noord.';

  @override
  String get territoryCodeLabel => 'Kode';

  @override
  String get territoryCodeHelp =>
      'Die kort kode waaronder winkels geliasseer word — GP-N.';

  @override
  String get territoryRegionLabel => 'Streek';

  @override
  String get territoryRegionHelp => 'Opsioneel. Die wyer gebied waarin dit lê.';

  @override
  String get territoryFieldRequired => 'Dit is verpligtend.';

  @override
  String get territoryCreate => 'Skep gebied';

  @override
  String get territoryCreateBlocked =>
      '’n Naam en ’n kode is albei verpligtend.';

  @override
  String territoryCreated(String territory) {
    return '$territory geskep.';
  }

  @override
  String get territoryMapTitle => 'Gebiedskaart';

  @override
  String get territoryMapEmptyHeadline => 'Geen winkels in hierdie gebied nie';

  @override
  String get territoryMapEmptyBody =>
      'Winkels word onder ’n gebied geliasseer volgens sy kode. Gee ’n winkel hierdie gebied se kode en dit verskyn hier.';

  @override
  String territoryTilesOffBody(String territory) {
    return 'Die kaart het nie gelaai nie, so $territory word hieronder gelys. Elke winkel en sy toestand is daar.';
  }

  @override
  String get territoryOutletVisited => 'Besoek';

  @override
  String get territoryOutletNotVisited => 'Nog nie besoek nie';

  @override
  String get territoryOutletVisitedLine =>
      '’n Besoek het hier geland binne die dekkingsvenster.';

  @override
  String get territoryOutletNotVisitedLine =>
      'Geen besoek het hier geland binne die dekkingsvenster nie.';

  @override
  String get territoryOutletPosition => 'Vasgespeld by';

  @override
  String get territoryNotFoundHeadline => 'Ons kon nie daardie gebied kry nie';

  @override
  String get territoryNotFoundBody =>
      'Dit is dalk geskrap, of die skakel behoort aan ’n ander kliënt.';

  @override
  String get dispatchTitle => 'Versending';

  @override
  String get dispatchFact =>
      'Agente word eers binne-gebied gerangskik, daarna volgens afstand vanaf hul laas bekende ligging.';

  @override
  String get dispatchOutletSection => 'Die winkel';

  @override
  String get dispatchChooseOutlet => 'Kies ’n winkel';

  @override
  String get dispatchChooseOutletHint =>
      'Rangskikking het ’n bestemming nodig om afstand vandaan te meet.';

  @override
  String dispatchChangeOutlet(String outlet) {
    return 'Winkel: $outlet. Kies ’n ander een.';
  }

  @override
  String get dispatchNoOutletHeadline => 'Kies ’n winkel om agente te rangskik';

  @override
  String get dispatchNoOutletBody =>
      'Niemand kan gerangskik word voordat daar iets is om hulle teen te rangskik nie.';

  @override
  String get dispatchNoOutletsHeadline => 'Nog geen winkels nie';

  @override
  String get dispatchNoOutletsBody =>
      'Voeg ’n winkel by en dit kan versend word.';

  @override
  String get dispatchCandidatesSection => 'Kandidate';

  @override
  String get dispatchNoCandidatesHeadline =>
      'Geen agent kan gerangskik word nie';

  @override
  String get dispatchNoCandidatesBody =>
      'Rangskikking het agente nodig wat aan ’n gebied toegeken is, of ’n laas bekende ligging — nog geen van albei is aangeteken nie.';

  @override
  String get dispatchInTerritory => 'Binne gebied';

  @override
  String get dispatchOutsideTerritory => 'Buite gebied';

  @override
  String get dispatchRecommended => 'Aanbeveel';

  @override
  String dispatchMetresAway(int metres) {
    return '$metres m weg';
  }

  @override
  String get dispatchNoLocation => 'Geen laas bekende ligging nie';

  @override
  String get trendsTitle => 'Tendense';

  @override
  String get trendsFact => 'Bedienerkant-bakke — weke begin Maandag, UTC.';

  @override
  String get trendsFilters => 'Filters';

  @override
  String get trendsOverTime => 'Oor tyd';

  @override
  String get trendsCompare => 'Vergelyk gebiede';

  @override
  String get trendsDaily => 'Daagliks';

  @override
  String get trendsWeekly => 'Weekliks';

  @override
  String get trendsServerDefault => 'Bediener se verstek';

  @override
  String get trendsCustomRange => 'Eie reeks';

  @override
  String get trendsClearRange => 'Maak die reeks skoon';

  @override
  String get trendsViewAs => 'Wys as';

  @override
  String get trendsAsChart => 'Grafiek';

  @override
  String get trendsAsTable => 'Tabel';

  @override
  String get trendsPeriod => 'Tydperk';

  @override
  String get trendsNotMeasured => 'Nie gemeet nie';

  @override
  String get trendsDashed => 'gestippel';

  @override
  String get trendsScrubHint => 'Sleep oor die grafiek om een bak te lees.';

  @override
  String trendsChartHint(String name, int count) {
    return '$name, $count bakke. Die presiese syfers is in die tabelaansig.';
  }

  @override
  String trendsGapNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bakke nie gemeet nie',
      one: '1 bak nie gemeet nie',
    );
    return '$_temp0';
  }

  @override
  String get trendsEmptyHeadline => 'Geen data in die reeks nie';

  @override
  String get trendsEmptyBody =>
      'Tendense vul in soos besoeke ingedien en bepunt word.';

  @override
  String get trendScorecards => 'Telkaart-tendens';

  @override
  String get trendScorecardsSeries => 'Geweegde uitvoeringstelling';

  @override
  String get trendAvailability => 'Beskikbaarheidstendens';

  @override
  String get trendAvailabilitySeries => 'Beskikbaarheid op rak';

  @override
  String get trendPerfectStore => 'Perfekte-winkel-tendens';

  @override
  String get trendPerfectStoreSeries => 'Winkels wat elke hek slaag';

  @override
  String get trendsMetric => 'Maatstaf';

  @override
  String get trendsMetricScore => 'Telling';

  @override
  String get trendsMetricPerfectStore => 'Perfekte winkel';

  @override
  String get trendsMetricAvailability => 'Beskikbaarheid';

  @override
  String get trendsMetricShareOfShelf => 'Rakaandeel';

  @override
  String get trendsClientAverage => 'Kliëntgemiddeld';

  @override
  String get trendsTarget => 'Teiken';

  @override
  String trendsUnassignedNote(String samples) {
    return 'Sluit ook $samples in van winkels buite elke gebied.';
  }

  @override
  String get trendsNoTerritoriesHeadline => 'Geen gebiede opgestel nie';

  @override
  String get trendsNoTerritoriesBody =>
      'Voeg gebiede by en elkeen kan teen die kliëntgemiddeld gelees word.';

  @override
  String get trendsCompareEmptyBody =>
      'Die vergelyking vul in soos besoeke ingedien en bepunt word.';

  @override
  String get trendsAboveAverage => 'Bo gemiddeld';

  @override
  String get trendsBelowAverage => 'Onder gemiddeld';

  @override
  String get trendsAtAverage => 'Op gemiddeld';

  @override
  String trendsAboveBy(String points, String samples) {
    return '$points punte bo die kliëntgemiddeld · $samples';
  }

  @override
  String trendsBelowBy(String points, String samples) {
    return '$points punte onder die kliëntgemiddeld · $samples';
  }

  @override
  String trendsLevelWith(String samples) {
    return 'Gelyk met die kliëntgemiddeld · $samples';
  }

  @override
  String get trendsSmallSample => 'Klein steekproef';

  @override
  String trendsTooFewToCompare(String samples) {
    return 'Te min om te vergelyk · $samples';
  }

  @override
  String get trendsNothingMeasuredHere => 'Niks gemeet in hierdie venster nie';

  @override
  String trendsRank(int rank) {
    return 'Gerangskik $rank';
  }

  @override
  String get trendsUnranked => 'Nie gerangskik nie';

  @override
  String get trendsShowing => 'Wys tans';

  @override
  String trendsAgainstClient(String territory) {
    return '$territory teen die kliëntgemiddeld';
  }

  @override
  String trendsMeterHint(String territory, int value, int average) {
    return '$territory: $value, kliëntgemiddeld $average';
  }

  @override
  String trendsSamplesScorecards(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count telkaarte',
      one: '1 telkaart',
    );
    return '$_temp0';
  }

  @override
  String trendsSamplesStockLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voorraadlyne',
      one: '1 voorraadlyn',
    );
    return '$_temp0';
  }

  @override
  String trendsSamplesFacings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count besoeke met rakfronte',
      one: '1 besoek met rakfronte',
    );
    return '$_temp0';
  }

  @override
  String get outletsTitle => 'Winkels';

  @override
  String get outletsSubtitle =>
      '’n Winkel sonder koördinate kan nie omhein word nie.';

  @override
  String get outletsRefresh => 'Herlaai die winkellys';

  @override
  String get outletsCreateStore => 'Voeg ’n winkel by';

  @override
  String get outletsSectionHeading => 'Winkels';

  @override
  String get outletsNoLocation => 'Geen ligging';

  @override
  String get outletsNoCoordinates => 'Geen koördinate op rekord nie';

  @override
  String get outletsPlaced => 'Geplaas';

  @override
  String get outletsEmptyHeadline => 'Nog geen winkels nie.';

  @override
  String get outletsEmptyBody =>
      'Voeg ’n winkel by om dit op ’n besoekplan te sit.';

  @override
  String get outletsLoadErrorHeadline => 'Die winkellys het nie gelaai nie.';

  @override
  String get outletsRetry => 'Probeer weer';

  @override
  String get outletsPinReportsHeading => 'Oop pen-verslae';

  @override
  String get outletsPinReportsNote =>
      'Agente wat nie kon inklok waar die pen sê die winkel is nie.';

  @override
  String get outletsPinReported => 'Pen aangemeld';

  @override
  String outletsPinReportStood(String agent, String distance) {
    return '$agent het $distance daarvandaan gestaan';
  }

  @override
  String get outletDetailTitle => 'Winkel';

  @override
  String get outletDetailBack => 'Terug na winkels';

  @override
  String get outletDetailLoadErrorHeadline =>
      'Hierdie winkel het nie gelaai nie.';

  @override
  String outletDetailDisputesHeadline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count agente het hierdie pen as verkeerd aangemeld',
      one: 'Een agent het hierdie pen as verkeerd aangemeld',
    );
    return '$_temp0';
  }

  @override
  String get outletDetailDisputesBody =>
      'Elkeen van hulle het in elk geval ingeklok, is gemerk, en die besoek is op die hersieningslys. Om die pen reg te stel sluit die verslag; om te stoor sonder om dit te skuif teken aan dat jy gekyk het en die pen bly staan.';

  @override
  String get outletDetailFormHeading => 'Hierdie winkel';

  @override
  String get outletFieldName => 'Winkelnaam';

  @override
  String get outletFieldCode => 'Winkelkode';

  @override
  String get outletFieldChannel => 'Kanaaltipe';

  @override
  String get outletFieldChannelHelp =>
      'Byvoorbeeld: supermark, spaza, vulstasiewinkel.';

  @override
  String get outletFieldTerritory => 'Gebied';

  @override
  String get outletFieldLatitude => 'Breedtegraad';

  @override
  String get outletFieldLongitude => 'Lengtegraad';

  @override
  String get outletFieldLatitudeHelp =>
      'Tussen -90 en 90. Johannesburg is omtrent -26,2.';

  @override
  String get outletFieldLongitudeHelp =>
      'Tussen -180 en 180. Johannesburg is omtrent 28,0.';

  @override
  String get outletFieldStatus => 'Status';

  @override
  String get outletStatusActive => 'Aktief';

  @override
  String get outletStatusClosed => 'Gesluit';

  @override
  String get outletStatusClosedConsequence =>
      'Word uit beplanning gehou. Inklok werk steeds — ’n agent by die deur moet kan werk.';

  @override
  String get outletStatusActiveConsequence => 'Word soos gewoonlik beplan.';

  @override
  String get outletRequired => 'Verpligtend';

  @override
  String get outletCoordinateNotANumber =>
      'Tik ’n getal in, byvoorbeeld -26,2041';

  @override
  String get outletLatitudeOutOfRange => '’n Breedtegraad is tussen -90 en 90';

  @override
  String get outletLongitudeOutOfRange =>
      '’n Lengtegraad is tussen -180 en 180';

  @override
  String get outletSave => 'Stoor';

  @override
  String get outletSaveBlocked =>
      'Vul eers die winkel se naam en albei koördinate in.';

  @override
  String get outletSaved => 'Winkel bygewerk.';

  @override
  String get outletSaveFailed =>
      'Daardie winkel is nie gestoor nie. Dit is onveranderd.';

  @override
  String get outletUsingAttempt =>
      'Gebruik ’n agent se aangetekende posisie. Die bediener lees die koördinate uit daardie inklok self.';

  @override
  String get outletAttemptsHeading => 'Afgekeurde inklokke';

  @override
  String get outletAttemptsNote =>
      'Waar agente werklik was toe hierdie winkel hulle weggewys het.';

  @override
  String get outletAttemptsEmptyHeadline => 'Geen afgekeurde inklokke nie.';

  @override
  String get outletAttemptsEmptyBody =>
      'Niemand is deur hierdie pen weggewys nie.';

  @override
  String outletAttemptSubtitle(String distance, String agent) {
    return '$distance daarvandaan · $agent';
  }

  @override
  String get outletUseThisPosition => 'Gebruik hierdie posisie';

  @override
  String get outletUseTheirPosition => 'Gebruik hul posisie';

  @override
  String get outletFixMocked =>
      'Die toestel het hierdie posisie as ’n vals ligging aangemeld. Dit kan nie hierdie winkel se pen word nie.';

  @override
  String get outletFixUnknown =>
      'Die toestel het nie gesê hoe akkuraat hierdie posisie was nie.';

  @override
  String outletFixCoarse(String metres) {
    return 'Akkuraat tot ongeveer $metres m — te grof om ’n pen mee te stel.';
  }

  @override
  String outletFixGood(String metres) {
    return 'Akkuraat tot ongeveer $metres m.';
  }

  @override
  String get outletDisputesHeading => 'Pen-verslae';

  @override
  String outletDisputeStood(String position, String distance, String pin) {
    return 'Het by $position gestaan — $distance van die pen af, wat toe $pin gelees het.';
  }

  @override
  String get outletDisputeSoleVisitor =>
      'Geen ander agent het hierdie winkel al besoek nie, so niemand anders se inklokke kan met ’n pen wat hierheen geskuif is verskil nie.';

  @override
  String get outletDisputeOpen => 'Oop';

  @override
  String get outletDisputeAnswering =>
      'Antwoord hierdie verslag wanneer jy stoor.';

  @override
  String get outletDisputeAnswer => 'Antwoord hierdie verslag';

  @override
  String outletDisputeApplied(String who) {
    return 'Toegepas deur $who';
  }

  @override
  String outletDisputeRejected(String who) {
    return 'Verwerp deur $who';
  }

  @override
  String get outletDisputeResolvedByManager => '’n bestuurder';

  @override
  String get outletPhotoCamera => 'Met die kamera geneem';

  @override
  String get outletPhotoGallery => 'Uit die galery gekies';

  @override
  String get outletPhotoUnknownSource => 'Bron nie aangeteken nie';

  @override
  String outletPhotoPhoneSaid(String when) {
    return 'Foon het $when gesê';
  }

  @override
  String outletPhotoReceived(String when) {
    return 'Ontvang $when';
  }

  @override
  String outletDisputePhotoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count winkelfront-fotos aangeheg',
      one: '1 winkelfront-foto aangeheg',
    );
    return '$_temp0';
  }

  @override
  String get outletPhotoAlt => 'Winkelfront-foto uit hierdie pen-verslag';

  @override
  String get outletPhotoMissing => 'Daardie foto het nie gelaai nie.';

  @override
  String get outletChangesHeading => 'Veranderingsgeskiedenis';

  @override
  String outletChangePinMoved(String before, String after) {
    return 'Pen geskuif van $before na $after';
  }

  @override
  String get outletChangePinFromAgent =>
      'vanaf ’n agent se aangetekende posisie';

  @override
  String outletChangeRenamed(String before, String after) {
    return 'Hernoem van “$before” na “$after”';
  }

  @override
  String outletChangeStatus(String before, String after) {
    return 'Status $before na $after';
  }

  @override
  String get outletChangeOther => 'Verander';

  @override
  String get outletChangeUnknownCoordinate => 'nie aangeteken nie';

  @override
  String get createOutletTitle => 'Voeg ’n winkel by';

  @override
  String get createOutletBack => 'Terug na winkels';

  @override
  String get createOutletSubmit => 'Voeg die winkel by';

  @override
  String get createOutletBlocked =>
      'Vul eers die naam, kode, kanaal, gebied en albei koördinate in.';

  @override
  String get createOutletFailed =>
      'Daardie winkel is nie geskep nie. Niks is gestoor nie.';

  @override
  String get createOutletLocationHeading => 'Waar hierdie winkel is';

  @override
  String get createOutletLocating => 'Soek waar hierdie foon is…';

  @override
  String get createOutletLocationDenied =>
      'Hierdie foon wil nie sê waar dit is nie. Tik eerder die winkel se koördinate in.';

  @override
  String get createOutletLocationFailed =>
      'Hierdie foon kon nie vind waar dit is nie. Tik eerder die winkel se koördinate in.';

  @override
  String get createOutletLocationFound =>
      'Vanaf hierdie foon ingevul. Tik daaroor as jy nie in die winkel staan nie.';

  @override
  String get createOutletUseThisPhone => 'Gebruik hierdie foon se posisie';

  @override
  String get createOutletTerritoriesLoading => 'Laai gebiede…';

  @override
  String get createOutletTerritoriesFailed =>
      'Die gebiedelys het nie gelaai nie.';

  @override
  String get createOutletTerritoriesRetry => 'Probeer weer';

  @override
  String get createOutletNoTerritories =>
      'Nog geen gebiede nie — skep eers een onder Gebiede.';

  @override
  String get createOutletTerritoryNotChosen => 'Kies ’n gebied';

  @override
  String get ordersTitle => 'Bestellings';

  @override
  String get ordersSubtitle =>
      'In die veld vasgelê. ’n Ingedienede bestelling wag op ’n besluit.';

  @override
  String get ordersRefresh => 'Herlaai die bestellingslys';

  @override
  String get ordersSectionHeading => 'Bestellings';

  @override
  String get ordersNewOrder => 'Nuwe bestelling';

  @override
  String get ordersAwaitingEyebrow => 'Wag op ’n besluit';

  @override
  String ordersAwaitingSubordinates(String confirmed, String cancelled) {
    return '$confirmed bevestig · $cancelled gekanselleer';
  }

  @override
  String get ordersValueEyebrow => 'Waarde van hierdie bestellings';

  @override
  String ordersValuePartial(String shown) {
    return 'Opgetel oor die $shown bestellings wat gelaai is, nie die hele geskiedenis nie.';
  }

  @override
  String ordersCountPartial(String shown) {
    return 'Ten minste soveel: getel oor die $shown bestellings wat gelaai is.';
  }

  @override
  String get ordersStatusSubmitted => 'Ingedien';

  @override
  String get ordersStatusConfirmed => 'Bevestig';

  @override
  String get ordersStatusCancelled => 'Gekanselleer';

  @override
  String ordersStatusOther(String status) {
    return 'Status $status';
  }

  @override
  String ordersLineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reëls',
      one: '1 reël',
    );
    return '$_temp0';
  }

  @override
  String ordersRowSubtitle(String status, String lines) {
    return '$status · $lines';
  }

  @override
  String get ordersUnknownStore => 'Winkel nie op hierdie lys nie';

  @override
  String get ordersEmptyHeadline => 'Nog geen bestellings nie.';

  @override
  String get ordersEmptyBody =>
      'Bestellings verskyn hier soos agente dit tydens ’n besoek vaslê.';

  @override
  String get ordersLoadErrorHeadline =>
      'Die bestellingslys het nie gelaai nie.';

  @override
  String get ordersRetry => 'Probeer weer';

  @override
  String ordersFooterMore(String shown) {
    return 'Wys die eerste $shown. Daar is meer.';
  }

  @override
  String ordersFooterOf(String shown, String total) {
    return 'Wys die $shown nuutstes van $total bestellings.';
  }

  @override
  String ordersFooterScope(String shown) {
    return 'Die syfers hierbo is van hierdie $shown.';
  }

  @override
  String get orderFormTitle => 'Nuwe bestelling';

  @override
  String get orderFormBack => 'Terug na bestellings';

  @override
  String get orderFormStoreHeading => 'Watter winkel';

  @override
  String get orderFormStore => 'Winkel';

  @override
  String get orderFormStoreNotChosen =>
      'Nog nie gekies nie. ’n Winkel bepaal wat bestel kan word.';

  @override
  String get orderFormStoresFailed => 'Die winkellys het nie gelaai nie.';

  @override
  String get orderFormLinesHeading => 'Bestellingsreëls';

  @override
  String get orderFormPickStoreFirst =>
      'Kies ’n winkel om te sien wat dit aanhou.';

  @override
  String get orderFormSkusFailed =>
      'Daardie winkel se produkte het nie gelaai nie.';

  @override
  String get orderFormNoSkusHeadline => 'Niks word hier aangehou nie.';

  @override
  String get orderFormNoSkusBody =>
      'Hierdie winkel het geen produkte op sy lys nie, so daar is niks om te bestel nie.';

  @override
  String get orderFormTotal => 'Bestellingstotaal';

  @override
  String get orderFormSubmit => 'Skep die bestelling';

  @override
  String get orderFormBlocked =>
      'Kies eers ’n winkel en stel ’n hoeveelheid op ten minste een reël.';

  @override
  String get orderFormFailed =>
      'Daardie bestelling is nie geskep nie. Niks is gestuur nie.';

  @override
  String get orderFormQuantity => 'Hoeveelheid';

  @override
  String get orderFormOneFewer => 'Een minder';

  @override
  String get orderFormOneMore => 'Een meer';

  @override
  String get orderFormTypeQuantity => 'Tik ’n hoeveelheid';

  @override
  String get orderFormTypeQuantityFirst => 'Tik eers ’n hoeveelheid in.';

  @override
  String get orderFormNotOrdered => 'Nie op hierdie bestelling nie';

  @override
  String get orderFormNoneOrdered => 'Niks hiervan nie';

  @override
  String get orderFormNoneOrderedLine => '’n Reël op nul word nie gestuur nie.';

  @override
  String get orderFormCancel => 'Kanselleer';

  @override
  String get orderFormSet => 'Stel';

  @override
  String get beatPlansTitle => 'Besoekplanne';

  @override
  String get beatPlansSubtitle =>
      '’n Plan is ’n dag se winkelstoppe, in besoekvolgorde.';

  @override
  String get beatPlansRefresh => 'Herlaai die besoekplanne';

  @override
  String get beatPlansSectionHeading => 'Planne';

  @override
  String get beatPlansNewPlan => 'Nuwe plan';

  @override
  String get beatPlansEmptyHeadline => 'Geen besoekplanne nie.';

  @override
  String get beatPlansEmptyBody =>
      '’n Plan is ’n dag se winkelstoppe in besoekvolgorde. Bou een om ’n agent ’n roete te gee.';

  @override
  String get beatPlansLoadErrorHeadline =>
      'Die besoekplanne het nie gelaai nie.';

  @override
  String get beatPlansRetry => 'Probeer weer';

  @override
  String beatPlansFooterMore(String shown) {
    return 'Wys die eerste $shown. Daar is meer.';
  }

  @override
  String beatPlansFooterOf(String shown, String total) {
    return 'Wys $shown van $total planne.';
  }

  @override
  String get beatPlanStatusScheduled => 'Geskeduleer';

  @override
  String get beatPlanStatusInProgress => 'Aan die gang';

  @override
  String get beatPlanStatusCompleted => 'Voltooi';

  @override
  String get beatPlanStatusMissed => 'Gemis';

  @override
  String get beatPlanStatusCancelled => 'Gekanselleer';

  @override
  String beatPlanStatusOther(String status) {
    return 'Status $status';
  }

  @override
  String get beatPlanDetailTitle => 'Besoekplan';

  @override
  String get beatPlanDetailBack => 'Terug na besoekplanne';

  @override
  String get beatPlanDetailLoadErrorHeadline =>
      'Hierdie besoekplan het nie gelaai nie.';

  @override
  String get beatPlanAdherenceEyebrow => 'Stoppe gewerk';

  @override
  String beatPlanAdherenceOf(String visited, String total) {
    return '$visited van $total stoppe';
  }

  @override
  String get beatPlanAdherenceNoStops =>
      'Hierdie plan het geen stoppe nie, so daar is niks om te werk nie.';

  @override
  String get beatPlanStopsHeading => 'Stoppe';

  @override
  String get beatPlanStopsEmptyHeadline => 'Geen stoppe op hierdie plan nie.';

  @override
  String get beatPlanStopsEmptyBody =>
      'Voeg winkels by die plan om die agent ’n roete te gee.';

  @override
  String beatPlanStopLabel(String sequence) {
    return 'Stop $sequence';
  }

  @override
  String get beatPlanStopVisited => 'Gewerk';

  @override
  String get beatPlanStopNotVisited => 'Nog nie';

  @override
  String beatPlanStopToggle(String stop) {
    return 'Merk $stop as gewerk';
  }

  @override
  String get beatPlanStopFailed =>
      'Daardie stop is nie verander nie. Dit is soos dit was.';

  @override
  String get beatPlanFormTitle => 'Nuwe besoekplan';

  @override
  String get beatPlanFormBack => 'Terug na besoekplanne';

  @override
  String get beatPlanFormPlanHeading => 'Die dag';

  @override
  String get beatPlanFormName => 'Plannaam';

  @override
  String get beatPlanFormNameHelp => 'Wat die agent bo-aan hul dag sal sien.';

  @override
  String get beatPlanFormDate => 'Geskeduleerde datum';

  @override
  String get beatPlanFormDateNotChosen => 'Nog nie gekies nie.';

  @override
  String get beatPlanFormPickDate => 'Kies ’n datum';

  @override
  String get beatPlanFormChangeDate => 'Verander die datum';

  @override
  String get beatPlanFormAgent => 'Veldagent';

  @override
  String get beatPlanFormAgentNotChosen =>
      'Nog nie gekies nie. ’n Plan behoort aan een agent.';

  @override
  String get beatPlanFormAgentsFailed => 'Die agentelys het nie gelaai nie.';

  @override
  String get beatPlanFormNoAgents =>
      'Nog geen veldagente op hierdie rekening nie.';

  @override
  String get beatPlanFormTerritory => 'Gebied';

  @override
  String get beatPlanFormTerritoryOptional =>
      'Opsioneel. Dit vernou verslagdoening, nie die stoppe nie.';

  @override
  String get beatPlanFormTerritoryNone => 'Geen gebied';

  @override
  String get beatPlanFormStopsHeading => 'Stoppe, in volgorde';

  @override
  String get beatPlanFormStopsEmpty =>
      'Nog geen stoppe nie. Voeg winkels uit die lys hieronder by.';

  @override
  String get beatPlanFormAvailableHeading => 'Winkels om by te voeg';

  @override
  String get beatPlanFormAvailableEmpty =>
      'Elke winkel is reeds op hierdie plan.';

  @override
  String get beatPlanFormStoresFailed => 'Die winkellys het nie gelaai nie.';

  @override
  String beatPlanFormAddStop(String store) {
    return 'Voeg $store by die plan';
  }

  @override
  String beatPlanFormRemoveStop(String store) {
    return 'Haal $store van die plan af';
  }

  @override
  String beatPlanFormMoveUp(String store) {
    return 'Skuif $store vroeër';
  }

  @override
  String beatPlanFormMoveDown(String store) {
    return 'Skuif $store later';
  }

  @override
  String beatPlanFormStopCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stoppe',
      one: '1 stop',
      zero: 'Geen stoppe',
    );
    return '$_temp0';
  }

  @override
  String get beatPlanFormSubmit => 'Skep die plan';

  @override
  String get beatPlanFormBlocked =>
      'Benoem die plan, kies ’n datum en ’n agent, en voeg eers ten minste een stop by.';

  @override
  String get beatPlanFormFailed =>
      'Daardie plan is nie geskep nie. Niks is gestoor nie.';

  @override
  String get salesTargetsTitle => 'Verkoopsteikens';

  @override
  String get salesTargetsSubtitle =>
      'Eenhede wat deur TradeIQ bestel is, nie wat kopers gekoop het nie.';

  @override
  String get salesSellIn => 'Inverkope (bestellings)';

  @override
  String get salesTargetsHelp =>
      'Stel een teiken per SKU vir die hele rekening, ’n gebied, of ’n enkele winkel.';

  @override
  String get salesTargetsUpload => 'Laai ’n CSV van teikens op';

  @override
  String salesMonthPrevious(String month) {
    return 'Die maand voor $month';
  }

  @override
  String salesMonthNext(String month) {
    return 'Die maand na $month';
  }

  @override
  String salesTimeZone(String zone) {
    return 'Plaaslike dae in $zone';
  }

  @override
  String get salesLevelsHeading => 'Teenoor teiken';

  @override
  String get salesLevelAccount => 'Rekeningwyd';

  @override
  String get salesLevelTerritories => 'Gebiede';

  @override
  String get salesLevelOutlets => 'Winkels';

  @override
  String get salesLevelNoTargets =>
      'Geen teiken is op hierdie vlak gestel nie, so daar is niks om te behaal nie.';

  @override
  String get salesLevelZeroTarget =>
      'Elke teiken op hierdie vlak is 0 eenhede, so daar is niks om te behaal nie.';

  @override
  String get salesLevelAttainmentUnknown =>
      'Die persentasie van teiken is nie vir hierdie vlak uitgewerk nie.';

  @override
  String salesLevelSubordinates(String actual, String target, int targets) {
    String _temp0 = intl.Intl.pluralLogic(
      targets,
      locale: localeName,
      other: '$targets teikens',
      one: '1 teiken',
    );
    return '$actual van $target eenhede · $_temp0';
  }

  @override
  String get salesBandOnTarget => 'Op teiken';

  @override
  String get salesBandClose => 'Naby';

  @override
  String get salesBandBehind => 'Agter';

  @override
  String get salesNoTarget => 'Geen teiken';

  @override
  String get salesZeroTarget => 'Teiken van 0 eenhede';

  @override
  String salesNoTargetsHeadline(String month) {
    return 'Geen teikens vir $month nie.';
  }

  @override
  String get salesNoTargetsBody =>
      'Stel ’n teiken op ’n SKU hieronder, of laai ’n CSV van teikens op.';

  @override
  String get salesSkusHeading => 'SKU’s';

  @override
  String salesSkusTruncated(String shown) {
    return 'Wys die eerste $shown.';
  }

  @override
  String get salesSkusEmptyHeadline => 'Geen SKU’s op hierdie rekening nie.';

  @override
  String get salesSkusEmptyBody =>
      'Teikens word per SKU gestel, so daar is nog niks om een op te stel nie.';

  @override
  String salesRowFigures(String metric, String actual, String target) {
    return '$metric $actual · teiken $target eenhede';
  }

  @override
  String salesRowNoTargetFigures(String metric, String actual) {
    return '$metric $actual · geen teiken gestel nie';
  }

  @override
  String get salesScopeTerritory => 'Gebied';

  @override
  String get salesScopeOutlet => 'Winkel';

  @override
  String get salesScopeAccount => 'Hele rekening';

  @override
  String get salesScopeUnknown => 'Omvang nie op hierdie lys nie';

  @override
  String salesScopedRowTitle(String sku, String scope) {
    return '$sku · $scope';
  }

  @override
  String get salesSetTarget => 'Stel ’n teiken';

  @override
  String get salesEditTarget => 'Wysig die teiken';

  @override
  String get salesRemoveTarget => 'Verwyder die teiken';

  @override
  String get salesRemoveFailed =>
      'Daardie teiken is nie verwyder nie. Dit is steeds gestel.';

  @override
  String get salesTargetSheetSet => 'Stel ’n verkoopsteiken';

  @override
  String get salesTargetSheetEdit => 'Wysig ’n verkoopsteiken';

  @override
  String salesTargetSheetSubtitle(String metric, String month) {
    return 'Eenhede van $metric vir $month.';
  }

  @override
  String get salesTargetSku => 'SKU';

  @override
  String get salesTargetSkuNotChosen =>
      'Nog nie gekies nie. ’n Teiken behoort aan een SKU.';

  @override
  String get salesTargetSkuLocked =>
      '’n Teiken word deur sy SKU geïdentifiseer, so ’n wysiging kan dit nie skuif nie.';

  @override
  String get salesTargetScope => 'Geld vir';

  @override
  String get salesTargetScopeLocked =>
      '’n Teiken word deur sy omvang geïdentifiseer, so ’n wysiging kan dit nie skuif nie.';

  @override
  String get salesTargetScopeAccountConsequence =>
      'Elke winkel op die rekening tel daartoe by.';

  @override
  String get salesTargetScopeTerritoryConsequence =>
      'Net winkels in die gekose gebied tel.';

  @override
  String get salesTargetScopeOutletConsequence => 'Net die gekose winkel tel.';

  @override
  String get salesTargetTerritoryNotChosen =>
      'Nog nie gekies nie. ’n Gebiedsteiken benodig een.';

  @override
  String get salesTargetOutletNotChosen =>
      'Nog nie gekies nie. ’n Winkelteiken benodig een.';

  @override
  String get salesTargetUnits => 'Teikeneenhede';

  @override
  String get salesTargetUnitsHelp => '’n Heelgetal eenhede, vir die maand.';

  @override
  String get salesTargetUnitsMissing => 'Tik ’n heelgetal eenhede in.';

  @override
  String get salesTargetSave => 'Stoor die teiken';

  @override
  String get salesTargetBlocked =>
      'Kies ’n SKU en ’n omvang, en tik ’n heelgetal eenhede in.';

  @override
  String get salesTargetCancel => 'Kanselleer';

  @override
  String get salesTargetsLoadErrorHeadline => 'Die teikens het nie gelaai nie.';

  @override
  String get salesTargetsRetry => 'Probeer weer';

  @override
  String get salesImportTitle => 'Laai verkoopsteikens op';

  @override
  String get salesImportSubtitle =>
      'Sien vooraf wat ’n lêer sou doen, en pas dan die goeie reëls toe.';

  @override
  String get salesImportFormat =>
      'Dit benodig ’n opskrifreël: month (YYYY-MM), sku (id of naam), targetUnits, en opsioneel territory of outlet (id of kode). Bestaande teikens vir dieselfde SKU, maand en omvang word vervang.';

  @override
  String get salesImportChooseFile => 'Kies ’n CSV-lêer';

  @override
  String get salesImportChooseAnother => 'Kies ’n ander lêer';

  @override
  String get salesImportRemoveFile => 'Verwyder die lêer';

  @override
  String get salesImportPasteLabel => 'Of plak ’n CSV';

  @override
  String get salesImportPasteHint => 'month,sku,targetUnits,territory,outlet';

  @override
  String get salesImportFileHeld =>
      'Sien vooraf wat hierdie lêer sou doen. Verwyder dit om eerder ’n CSV te plak.';

  @override
  String get salesImportFileUnreadable =>
      'Daardie lêer kon nie gelees word nie.';

  @override
  String get salesImportPreview => 'Sien vooraf';

  @override
  String get salesImportApply => 'Pas toe';

  @override
  String salesImportApplyRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Pas $count reëls toe',
      one: 'Pas 1 reël toe',
    );
    return '$_temp0';
  }

  @override
  String get salesImportBlockedPreview =>
      'Sien eers die lêer vooraf. Wat geskryf word is altyd wat gewys is.';

  @override
  String get salesImportBlockedNoRows =>
      'Geen reël in hierdie lêer kan geskryf word nie.';

  @override
  String get salesImportReadyEyebrow => 'Reëls gereed om te skryf';

  @override
  String get salesImportErrorsEyebrow => 'Reëls met foute';

  @override
  String salesImportWouldDo(String created, String updated) {
    return 'Sou $created skep en $updated bywerk.';
  }

  @override
  String get salesImportErrorsHeading => 'Wat verkeerd is';

  @override
  String salesImportRowError(String row, String message) {
    return 'Reël $row: $message';
  }

  @override
  String salesImportRowErrorColumn(String row, String column, String message) {
    return 'Reël $row · $column: $message';
  }

  @override
  String salesImportMoreErrors(String count) {
    return '…en nog $count.';
  }

  @override
  String get salesImportNothingWrong =>
      'Elke reël in hierdie lêer kan geskryf word.';

  @override
  String salesImportApplied(String created, String updated) {
    return '$created geskep, $updated bygewerk.';
  }

  @override
  String salesImportAppliedSkipped(
    String created,
    String updated,
    String skipped,
  ) {
    return '$created geskep, $updated bygewerk, $skipped reëls oorgeslaan.';
  }

  @override
  String get salesPanelTitle => 'Inverkope teenoor teiken';

  @override
  String salesPanelSubtitle(String metric, String month) {
    return '$metric · $month — nie verbruikersverkope nie';
  }

  @override
  String get salesPanelThisMonth => 'hierdie maand';

  @override
  String get salesPanelLink => 'Teikens';

  @override
  String get salesPanelEmptyBody =>
      'Stel maandelikse SKU-teikens onder Verkoopsteikens om inverkope daarteen te volg.';
}
