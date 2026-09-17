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
  String get captureButton => 'Neem foto';

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
      'Jou bestuurder het nog nie ’n roeteplan vir vandag opgestel nie. Jy kan steeds ’n winkel besoek — kies dit self.';

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
  String get myWorkTitle => 'Jou werk';

  @override
  String get myWorkSubtitle => 'Wat op hierdie foon is, en wat gestuur is';

  @override
  String get myWorkSyncNow => 'Probeer nou stuur';

  @override
  String get myWorkLoadErrorTitle => 'Kon nie jou werk lees nie';

  @override
  String get myWorkNeedsYouHeading => 'Het jou nodig';

  @override
  String get myWorkWaitingHeading => 'Wag om te stuur';

  @override
  String get myWorkSentHeading => 'Gestuur';

  @override
  String get myWorkEmpty => 'Nog niks vasgelê nie';

  @override
  String get myWorkFooter =>
      'Vasleggings stuur vanself wanneer jy sein het — jy hoef nooit te onthou om dit te doen nie. Niks hier raak ooit verlore nie.';

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
      'Doen die afdelings in enige volgorde — die winkel laat jou nie altyd toe om een te volg nie. Alles stoor soos jy gaan, selfs sonder sein.';

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
      'Jy moet binne 50 m van die winkel wees om aan te meld. Dit is wat bewys dat die besoek plaasgevind het.';

  @override
  String get visitRetry => 'Probeer weer';

  @override
  String get visitBackToRoute => 'Terug na roete';

  @override
  String get visitTooFarTitle => 'Jy’s te ver weg';

  @override
  String get visitTooFarBody =>
      'Gaan nader aan die winkel en probeer weer. Niks is verlore nie — die besoek het nog nie begin nie.';

  @override
  String visitTooFarDistance(int meters) {
    return '$meters m weg · moet 50 m of nader wees';
  }

  @override
  String get visitTooFarFraudNote =>
      'Hierdie poging word aangeteken. Om van ver af weer te probeer is self ’n bedrogsein, so dit is beter om nader te stap as om aan te hou tik.';

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
      'Kyk dit na voordat dit na jou bestuurder gaan. Nadat jy dit ingedien het, kan jy dit nie meer verander nie.';

  @override
  String get submitWillRaiseHeading => 'Dit skep hierdie take';

  @override
  String submitAccusation(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Jy sê vir die bestuurder $count dinge is verkeerd in hierdie winkel. Dit kom almal uit wat jy vasgelê het — niks word agterna bygevoeg nie. As die bestuurder een hiervan reeds oop het, word dit nie twee keer geskep nie.',
      one:
          'Jy sê vir die bestuurder een ding is verkeerd in hierdie winkel. Dit kom uit wat jy vasgelê het — niks word agterna bygevoeg nie. As die bestuurder dit reeds oop het, word dit nie twee keer geskep nie.',
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
      'Niks om te skep nie. Jy het niks uit voorraad gekry nie en geen risiko’s gemerk nie — hierdie winkel is in goeie toestand.';

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
      'Kon nie nou die bediener bereik nie — dit sal self stuur sodra jy sein het. Jy kan die app toemaak.';

  @override
  String get outcomeHeldBodyNoSignal =>
      'Daar is nou geen sein nie — dit sal self stuur sodra jy sein het. Jy kan die app toemaak.';

  @override
  String get outcomeScoredWhenSends => 'Word getel sodra dit stuur';

  @override
  String get outcomeScoredOnServer =>
      'Jou telling word op die bediener uitgewerk, nie op die foon nie';

  @override
  String get outcomeNoGuess =>
      'Ons raai nie hier ’n telling nie. Jy sien die regte een — dieselfde een wat jou bestuurder sien — sodra dit die bediener bereik.';

  @override
  String outcomeRatingBand(String band) {
    String _temp0 = intl.Intl.selectLogic(band, {
      'green': 'Groen',
      'amber': 'Oranje',
      'other': 'Rooi',
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
      'Geen mededinger op die rak om teen te meet nie — dit tel nie teen jou nie.';

  @override
  String get outcomeUnmeasurableSalesCapability =>
      'Geen personeel aan diens om te beoordeel nie — dit tel nie teen jou nie.';

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
      'Opsioneel. Word gestoor as bewys vir hierdie afdeling en as opleidingsdata vir outomatiese planogram-telling.';

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
      'Opsioneel. Pryse word steeds met die hand ingevoer — dit is bewys, en die opleidingsdata vir outomatiese pryslees.';

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
  String get s8FlagTypeHint => 'Wat uitgewys is';

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
      'Risiko’s wat in S8 gemerk is, skep outomaties take met ’n SLA op die bediener. Voeg enige ekstra take hieronder by.';

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
      'Dit het te lank geneem om jou ligging te kry. Maak seker dat ligging vir TradeIQ aangeskakel is, en probeer dan weer.';

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
      'Ekstra vrae wat hierdie kliënt by elke besoek vra. Beantwoord die verpligte vrae voor jy indien.';

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
    return 'Terwyl TradeIQ oop is en jy ingeteken is, stuur dit $_temp0 jou foon se ligging na jou bestuurder, sodat hulle kan sien by watter winkel jy is. Dit stop wanneer jy TradeIQ toemaak of uitteken, en niks word in die agtergrond gestuur nie.';
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
      'Deel is aan, maar hierdie foon gee nie ’n ligging aan TradeIQ nie';

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
  String get locationStopConfirm => 'Hou op om te deel';

  @override
  String get locationStopCancel => 'Hou aan om te deel';

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
      'Jy kan ook kennisgewings vir TradeIQ in jou foon se instellings afskakel.';
}
