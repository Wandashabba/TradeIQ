// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get languageMenuTooltip => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageAfrikaans => 'Afrikaans';

  @override
  String get agentBackTooltip => 'Back';

  @override
  String get agentThemeTooltip => 'Theme';

  @override
  String get agentLogOutTooltip => 'Log out';

  @override
  String get agoJustNow => 'just now';

  @override
  String agoMinutes(int minutes) {
    return '$minutes min ago';
  }

  @override
  String agoHours(int hours) {
    return '${hours}h ago';
  }

  @override
  String agoDays(int days) {
    return '${days}d ago';
  }

  @override
  String syncSendingTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sending $count captures…',
      one: 'Sending 1 capture…',
    );
    return '$_temp0';
  }

  @override
  String get syncSendingSubtitle => 'Keep going — you don’t have to wait';

  @override
  String syncAttentionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items need your attention',
      one: '1 item needs your attention',
    );
    return '$_temp0';
  }

  @override
  String get syncAttentionSubtitle =>
      'They will not send on their own — tap to see';

  @override
  String syncHeldTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count captures held on this phone',
      one: '1 capture held on this phone',
    );
    return '$_temp0';
  }

  @override
  String get syncHeldSubtitle => 'They will send themselves · nothing is lost';

  @override
  String get syncAllSentTitle => 'Everything is sent';

  @override
  String get syncNothingWaiting => 'Nothing waiting';

  @override
  String syncLastSent(String ago) {
    return 'Last sent $ago';
  }

  @override
  String get kitStepperFewer => 'One fewer';

  @override
  String get kitStepperMore => 'One more';

  @override
  String get captureCancelTooltip => 'Cancel';

  @override
  String get captureErrorChip => 'Error';

  @override
  String captureError(String error) {
    return 'Could not capture a photo: $error';
  }

  @override
  String get captureButton => 'Capture';

  @override
  String get captureGalleryButton => 'Choose from gallery';

  @override
  String photoFieldDefaultHint(String label) {
    return 'Frame the $label inside the guides, edge to edge.';
  }

  @override
  String get photoFieldAdd => 'Add photo';

  @override
  String get photoFieldCaptured => 'Captured';

  @override
  String get photoFieldRetake => 'Retake';

  @override
  String get loginInvalidCredentials => 'Invalid credentials';

  @override
  String get loginBackTooltip => 'Back to welcome';

  @override
  String get loginKicker => 'WELCOME BACK';

  @override
  String get loginSignIn => 'Sign in';

  @override
  String get loginSubtitle => 'Use your TradeIQ work account.';

  @override
  String get loginEmailLabel => 'Email';

  @override
  String get loginEmailHint => 'you@company.com';

  @override
  String get loginEmailRequired => 'Email is required';

  @override
  String get loginPasswordLabel => 'Password';

  @override
  String get loginPasswordHint => 'Enter your password';

  @override
  String get loginShowPassword => 'Show password';

  @override
  String get loginHidePassword => 'Hide password';

  @override
  String get loginPasswordRequired => 'Password is required';

  @override
  String get loginRememberMe => 'Remember me';

  @override
  String get loginForgotPassword => 'Forgot password?';

  @override
  String get loginPasswordResetUnavailable =>
      'Password reset is not available yet.';

  @override
  String get todayTitle => 'Today';

  @override
  String get todayLoadErrorTitle => 'Could not load your route';

  @override
  String get todayLoadErrorDetail => 'You can still start a visit yourself.';

  @override
  String get todayNoRouteTitle => 'No route planned for today';

  @override
  String get todayNoPlanDetail =>
      'No beat plan for today. You can still pick a store yourself.';

  @override
  String get todayEmptyPlanDetail =>
      'Today’s beat plan has no stops on it yet.';

  @override
  String get todayYourRouteHeading => 'Your route';

  @override
  String get todayVisitAnotherStore => 'Visit a store not on my route';

  @override
  String todayStoresOfTotal(int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: ' of $total stores',
      one: ' of 1 store',
    );
    return '$_temp0';
  }

  @override
  String todayStoresLeft(int count) {
    return '$count left';
  }

  @override
  String get todayRouteDone => 'Route done';

  @override
  String get todayDistancesOff =>
      'Distances are off — this phone will not say where it is.';

  @override
  String get todayStopDoneTag => 'DONE';

  @override
  String get todayStopNextTag => 'NEXT';

  @override
  String get todayPickStore => 'Pick a store to visit';

  @override
  String get todayNextUpHeading => 'Next up';

  @override
  String get todayRestOfDayHeading => 'The rest of the day';

  @override
  String get todayStoresRingLabel => 'Stores';

  @override
  String todayStopNumber(String number) {
    return 'Stop $number';
  }

  @override
  String get todayCheckInHere => 'Check in here';

  @override
  String get pickerTitle => 'Select an Outlet';

  @override
  String get pickerSubtitle => 'Tap a store to start a visit';

  @override
  String get pickerAddStore => 'Add a store';

  @override
  String get pickerScopeMine => 'My territories';

  @override
  String get pickerScopeAll => 'All stores';

  @override
  String pickerScopeMineSummary(int count) {
    return '$count in your territories · tap All stores to see every shop';
  }

  @override
  String pickerScopeAllSummary(int count) {
    return 'All $count stores across this client';
  }

  @override
  String get pickerLoadErrorTitle => 'Could not load your stores';

  @override
  String get pickerRetry => 'Try again';

  @override
  String get myWorkTitle => 'Your work';

  @override
  String get myWorkSubtitle => 'What is on this phone, and what is sent';

  @override
  String get myWorkSyncNow => 'Try sending now';

  @override
  String get myWorkLoadErrorTitle => 'Could not read your work';

  @override
  String get myWorkNeedsYouHeading => 'Needs you';

  @override
  String get myWorkWaitingHeading => 'Waiting to send';

  @override
  String get myWorkSentHeading => 'Sent';

  @override
  String get myWorkEmpty => 'Nothing captured yet';

  @override
  String get myWorkFooter =>
      'Captures send themselves when you have signal. Nothing is lost.';

  @override
  String myWorkSendingTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sending $count items…',
      one: 'Sending 1 item…',
    );
    return '$_temp0';
  }

  @override
  String get myWorkSendingSubtitle => 'You don’t have to wait for this';

  @override
  String myWorkFailedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items will not send',
      one: '1 item will not send',
    );
    return '$_temp0';
  }

  @override
  String get myWorkFailedSubtitle => 'Everything else is safe';

  @override
  String myWorkHeldTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items held on this phone',
      one: '1 item held on this phone',
    );
    return '$_temp0';
  }

  @override
  String get myWorkHeldSubtitle => 'They will send themselves';

  @override
  String get myWorkStateSent => 'Sent';

  @override
  String get myWorkStateFailed => 'Failed';

  @override
  String get myWorkStateWaiting => 'Waiting';

  @override
  String get syncErrorWaitingForVisit => 'Waiting for the visit to send first';

  @override
  String get syncErrorNoConnection => 'No connection';

  @override
  String get syncErrorSignedOut => 'Signed out — sign in again';

  @override
  String get syncErrorTooLarge => 'Too large to send';

  @override
  String get syncErrorServerProblem => 'Server problem — will retry';

  @override
  String syncErrorRejected(int status) {
    return 'Rejected by the server ($status)';
  }

  @override
  String get syncErrorCouldNotSend => 'Could not send';

  @override
  String get syncItemCheckIn => 'Check-in';

  @override
  String get syncItemSubmittedVisit => 'Submitted visit';

  @override
  String get syncItemStockCount => 'Stock count';

  @override
  String get syncItemVisibility => 'Visibility & display';

  @override
  String get syncItemPricing => 'Pricing';

  @override
  String get syncItemCompetitive => 'Competitive';

  @override
  String get syncItemCapability => 'Team capability';

  @override
  String get syncItemRisks => 'Risks';

  @override
  String get syncItemActionPlan => 'Action plan';

  @override
  String get syncItemScore => 'Score';

  @override
  String get syncItemPhoto => 'Photo';

  @override
  String get syncItemOrder => 'Order';

  @override
  String get visitStartingTitle => 'Starting visit';

  @override
  String get visitTitle => 'Visit';

  @override
  String visitOutletLoadFailed(String error) {
    return 'Failed to load outlet: $error';
  }

  @override
  String get visitOutletNotFound => 'Outlet not found';

  @override
  String visitReadFailed(String error) {
    return 'Could not read this visit: $error';
  }

  @override
  String get visitInStoreJustNow => 'In store just now';

  @override
  String visitInStoreMinutes(int minutes) {
    return 'In store $minutes min';
  }

  @override
  String visitInStoreHours(int hours) {
    return 'In store ${hours}h';
  }

  @override
  String visitInStoreDays(int days) {
    return 'In store ${days}d';
  }

  @override
  String get visitAuditHeading => 'The audit';

  @override
  String get visitAnyOrderHint =>
      'Any order. Everything saves as you go, even with no signal.';

  @override
  String visitFinishToSubmit(String sections) {
    return 'Finish $sections to submit';
  }

  @override
  String visitSectionsAnd(String first, String second) {
    return '$first and $second';
  }

  @override
  String get visitSubmitButton => 'Submit visit';

  @override
  String get visitSectionSavesAsYouGo => 'Saves as you go';

  @override
  String get visitSectionDoneBack => 'Done · back to visit';

  @override
  String visitProgressOfSections(int total) {
    return ' of $total sections';
  }

  @override
  String get visitReadyToSubmit => 'Ready to submit';

  @override
  String visitStillRequired(int count) {
    return '$count still required';
  }

  @override
  String get visitSectionsCaptured => 'Sections captured';

  @override
  String get visitScoreCalculatedOnSubmit => 'Calculated when you submit';

  @override
  String get visitSectionNotStarted => 'Not started';

  @override
  String get visitSectionOptional => 'Optional';

  @override
  String get visitRequiredToSubmitBadge => 'REQUIRED TO SUBMIT';

  @override
  String get visitRequiredToSubmit => 'Required to submit';

  @override
  String get visitRequiredShort => 'REQ';

  @override
  String get visitSectionOutletInfo => 'Outlet info';

  @override
  String get visitSectionStock => 'Stock & availability';

  @override
  String get visitSectionVisibility => 'Visibility & display';

  @override
  String get visitSectionPricing => 'Pricing & promotions';

  @override
  String get visitSectionCompetitive => 'Competitive';

  @override
  String get visitSectionCapability => 'Team capability';

  @override
  String get visitSectionRisks => 'Risks';

  @override
  String get visitSectionActionPlan => 'Action plan';

  @override
  String get visitSectionScore => 'Score';

  @override
  String get visitCheckInFinding => 'Finding you…';

  @override
  String get visitCheckInWithinHint =>
      'Check in within 50 m of the store. This proves the visit happened.';

  @override
  String get visitRetry => 'Try again';

  @override
  String get visitBackToRoute => 'Back to route';

  @override
  String get visitTooFarTitle => 'You’re too far away';

  @override
  String get visitTooFarBody =>
      'Move closer and try again. Nothing is lost — the visit hasn’t started.';

  @override
  String visitTooFarDistance(int meters) {
    return '$meters m away · need 50 m or closer';
  }

  @override
  String get visitTooFarFraudNote =>
      'This attempt is recorded. Retrying from far away is itself a fraud signal — walk closer instead.';

  @override
  String get visitNoLocationTitle => 'Can’t find your location';

  @override
  String get visitCheckInFailedTitle => 'Could not start the visit';

  @override
  String get visitCheckInFailedNothingLost =>
      'Nothing is lost — the visit hadn’t started.';

  @override
  String submitSubtitleInStore(String outlet, int minutes) {
    return '$outlet · $minutes min in store';
  }

  @override
  String get submitOfflineNote =>
      'No signal? Submitting still works — it saves on the phone and sends itself.';

  @override
  String get submitIntro =>
      'Check this before it goes to your manager — you cannot change it after.';

  @override
  String get submitWillRaiseHeading => 'This will raise';

  @override
  String submitAccusation(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'You are telling the manager $count things are wrong in this store. They come from what you captured — nothing is added. Anything already open is not raised twice.',
      one:
          'You are telling the manager one thing is wrong in this store. It comes from what you captured — nothing is added. If it is already open, it is not raised twice.',
    );
    return '$_temp0';
  }

  @override
  String submitSectionsComplete(int done, int total) {
    return '$done of $total sections complete';
  }

  @override
  String submitTaskForManager(String priority) {
    return 'Task for the manager · $priority';
  }

  @override
  String submitPriority(String priority) {
    String _temp0 = intl.Intl.selectLogic(priority, {
      'critical': 'critical',
      'high': 'high',
      'normal': 'normal',
      'low': 'low',
      'other': '$priority',
    });
    return '$_temp0';
  }

  @override
  String get submitNothingToRaise =>
      'Nothing to raise. No stockouts, no risks — this store is in good shape.';

  @override
  String get outcomeTitle => 'Visit submitted';

  @override
  String get outcomeNextStore => 'Next store';

  @override
  String get outcomeSending => 'Sending your visit…';

  @override
  String get outcomeHeldTitle => 'Your visit is safe on this phone';

  @override
  String get outcomeHeldBodyUnreachable =>
      'Could not reach the server. It sends itself when signal returns — you can close the app.';

  @override
  String get outcomeHeldBodyNoSignal =>
      'No signal. It sends itself when signal returns — you can close the app.';

  @override
  String get outcomeScoredWhenSends => 'Scored when it sends';

  @override
  String get outcomeScoredOnServer =>
      'Worked out on the server, not on the phone';

  @override
  String get outcomeNoGuess =>
      'Your real score — the one your manager sees — appears once this reaches the server.';

  @override
  String ratingBand(String band) {
    String _temp0 = intl.Intl.selectLogic(band, {
      'green': 'Healthy',
      'amber': 'Watch',
      'other': 'Gap',
    });
    return '$_temp0';
  }

  @override
  String outcomeDeltaSame(int previous) {
    return 'Same as your last visit here ($previous).';
  }

  @override
  String outcomeDeltaUp(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Up $count points',
      one: 'Up 1 point',
    );
    return '$_temp0';
  }

  @override
  String outcomeDeltaDown(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Down $count points',
      one: 'Down 1 point',
    );
    return '$_temp0';
  }

  @override
  String outcomeDeltaFromLast(int previous) {
    return 'from your last visit here ($previous).';
  }

  @override
  String get outcomeHowScored => 'How it was scored';

  @override
  String get outcomePerfectStoreScore => 'Perfect-store score';

  @override
  String get outcomeDimensionAvailability => 'Availability';

  @override
  String get outcomeDimensionVisibility => 'Visibility';

  @override
  String get outcomeDimensionDisplay => 'Display';

  @override
  String get outcomeDimensionPricing => 'Pricing';

  @override
  String get outcomeDimensionCompetitive => 'Share of shelf';

  @override
  String get outcomeDimensionSalesCapability => 'Team capability';

  @override
  String get outcomeUnmeasurableCompetitive =>
      'No competitor on shelf — not counted against you.';

  @override
  String get outcomeUnmeasurableSalesCapability =>
      'No staff on shift — not counted against you.';

  @override
  String get s1Title => 'Outlet check-in';

  @override
  String get s1ConfirmedAtCheckin => 'Confirmed at check-in';

  @override
  String get s1CheckedIn => 'Checked in';

  @override
  String get s1NotRecorded => 'Not recorded';

  @override
  String get s1Geofence => 'Geofence';

  @override
  String get s1Passed => 'Passed';

  @override
  String s2LoadFailed(String error) {
    return 'Failed to load SKUs: $error';
  }

  @override
  String get s2NoSkus => 'No SKUs configured for this client.';

  @override
  String s2ContextSelling(String velocity) {
    return 'Selling ~$velocity/day';
  }

  @override
  String s2ContextSellingOutOfStock(String velocity, int days) {
    return 'Selling ~$velocity/day · out of stock ${days}d';
  }

  @override
  String get s2ContextNoHistory => 'No sales history yet';

  @override
  String s2ContextNoHistoryOutOfStock(int days) {
    return 'No sales history yet · out of stock ${days}d';
  }

  @override
  String s2Rrp(String price) {
    return 'RRP $price';
  }

  @override
  String get s2OutOfStockRaisesTask =>
      'Out of stock — this raises a task for the manager';

  @override
  String get s2ShoppersSwitch =>
      '70% of shoppers switch brand when the product is missing.';

  @override
  String get s2SaveStock => 'Save stock';

  @override
  String get s2StockSaved => 'Stock saved — queued for sync';

  @override
  String get s2UnitsOnShelf => 'Units on shelf';

  @override
  String get s2Cancel => 'Cancel';

  @override
  String get s2Set => 'Set';

  @override
  String get s10ComputeFailed =>
      'Could not compute the scorecard. Try refreshing.';

  @override
  String get s10DimensionScores => 'Dimension scores';

  @override
  String get s10WeightedTotal => 'Weighted total';

  @override
  String get s10Finalize => 'Finalize scorecard';

  @override
  String get s10Refresh => 'Refresh';

  @override
  String get s10Queued => 'Scorecard queued for sync';

  @override
  String get s10DimensionAvailability => 'Availability';

  @override
  String get s10DimensionVisibility => 'Visibility';

  @override
  String get s10DimensionDisplay => 'Display';

  @override
  String get s10DimensionPricing => 'Pricing';

  @override
  String get s10DimensionCompetitive => 'Competitive';

  @override
  String get s10DimensionSalesCapability => 'Sales Capability';

  @override
  String get s34BrandingPoster => 'Poster';

  @override
  String get s34BrandingShelfStrip => 'Shelf strip';

  @override
  String get s34BrandingWobbler => 'Wobbler';

  @override
  String get s34BrandingLabel => 'Branding elements present';

  @override
  String get s34PlanogramLabel => 'Planogram compliance %';

  @override
  String get s34FacingsLabel => 'Facings count';

  @override
  String get s34CleanlinessLabel => 'Cleanliness score';

  @override
  String get s34HighTrafficLabel => 'High-traffic location';

  @override
  String get s34PhotoLabel => 'Shelf photo';

  @override
  String get s34PhotoHelper =>
      'Optional. Evidence for this section, and training data for automatic planogram scoring.';

  @override
  String get s34SaveButton => 'Save visibility';

  @override
  String get s34Saved => 'Visibility saved — queued for sync';

  @override
  String s5LoadError(String error) {
    return 'Failed to load SKUs: $error';
  }

  @override
  String get s5NoSkus => 'No SKUs configured for this client.';

  @override
  String get s5ActualPriceLabel => 'Actual price';

  @override
  String get s5PromoActiveLabel => 'Promotion active';

  @override
  String get s5CommsRatingLabel => 'Comms rating (1-5)';

  @override
  String get s5PhotoLabel => 'Shelf-price photo';

  @override
  String get s5PhotoHelper =>
      'Optional. Evidence for the prices you typed, and training data for automatic price reading.';

  @override
  String get s5SaveButton => 'Save pricing';

  @override
  String get s5Saved => 'Pricing saved — queued for sync';

  @override
  String s6CompetitorTitle(int number) {
    return 'Competitor $number';
  }

  @override
  String get s6SkuLabel => 'Competitor SKU';

  @override
  String get s6SkuHint => 'What the rival is selling';

  @override
  String get s6PriceLabel => 'Competitor price';

  @override
  String get s6PosmLabel => 'POSM type';

  @override
  String get s6PosmHint => 'Poster, wobbler, gondola…';

  @override
  String get s6FacingsLabel => 'Facings on shelf';

  @override
  String get s6FacingsHelp => 'How much shelf this competitor holds';

  @override
  String get s6PromoterLabel => 'Promoter present';

  @override
  String get s6AddButton => 'Add competitor';

  @override
  String get s6SaveButton => 'Save competitive';

  @override
  String get s6Saved => 'Competitive intel saved — queued for sync';

  @override
  String get s7TrainingProductKnowledge => 'Product knowledge';

  @override
  String get s7TrainingMerchandising => 'Merchandising';

  @override
  String get s7TrainingPosSystems => 'POS systems';

  @override
  String get s7HeadcountLabel => 'Staff headcount confirmed';

  @override
  String get s7HeadcountHint => 'Reps on the floor';

  @override
  String get s7TrainingLabel => 'Rep training completed';

  @override
  String get s7QuizLabel => 'Quiz score (0-100)';

  @override
  String get s7SaveButton => 'Save capability';

  @override
  String get s7Saved => 'Capability saved — queued for sync';

  @override
  String get s8SeverityCritical => 'Critical';

  @override
  String get s8SeverityHigh => 'High';

  @override
  String get s8SeverityNormal => 'Normal';

  @override
  String s8RiskTitle(int number) {
    return 'Risk $number';
  }

  @override
  String get s8FlagTypeLabel => 'Flag type';

  @override
  String get s8FlagTypeHint => 'What was flagged';

  @override
  String get s8SeverityLabel => 'Severity';

  @override
  String get s8NoteLabel => 'Note';

  @override
  String get s8NoteHint => 'Optional detail';

  @override
  String get s8AddButton => 'Flag a risk';

  @override
  String get s8SaveButton => 'Save risks';

  @override
  String get s8Saved =>
      'Risks saved — queued for sync; follow-up tasks will be auto-created';

  @override
  String s8SeverityNote(String severity) {
    String _temp0 = intl.Intl.selectLogic(severity, {
      'critical': 'Critical risk — saving it raises a follow-up task',
      'other': 'High risk — saving it raises a follow-up task',
    });
    return '$_temp0';
  }

  @override
  String get s9PriorityCritical => 'Critical';

  @override
  String get s9PriorityHigh => 'High';

  @override
  String get s9PriorityNormal => 'Normal';

  @override
  String get s9Intro =>
      'Risks flagged in S8 auto-create tasks with an SLA. Add extra tasks below.';

  @override
  String get s9FindingTypeLabel => 'Finding type';

  @override
  String get s9FindingTypeHint => 'What needs fixing';

  @override
  String get s9RequiredFixLabel => 'Required fix';

  @override
  String get s9RequiredFixHint => 'The corrective action';

  @override
  String get s9PriorityLabel => 'Priority';

  @override
  String get s9AddButton => 'Add task';

  @override
  String get s9Saved => 'Task queued for sync';

  @override
  String get errorSessionExpired =>
      'Your session has expired. Please sign in again.';

  @override
  String get errorUnreachable =>
      'Could not reach the server. Check your connection and try again.';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get checkInLocationPermissionDenied => 'Location permission denied';

  @override
  String get checkInLocationServicesDisabled =>
      'Location services are disabled';

  @override
  String get checkInLocationTimedOut =>
      'Took too long. Check location is on for TradeIQ, then try again.';

  @override
  String checkInLocationFailed(String error) {
    return 'Failed to get current location: $error';
  }

  @override
  String get progressConfirmedAtCheckIn => 'Confirmed at check-in';

  @override
  String progressSkusOfTotal(int items, int total) {
    return '$items of $total SKUs';
  }

  @override
  String progressStockCounted(int items) {
    return '$items SKUs counted';
  }

  @override
  String progressStockOutOfStock(int items, int outOfStock) {
    return '$items SKUs · $outOfStock out of stock';
  }

  @override
  String progressSkusPriced(int items) {
    return '$items SKUs priced';
  }

  @override
  String get progressNoCompetitors => 'None on shelf';

  @override
  String progressCompetitors(int items) {
    return '$items competitor(s)';
  }

  @override
  String get progressCaptured => 'Captured';

  @override
  String get progressNoRisks => 'None raised';

  @override
  String progressRisksRaised(int items) {
    return '$items raised';
  }

  @override
  String taskStockoutTitle(String sku) {
    return '$sku is out of stock';
  }

  @override
  String get taskStockoutTitleUnnamed => 'This SKU is out of stock';

  @override
  String get taskStockoutReason => 'You counted zero on shelf';

  @override
  String taskRiskTitle(String flagType) {
    return '$flagType flagged';
  }

  @override
  String get taskRiskTitleUntyped => 'Risk flagged';

  @override
  String taskRiskReason(String flagType) {
    return 'Risk you raised · $flagType';
  }

  @override
  String get taskRiskReasonUntyped => 'Risk you raised · flagged';

  @override
  String get taskActionPlanTitleUntitled => 'Action you asked for';

  @override
  String get taskActionPlanReason => 'Action plan you wrote';

  @override
  String reviewSkusCounted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count SKUs counted',
      one: '1 SKU counted',
    );
    return '$_temp0';
  }

  @override
  String reviewCompetitors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count competitors',
      one: '1 competitor',
    );
    return '$_temp0';
  }

  @override
  String reviewPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '1 photo',
    );
    return '$_temp0';
  }

  @override
  String get visitTemplateSectionKicker => 'Client questions';

  @override
  String visitTemplateTileDetail(String detail) {
    return 'Client questions · $detail';
  }

  @override
  String get visitTemplateSectionIntro =>
      'Asked on every visit. Answer the required ones to submit.';

  @override
  String visitTemplateProgressAnswered(int answered, int total) {
    return '$answered of $total answered';
  }

  @override
  String visitTemplateRequiredLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count required questions left',
      one: '1 required question left',
    );
    return '$_temp0';
  }

  @override
  String get visitTemplateAllRequiredAnswered =>
      'All required questions answered';

  @override
  String get visitTemplateFieldRequired => 'Required';

  @override
  String get visitTemplateFieldRequiredError => 'Answer this before you submit';

  @override
  String get visitTemplateSave => 'Save answers';

  @override
  String get visitTemplateSaved => 'Answers saved — queued for sync';

  @override
  String get visitTemplatePhotoUnsupported =>
      'Photo questions can’t be answered in the app yet';

  @override
  String get visitTemplateNoQuestions =>
      'This client’s template has no questions yet';

  @override
  String get locationNoticeTitle => 'Your location is shared with your manager';

  @override
  String locationNoticeBody(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'every $minutes minutes',
      one: 'every minute',
    );
    return 'Your manager can see which store you are at.\n\nWhile TradeIQ is open and you are signed in, it sends your location $_temp0. Closing TradeIQ or signing out stops it. Nothing is sent in the background.';
  }

  @override
  String get locationNoticeAcknowledge => 'I understand, share my location';

  @override
  String get locationNoticeDecline => 'Don’t share';

  @override
  String get locationSharingActiveTitle =>
      'Sharing your location with your manager';

  @override
  String get locationSharingActiveSubtitle =>
      'Only while TradeIQ is open · tap to stop';

  @override
  String get locationSharingNoFixSubtitle =>
      'Sharing is on, but this phone isn’t giving TradeIQ a location';

  @override
  String get locationSharingOffTitle => 'Your location is not shared';

  @override
  String get locationSharingOffSubtitle => 'Tap to change this';

  @override
  String get locationStopTitle => 'Stop sharing your location?';

  @override
  String get locationStopBody =>
      'Your manager will no longer see where you are. You can turn it back on later.';

  @override
  String get locationStopConfirm => 'Stop sharing';

  @override
  String get locationStopCancel => 'Keep sharing';

  @override
  String get backgroundLocationNoticeTitle =>
      'Recording your route between stores';

  @override
  String backgroundLocationNoticeBody(int minutes, String start, String end) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'every $minutes minutes',
      one: 'every minute',
    );
    return 'Separate from sharing while TradeIQ is open, and you can say no.\n\nTradeIQ records where you are $_temp0, even when it is closed, so your manager can see your route between stores. Working days $start–$end only — never at night or at a weekend. A notification stays on your phone the whole time. You can turn it off whenever you like; that does not stop the sharing you already agreed to.';
  }

  @override
  String get backgroundLocationNoticeAccept => 'Turn on route tracking';

  @override
  String get backgroundLocationNoticeDecline => 'No, don’t record my route';

  @override
  String get backgroundLocationOfferTitle => 'Route tracking is off';

  @override
  String get backgroundLocationOfferSubtitle => 'Tap to see what it does';

  @override
  String get backgroundLocationActiveTitle =>
      'Recording your route between stores';

  @override
  String get backgroundLocationActiveSubtitle =>
      'Working hours only · tap to stop';

  @override
  String get backgroundLocationOutsideHoursTitle => 'Route tracking is paused';

  @override
  String backgroundLocationOutsideHoursSubtitle(String start) {
    return 'It starts again on a working day at $start';
  }

  @override
  String get backgroundLocationPermissionTitle =>
      'Android needs one more permission';

  @override
  String get backgroundLocationPermissionBody =>
      'Choose “Allow all the time” for location on TradeIQ’s settings page.\n\nThat lets TradeIQ record your route when it is closed. Everything else keeps working if you would rather not.';

  @override
  String get backgroundLocationPermissionOpenSettings =>
      'Open TradeIQ’s settings';

  @override
  String get backgroundLocationPermissionNotNow => 'Not now';

  @override
  String get backgroundLocationStopTitle => 'Stop recording your route?';

  @override
  String get backgroundLocationStopBody =>
      'Your manager will no longer see your route between stores.\n\nSharing your location while TradeIQ is open is not affected.';

  @override
  String get backgroundLocationStopConfirm => 'Stop route tracking';

  @override
  String get backgroundLocationStopCancel => 'Keep recording';

  @override
  String get backgroundLocationNotificationTitle =>
      'TradeIQ is recording your route';

  @override
  String get backgroundLocationNotificationBody =>
      'Working hours only. Turn it off in TradeIQ.';

  @override
  String get backgroundLocationNotificationChannel => 'Route tracking';

  @override
  String get contestsTitle => 'Contests';

  @override
  String get contestsSubtitle => 'Earn points, climb the standings';

  @override
  String get contestsActiveHeading => 'Running now';

  @override
  String get contestsEndedHeading => 'Recently ended';

  @override
  String contestDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days left',
      one: '1 day left',
    );
    return '$_temp0';
  }

  @override
  String get contestEnded => 'Ended';

  @override
  String contestDateRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String get contestPrizeLabel => 'Prize';

  @override
  String get contestCountsLabel => 'What counts';

  @override
  String get contestEventAll => 'All points';

  @override
  String get contestEventVisitSubmitted => 'Submitted visits';

  @override
  String get contestEventTaskClosed => 'Closed tasks';

  @override
  String get contestEventScorecard => 'Scorecards';

  @override
  String contestYourRank(int rank, int total) {
    return 'Your rank: $rank of $total';
  }

  @override
  String contestPoints(String points) {
    return '$points pts';
  }

  @override
  String get contestNotRanked => 'You’re not on this contest’s standings';

  @override
  String get contestStandingsHeading => 'Standings';

  @override
  String get contestYouTag => 'You';

  @override
  String get contestsEmptyTitle => 'No contests right now';

  @override
  String get contestsEmptyBody =>
      'When your manager starts a contest, it shows up here.';

  @override
  String get contestsLoadError => 'Couldn’t load contests';

  @override
  String get contestsRetry => 'Try again';

  @override
  String contestsRunningHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contests running',
      one: '1 contest running',
    );
    return '$_temp0';
  }

  @override
  String get agentNotificationsTooltip => 'Notifications';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsSubtitle => 'Choose what reaches this phone';

  @override
  String get notificationsTasksLabel => 'Tasks assigned to you';

  @override
  String get notificationsTasksHelp => 'When your manager gives you a task';

  @override
  String get notificationsMessagesLabel => 'Messages and announcements';

  @override
  String get notificationsMessagesHelp =>
      'Messages to you or the team, and announcements';

  @override
  String get notificationsSlaLabel => 'Overdue tasks';

  @override
  String get notificationsSlaHelp =>
      'When one of your tasks passes its deadline';

  @override
  String get notificationsNotSetUpTitle =>
      'Notifications aren’t switched on yet';

  @override
  String get notificationsNotSetUpBody =>
      'Your choices are saved and apply as soon as they are.';

  @override
  String get notificationsLoadErrorTitle =>
      'Couldn’t load your notification settings';

  @override
  String get notificationsRetry => 'Try again';

  @override
  String get notificationsSaveFailed =>
      'Couldn’t save that. Check your connection and try again.';

  @override
  String get notificationsFooter =>
      'You can also turn these off in your phone’s settings.';

  @override
  String get navToday => 'Today';

  @override
  String get navMyWork => 'My work';

  @override
  String get navMap => 'Map';

  @override
  String get navMe => 'Me';

  @override
  String get todayRouteEyebrow => 'Route';

  @override
  String get todayStopUpcoming => 'To do';

  @override
  String get unitMetres => 'm';

  @override
  String get unitKilometres => 'km';

  @override
  String get skinDay => 'Day';

  @override
  String get skinNight => 'Night';

  @override
  String get skinVeld => 'Veld, the outdoor high-contrast screen';

  @override
  String get syncChipAllSent => 'All sent';

  @override
  String get syncChipAllSentSemantics =>
      'All your work is sent. Double-tap to see it.';

  @override
  String get visitClientQuestions => 'The client’s questions';

  @override
  String get visitReadFailedTitle => 'This visit could not be read.';

  @override
  String get visitReadFailedBlock =>
      'The visit’s own progress could not be read, so it cannot be sent yet.';

  @override
  String get visitCantConfirmProducts =>
      'The product list did not load — this section can’t be confirmed.';

  @override
  String get visitCantConfirmTemplate =>
      'The client’s questions did not load — this section can’t be confirmed.';

  @override
  String get visitCheckInEyebrow => 'Check-in';

  @override
  String get visitTooFarAttemptsRecorded =>
      'Every attempt is recorded with where you were.';

  @override
  String get visitTooFarClose => 'You’re close. Try walking to the front door.';

  @override
  String get visitTooFarWrongStore =>
      'This looks like the wrong store, or the store’s pin is wrong.';

  @override
  String get visitPinIsWrong => 'The pin is wrong';

  @override
  String get visitPinReportedHeld =>
      'Reported on this phone. It has not been sent anywhere yet — there is nowhere to send it.';

  @override
  String get visitNoGpsFixPermission =>
      'Allow location for TradeIQ in your phone’s settings. You can allow it just while using the app.';

  @override
  String get visitNoGpsFixServices =>
      'Turn location on in your phone’s settings, then try again.';

  @override
  String get visitNoGpsFixTimedOut =>
      'Step outside or near a window and try again. Your GPS still works in airplane mode — give it a few seconds.';

  @override
  String get visitNoGpsFixGeneric =>
      'Step outside or near a window and try again.';

  @override
  String get visitCopyCode => 'Copy';

  @override
  String get visitCopyCodeSemantics => 'Copy the error code';

  @override
  String todayRouteSemantics(int done, int total, int left) {
    return 'Route: $done of $total stores done, $left left.';
  }

  @override
  String todayStopSemantics(String name, String code, String state) {
    return '$name, $code, $state. Double-tap to check in here.';
  }

  @override
  String todayDistanceMetresSemantics(int meters) {
    return '$meters metres away';
  }

  @override
  String todayDistanceKmSemantics(num km) {
    return '$km kilometres away';
  }

  @override
  String skinCycleLabel(String current, String next) {
    return 'Screen: $current. Double-tap for $next.';
  }

  @override
  String visitReadinessSemantics(int done, int total, int blocking) {
    return 'Captured, $done of $total. $blocking sections still needed.';
  }

  @override
  String visitScoreSemantics(String name) {
    return '$name, not yet available. Worked out when the visit sends.';
  }

  @override
  String visitSectionSemantics(String name, String state, String detail) {
    return '$name. $state. $detail';
  }

  @override
  String visitTooFarNeedWithin(int meters) {
    return 'You need to be within 50 m. Right now you are $meters m away.';
  }

  @override
  String visitTooFarSemantics(int meters) {
    return 'Too far from the shop. You are $meters metres away. You need to be within 50 metres.';
  }

  @override
  String visitErrorCodeSemantics(String code) {
    return 'Error code $code';
  }

  @override
  String syncChipHeld(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count held on this phone',
      one: '1 held on this phone',
    );
    return '$_temp0';
  }

  @override
  String syncChipHeldSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count captures held on this phone. Double-tap to see your work.',
      one: '1 capture held on this phone. Double-tap to see your work.',
    );
    return '$_temp0';
  }

  @override
  String syncChipNeedsYou(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count need you',
      one: '1 needs you',
    );
    return '$_temp0';
  }

  @override
  String syncChipNeedsYouSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Needs you. $count captures will not send on their own. Double-tap to see your work.',
      one:
          'Needs you. 1 capture will not send on its own. Double-tap to see your work.',
    );
    return '$_temp0';
  }

  @override
  String visitCantConfirmCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sections can’t be confirmed',
      one: '1 section can’t be confirmed',
    );
    return '$_temp0';
  }

  @override
  String get wordYes => 'Yes';

  @override
  String get wordNo => 'No';

  @override
  String get sectionSave => 'Save';

  @override
  String get sectionSaveAndBack => 'Save and go back';

  @override
  String get sectionSaveFailedTitle => 'Not saved';

  @override
  String get sectionSaveFailedBody =>
      'Your answers are still here — try Save again.';

  @override
  String get sectionCantConfirm => 'Can\'t confirm this section';

  @override
  String get sectionCantConfirmWhy => 'Why not?';

  @override
  String sectionCantConfirmLocked(String reason) {
    return 'Can\'t confirm: $reason';
  }

  @override
  String get sectionCantConfirmHeld =>
      'Held on this phone. Nothing is sent for this yet.';

  @override
  String get sectionCanConfirmAfterAll => 'I can confirm it after all';

  @override
  String get sectionLockedBlock => 'This section is marked can\'t confirm';

  @override
  String get sectionLeaveTitle => 'You have unsaved answers';

  @override
  String get sectionLeaveWithoutSaving => 'Go back without saving';

  @override
  String get sectionStayHere => 'Stay here';

  @override
  String get sectionAddAnother => 'Add another';

  @override
  String sectionEntryPosition(int index, int total) {
    return '$index of $total';
  }

  @override
  String sectionRemoveEntry(String name, String position) {
    return 'Remove $name $position';
  }

  @override
  String get sectionNotAnsweredYet => 'Not answered yet';

  @override
  String get sectionPhotoOpenCamera => 'Open camera';

  @override
  String get sectionPhotoOpenCameraSemantics =>
      'Open the camera to photograph the shelf';

  @override
  String get sectionPhotoFraming =>
      'Stand back far enough to get the whole bay, including the price rail.';

  @override
  String get sectionPhotoStamped =>
      'Your photo is stamped with the time and where you are.';

  @override
  String get sectionPhotoTorchHint =>
      'Aisle dark? Switch your phone torch on before you shoot.';

  @override
  String get sectionPhotoHeld => 'Held on this phone · sends with the visit';

  @override
  String get sectionPhotoNoCamera => 'This phone has no camera we can reach.';

  @override
  String get sectionPhotoTooLarge =>
      'That photo is too big to send. Take it again.';

  @override
  String get sectionPhotoFailed =>
      'The camera did not hand the photo back. Try again.';

  @override
  String get sectionPhotoRemoveSemantics => 'Remove the photo';

  @override
  String sectionPhotoSemantics(String time) {
    return 'Photo taken $time, held on this phone';
  }

  @override
  String get skipReasonStoreRefused => 'The store would not let me';

  @override
  String get skipReasonStoreRefusedConsequence =>
      'The manager is told the store refused';

  @override
  String get skipReasonNotStocked => 'They do not stock this';

  @override
  String get skipReasonNotStockedConsequence =>
      'These lines are marked not-stocked for this outlet';

  @override
  String get skipReasonEquipment => 'The equipment is broken';

  @override
  String get skipReasonEquipmentConsequence => 'A repair task is raised';

  @override
  String get skipReasonSomethingElse => 'Something else';

  @override
  String get skipReasonSomethingElseConsequence => 'You write what happened';

  @override
  String get skipReasonSave => 'Save reason';

  @override
  String get skipReasonChange => 'Change reason';

  @override
  String get skipReasonCancel => 'Cancel';

  @override
  String get skipReasonNoteLabel => 'What happened?';

  @override
  String get skipReasonChooseFirst => 'Choose a reason first';

  @override
  String get skipReasonSayWhatHappened => 'Say what happened';

  @override
  String s2Summary(int counted, int outOfStock, int toGo) {
    return '$counted counted · $outOfStock out of stock · $toGo to go';
  }

  @override
  String get s2NotCounted => 'Not counted';

  @override
  String get s2OutOfStockWord => 'Out of stock';

  @override
  String get s2TypeCount => 'Type a count';

  @override
  String get s2OneFewer => 'One fewer';

  @override
  String get s2OneMore => 'One more';

  @override
  String s2PartCounted(int toGo) {
    return 'Saving now records $toGo products as not counted — never as empty.';
  }

  @override
  String s2CountedOf(int counted, int total) {
    return '$counted of $total counted';
  }

  @override
  String get s10NotFinal =>
      'Worked out on this phone. The final score comes back when the visit sends.';

  @override
  String get s10NotMeasured => 'Not measured on this visit';

  @override
  String s10ScoreSemantics(String score, String band) {
    return 'Weighted total $score out of 100, $band';
  }

  @override
  String get s5NoPriceYet => 'No price entered';

  @override
  String get s6NoCompetitors =>
      'No competitor on this shelf yet. Add one if you see it.';

  @override
  String get s8NoRisks => 'Nothing flagged yet.';

  @override
  String get s9NoTasks => 'No extra tasks yet.';

  @override
  String s9AddedTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks queued for sync',
      one: '1 task queued for sync',
    );
    return '$_temp0';
  }
}
