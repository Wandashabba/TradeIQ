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
  String get captureButton => 'Open camera';

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
  String get todayTitle => 'Today';

  @override
  String get todayLoadErrorTitle => 'Could not load your route';

  @override
  String get todayLoadErrorDetail => 'You can still start a visit yourself.';

  @override
  String get todayNoRouteTitle => 'No route today';

  @override
  String get todayEmptyPlanTitle => 'Your plan is empty';

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
  String get myWorkTitle => 'My work';

  @override
  String get myWorkSubtitle => 'Everything you’ve captured';

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
  String submitNotConfirmedLine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sections could not be confirmed — the manager is told',
      one: '1 section could not be confirmed — the manager is told',
    );
    return '$_temp0';
  }

  @override
  String submitCantConfirmTask(String section) {
    return '$section could not be confirmed';
  }

  @override
  String get submitCantConfirmTaskLine => 'The manager is told · not confirmed';

  @override
  String submitTaskSemanticsUrgent(String title, String line) {
    return 'Urgent. $title. $line';
  }

  @override
  String submitTaskSemanticsRoutine(String title, String line) {
    return 'Routine. $title. $line';
  }

  @override
  String submitCantConfirmSemantics(String section, String reason) {
    return 'Not confirmed. $section. $reason';
  }

  @override
  String get submitPrimarySemantics => 'Submit this visit to your manager';

  @override
  String submitCapturedSemantics(int done, int total, String line) {
    return '$done of $total sections complete. $line';
  }

  @override
  String get submitNothingToRaiseHeadline => 'Nothing to raise';

  @override
  String get submitGateBack => 'Go back and change something';

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
  String get locationNoticeSummary => 'Nothing is sent in the background.';

  @override
  String get locationNoticeExpand => 'Read what is shared';

  @override
  String get locationNoticeCollapse => 'Close this';

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
  String get outcomeOpenMyWork => 'Open my work';

  @override
  String outcomeHeroSemantics(int score, String band) {
    return 'Perfect-store score, $score out of 100. $band.';
  }

  @override
  String outcomeDimensionSemantics(String name, int value) {
    return '$name, $value out of 100.';
  }

  @override
  String outcomeDimensionUnmeasuredSemantics(String name, String reason) {
    return '$name, not measured. $reason';
  }

  @override
  String get outcomeNotMeasuredGeneric => 'Not measured in this visit.';

  @override
  String get outcomeFirstScored => 'First scored visit here.';

  @override
  String get outcomeReconciledLead => 'Now scored';

  @override
  String get outcomeReconciledTail => '— it was';

  @override
  String outcomeReconciledSemantics(int now, int seen) {
    return 'Now scored $now. It was $seen when you saw it.';
  }

  @override
  String get outcomeReconciledReason => 'It was scored again after you saw it.';

  @override
  String get outcomeNextStoreSemantics => 'Go on to the next store';

  @override
  String get outcomeHeldSemantics =>
      'Submitted. Held on this phone until you have signal.';

  @override
  String get captureOpenCameraSemantics =>
      'Open the camera to photograph the shelf';

  @override
  String get captureTorchHint =>
      'Aisle dark? Switch your phone torch on before you shoot.';

  @override
  String get captureStampNote =>
      'Your photo is stamped with the time and where you are.';

  @override
  String get captureReviewTitle => 'Check the photo';

  @override
  String get captureDarkCaption => 'Dark — retake?';

  @override
  String get captureDarkSemantics => 'Dark — you may want to retake this.';

  @override
  String get captureUseIt => 'Use it';

  @override
  String get captureNoCamera => 'This phone has no camera we can reach.';

  @override
  String get captureGeotagged => 'geotagged';

  @override
  String get captureNoGeotag => 'no location on this photo';

  @override
  String capturePhotoMeta(String time, String tag) {
    return '$time · $tag';
  }

  @override
  String capturePhotoSemantics(String time) {
    return 'Photo taken $time, held on this phone.';
  }

  @override
  String get mapTitle => 'Map';

  @override
  String mapStoresFact(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stores',
      one: '1 store',
    );
    return '$_temp0';
  }

  @override
  String get mapRouteHeading => 'Today’s route';

  @override
  String get mapRouteEmptyLine => 'No route planned for today.';

  @override
  String get mapPatchHeading => 'The rest of your patch';

  @override
  String get mapStateDone => 'Visited today';

  @override
  String get mapStateNext => 'Next up';

  @override
  String get mapStatePlanned => 'On today’s route';

  @override
  String get mapStateTerritory => 'In your patch';

  @override
  String get mapStateDisputed => 'Pin under review';

  @override
  String get mapDisputedLine =>
      'Someone has reported this pin as wrong, so the position on the map may not be the shop.';

  @override
  String get mapYouAreHere => 'You are here';

  @override
  String get mapLocationDenied =>
      'Location is off for this app, so there are no distances and no dot for where you are. The stores are still right.';

  @override
  String get mapLocationServicesOff =>
      'Location is switched off on this phone, so there are no distances and no dot for where you are. The stores are still right.';

  @override
  String get mapLocationNoFix =>
      'This phone cannot get a fix yet, so there are no distances and no dot for where you are. The stores are still right.';

  @override
  String get mapTilesOffTitle => 'No map here';

  @override
  String get mapTilesOffBody =>
      'The map will not load — there is nothing to fetch it with. Your stores are listed below, and the list needs no connection.';

  @override
  String get mapVeldNote =>
      'The map is off in bright sun. Your stores are listed below, nearest first.';

  @override
  String get mapEmptyTitle => 'No stores yet';

  @override
  String get mapEmptyBody =>
      'There is no route for today and no store in your patch. A manager assigns both.';

  @override
  String get mapLoadErrorTitle => 'Your stores did not load';

  @override
  String get mapLoadErrorDetail =>
      'We could not reach the server. Your day still works — pick a store and check in.';

  @override
  String mapShowingNearest(int shown, int total) {
    return 'Showing the $shown nearest of $total stores.';
  }

  @override
  String mapShowingFirst(int shown, int total) {
    return 'Showing $shown of $total stores.';
  }

  @override
  String get mapCheckInAgain => 'Check in again';

  @override
  String get mapVisitedTodayLine => 'You checked in here today.';

  @override
  String mapCircleAtDoor(String name) {
    return 'Check in at $name';
  }

  @override
  String mapPinHint(String name, String state) {
    return '$name, $state. Double-tap for what you can do here.';
  }

  @override
  String get mapLegendLabel => 'What the pins mean';

  @override
  String get sheetClose => 'Close';

  @override
  String get askTitle => 'Ask TradeIQ';

  @override
  String get askHistoryAction => 'History';

  @override
  String askHistoryActionCount(int count) {
    return 'History · $count';
  }

  @override
  String get askComposerLabel => 'Ask a question';

  @override
  String get askComposerHint => 'Team, stock, shelf, competitors';

  @override
  String get askComposerRephrase => 'Ask again, or rephrase';

  @override
  String get askSend => 'Send this question';

  @override
  String get askSendUnavailable => 'Send, unavailable, needs a connection';

  @override
  String get askSendNothingTyped => 'Send, unavailable, nothing typed yet';

  @override
  String get askStop => 'Stop the answer';

  @override
  String get askQuestionSent => 'Question sent';

  @override
  String get askYourQuestion => 'Your question';

  @override
  String get askEmptyHeadline => 'Ask about your territory.';

  @override
  String get askEmptyBody =>
      'I read your sales, stock, shelf and competitor data and explain what I find. I cannot change anything.';

  @override
  String get askTryOneOfThese => 'Try one of these';

  @override
  String get askReadOnlyFootnote =>
      'Read-only. Nothing you ask here changes your data.';

  @override
  String get askExampleTeam => 'How has my team been performing this month?';

  @override
  String get askExampleTeamReads => 'reads visit history and scorecards';

  @override
  String get askExampleStock => 'Which outlets keep running out of stock?';

  @override
  String get askExampleStockReads => 'reads stock on shelf, worst first';

  @override
  String get askExampleShelf => 'What is our share of shelf year to date?';

  @override
  String get askExampleShelfReads => 'reads shelf audits and photos';

  @override
  String get askExampleFraud => 'Show me any visits that look suspicious.';

  @override
  String get askExampleFraudReads => 'reads flagged visits and GPS';

  @override
  String get askSuggestionsGroup => 'Four example questions';

  @override
  String askSuggestionSemantic(String question, String reads) {
    return 'Ask: $question This $reads';
  }

  @override
  String get askNotEnabledHeadline => 'Not switched on yet.';

  @override
  String get askNotEnabledBody =>
      'Ask TradeIQ is being rolled out gradually — speak to your TradeIQ contact to be included.';

  @override
  String get askStepsLookingUp => 'Looking things up';

  @override
  String get askStepsWriting => 'Writing the answer';

  @override
  String get askStepsStillWorking => 'This one is taking a while';

  @override
  String get askStepsStarting => 'Reading your question';

  @override
  String askStepsStillWorkingOn(String label) {
    return 'Still working on $label.';
  }

  @override
  String get askStopShort => 'Stop';

  @override
  String get askNavFloor => 'Floor';

  @override
  String get askNavWork => 'Work';

  @override
  String get askNavAsk => 'Ask';

  @override
  String get askNavMenu => 'Menu';

  @override
  String get askStepsLive => 'Live';

  @override
  String askStepsUnavailable(String label) {
    return '$label — unavailable';
  }

  @override
  String askStepsDidNotFinish(String label) {
    return '$label — did not finish';
  }

  @override
  String askStepsMore(int count) {
    return '$count more';
  }

  @override
  String askStepsChecked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Checked $count sources',
      one: 'Checked 1 source',
    );
    return '$_temp0';
  }

  @override
  String askStepsUnavailableCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unavailable',
      one: '1 unavailable',
    );
    return '$_temp0';
  }

  @override
  String get askStepsNoneAnswered => 'No sources answered';

  @override
  String get askStepsShow => 'show the steps';

  @override
  String get askStepsHide => 'hide the steps';

  @override
  String askStepsSemantic(String summary, String action) {
    return '$summary, $action';
  }

  @override
  String askStepProgress(int index, int total, String label) {
    return 'Step $index of $total, $label';
  }

  @override
  String get askCallout => 'What explains it';

  @override
  String get askSources => 'Sources';

  @override
  String get askSourcesNothingUsable =>
      'The web search returned nothing usable.';

  @override
  String askSourcesGroup(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sources, $count items',
      one: 'Sources, 1 item',
    );
    return '$_temp0';
  }

  @override
  String askSourceSemantic(int index, String domain, String title) {
    return 'Web source $index, $domain, $title, opens in browser';
  }

  @override
  String get askSourceOpensInBrowser => 'opens in browser';

  @override
  String get askSourceUnreachable =>
      'Could not open a browser. Long-press to copy the address.';

  @override
  String get askSourceCopied => 'Address copied';

  @override
  String askSourceCopiedPreview(String snippet) {
    return 'Address copied. The page says: $snippet';
  }

  @override
  String askShowAllSources(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Show all $count sources',
      one: 'Show 1 source',
    );
    return '$_temp0';
  }

  @override
  String askShowAll(int count) {
    return 'Show all $count';
  }

  @override
  String get askNoticeLookupBudget =>
      'I ran out of lookups for this question, so this answer may be incomplete.';

  @override
  String get askNoticeTimeBudget =>
      'I ran out of time on this question, so this answer may be incomplete.';

  @override
  String get askNoticeToolCallRefused =>
      'I stopped short of the lookups I planned, so this answer may be incomplete.';

  @override
  String get askNoticeGeneral => 'This answer may be incomplete.';

  @override
  String get askNoticeNarrower => 'Ask a narrower follow-up to go further.';

  @override
  String askNoticeSemantic(String reason, String advice) {
    return 'Notice: this answer may be incomplete. $reason $advice';
  }

  @override
  String get askFigures => 'Figures for this answer';

  @override
  String get askWorstFirst => 'Worst first';

  @override
  String get askOverTime => 'Over time';

  @override
  String get askUnsupportedView =>
      'This answer includes a view your app version cannot draw yet. The summary above still applies.';

  @override
  String get askUnprovenancedFigures =>
      'Figures are not shown for answers that used the web, because this app version cannot tell which came from outside.';

  @override
  String get askLoadingFigures => 'Loading figures';

  @override
  String get askLoading => 'Loading';

  @override
  String askNotEnoughToPlot(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Not enough data to plot — $count periods returned.',
      one: 'Not enough data to plot — 1 period returned.',
      zero: 'Not enough data to plot — nothing returned.',
    );
    return '$_temp0';
  }

  @override
  String askNoComparisonData(String label) {
    return 'no data for $label';
  }

  @override
  String get askChartSolidLine => 'solid line';

  @override
  String get askChartDashedLine => 'dashed line';

  @override
  String askLegend(String entries) {
    return 'Legend: $entries';
  }

  @override
  String askLegendEntry(String name, String channel) {
    return '$name, $channel';
  }

  @override
  String askBarSemantic(String name, String value, int index, int total) {
    return '$name, $value, position $index of $total';
  }

  @override
  String get askBarWorst => 'worst';

  @override
  String get askOutsideData => 'Outside data';

  @override
  String askOutsideRead(String date) {
    return 'read $date';
  }

  @override
  String askOutsidePublisher(String publisher, String date) {
    return '$publisher, read $date. Not TradeIQ data, and not added to any total above.';
  }

  @override
  String askOutsideUnnamed(String date) {
    return 'Read from outside TradeIQ on $date. Not TradeIQ data, and not added to any total above.';
  }

  @override
  String askOutsideStale(int days) {
    return '$days days old';
  }

  @override
  String get askOutsideFigure => 'outside figure';

  @override
  String get askTryAgain => 'Try again';

  @override
  String get askStopped => 'Stopped.';

  @override
  String get askStoppedSemantic => 'Stopped. The answer is incomplete.';

  @override
  String get askAskAgain => 'Ask again';

  @override
  String get askCopyAnswer => 'Copy this answer';

  @override
  String get askAnswerCopied => 'Answer copied';

  @override
  String get askAskAgainAnswer => 'Ask this question again';

  @override
  String get askFailedTwice =>
      'This has failed twice. It may be the connection rather than the question.';

  @override
  String askErrorSemantic(String message) {
    return 'Error. $message';
  }

  @override
  String get askOffline => 'No connection — Ask TradeIQ needs one.';

  @override
  String get askSessionEnded => 'Your session ended. Sign in to ask again.';

  @override
  String get askSessionEndedSemantic =>
      'Your session ended. Sign in to ask again. Your answers are still on screen.';

  @override
  String get askSignIn => 'Sign in';

  @override
  String get askHeld => 'Held';

  @override
  String get askHistoryTitle => 'This conversation';

  @override
  String askHistorySubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Held on this device until you leave the screen. $count questions.',
      one: 'Held on this device until you leave the screen. 1 question.',
    );
    return '$_temp0';
  }

  @override
  String askHistoryLimit(int count) {
    return 'only the last $count are sent with a new question';
  }

  @override
  String get askHistoryEmpty => 'Nothing yet.';

  @override
  String get askHistoryEmptyBody =>
      'Your questions will be listed here while you are on this screen.';

  @override
  String askHistoryRowSemantic(String time, String question) {
    return 'Asked at $time: $question Go to this answer.';
  }

  @override
  String get askNow => 'now';

  @override
  String get askStartOver => 'Start a new conversation';

  @override
  String get askStartOverTitle => 'Start a new conversation?';

  @override
  String askStartOverBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'This one is not saved. The $count questions and their answers go.',
      one: 'This one is not saved. The 1 question and its answer go.',
    );
    return '$_temp0';
  }

  @override
  String get askCarryOn => 'Carry on';

  @override
  String get askStartOverConfirm => 'Start over';

  @override
  String get askStartOverMidTurnTitle => 'A question is still being answered.';

  @override
  String get askStartOverMidTurnBody => 'Starting over will stop it.';

  @override
  String get askKeepWaiting => 'Keep waiting';

  @override
  String get askStopAndStartOver => 'Stop and start over';

  @override
  String get askShowFullQuestion => 'Show the full question';

  @override
  String askFollowUpSemantic(String question) {
    return 'Ask: $question';
  }

  @override
  String get askFollowUpDisabled =>
      'unavailable while the answer is being written';

  @override
  String askSeconds(String seconds) {
    return '${seconds}s';
  }

  @override
  String askPoints(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'pts',
      one: 'pt',
    );
    return '$_temp0';
  }

  @override
  String get askAnswer => 'Answer';

  @override
  String get askOpenFullView => 'Open full view';

  @override
  String askOpenFullViewOf(String name) {
    return 'Open the full view of $name';
  }

  @override
  String get askQuestionCopied => 'Question copied';

  @override
  String get askTileNoData => 'Nothing measured in this window';

  @override
  String get askTileUpdatedTo => 'Updated to';

  @override
  String get askTileUpdatedFrom => 'from';

  @override
  String askTileUpdatedAt(String time) {
    return 'Updated at $time.';
  }

  @override
  String askTileWasValue(String value, String time) {
    return 'Was $value at $time.';
  }

  @override
  String get askPillarSales => 'Sales';

  @override
  String get askPillarStock => 'Stock';

  @override
  String get askPillarVisibility => 'Visibility';

  @override
  String get askPillarCompetition => 'Competition';

  @override
  String get askPillarFigures => 'Pillar figures';

  @override
  String get askPillarNoFigures => 'No figures were returned for this period.';

  @override
  String askPillarComparedWith(String label) {
    return 'Change is measured against $label.';
  }

  @override
  String get askMetricOsa => 'On-shelf availability';

  @override
  String get askMetricShareOfShelf => 'Share of shelf';

  @override
  String get askMetricVisibility => 'Visibility compliance';

  @override
  String get askMetricPrice => 'Price compliance';

  @override
  String get askMetricAttainment => 'Attainment';

  @override
  String get askMetricRateOfSale => 'Rate of sale';

  @override
  String get askMetricOutletsWithStockout => 'Outlets with a stockout';

  @override
  String get askMetricOutOfStockLines => 'Out-of-stock lines';

  @override
  String get askMetricLinesObserved => 'Lines observed';

  @override
  String get askMetricCompetitorFacings => 'Competitor facings';

  @override
  String get askMetricExecutionScore => 'Execution score';

  @override
  String get askMetricPerfectStore => 'Perfect-store rate';

  @override
  String get askScorecardTitle => 'Agent scorecard';

  @override
  String askScorecardScored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count scored visits',
      one: '1 scored visit',
    );
    return '$_temp0';
  }

  @override
  String get askScorecardAverage => 'Average score';

  @override
  String get askScorecardTeam => 'Team average';

  @override
  String get askScorecardNoTeam =>
      'No other agent has a scored visit in this period.';

  @override
  String get askScorecardVisits => 'Visits';

  @override
  String get askScorecardOutlets => 'Outlets';

  @override
  String get askScorecardVsTeam => 'vs team';

  @override
  String get askMapTitle => 'Outlets with stockouts';

  @override
  String askMapCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count outlets',
      one: '1 outlet',
    );
    return '$_temp0';
  }

  @override
  String get askMapUnreadable =>
      'The outlet locations for this answer could not be read. The summary above still applies.';

  @override
  String askMapPin(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines',
      one: '1 line',
    );
    return '$name, $_temp0 out of stock';
  }

  @override
  String get askMapNotInVeld =>
      'Maps are not drawn in Veld. The outlets are listed instead.';

  @override
  String get visitPinTooFarToReport =>
      'This is too far to report the pin from here. Ask your manager to correct this store.';

  @override
  String get pinDisputeEyebrow => 'The pin is wrong';

  @override
  String get pinDisputeTitle => 'Report the pin and start the visit';

  @override
  String get pinDisputeEvidenceEyebrow => 'Sent with your report';

  @override
  String get pinDisputeDistanceLine =>
      'from where the app has this shop, measured just now';

  @override
  String pinDisputeDistanceSemantics(int meters) {
    return 'You are $meters metres from where the app has this shop.';
  }

  @override
  String get pinDisputePositionLine =>
      'Where you are standing, as your phone recorded it';

  @override
  String get pinDisputePhotoLine => 'Your photo of the storefront';

  @override
  String get pinDisputeExplain =>
      'The visit starts outside the fence and stays flagged. Your manager sees where you were and can move the pin. You cannot clear the flag yourself.';

  @override
  String get pinDisputeNoteLabel => 'What is wrong with the pin? (optional)';

  @override
  String get pinDisputeNoteHint =>
      'e.g. the pin is on the depot, the shop is on Main Road';

  @override
  String get pinDisputeAddPhoto => 'Add a photo of the storefront';

  @override
  String get pinDisputeRetakePhoto => 'Retake the photo';

  @override
  String get pinDisputePhotoAdded =>
      'Storefront photo added. It is sent with the visit.';

  @override
  String get pinDisputePhotoLabel => 'Storefront';

  @override
  String get pinDisputePhotoHint =>
      'Stand back far enough to get the shop name and the door in one shot.';

  @override
  String get pinDisputeSubmit => 'Start the visit, flagged';

  @override
  String get pinDisputeBack => 'Back to the distance';

  @override
  String pinDisputeFailed(String reason) {
    return 'The visit could not start: $reason';
  }

  @override
  String get visitFlagOutOfFence => 'Out of fence';

  @override
  String visitFlagMetres(int meters) {
    return '$meters m';
  }

  @override
  String visitFlagOutOfFenceSemantics(int meters) {
    return 'Out of fence, $meters metres. Double-tap for detail.';
  }

  @override
  String get visitFlagPinReported => 'Pin reported';

  @override
  String get visitFlagPinReportedSemantics =>
      'Pin reported, for your manager to review. Double-tap for detail.';

  @override
  String get visitFlagSheetTitle => 'Checked in outside the fence';

  @override
  String visitFlagSheetBody(int meters) {
    return 'You were $meters m from this store’s pin and reported the pin as wrong. Your position and distance went with the visit. Your manager reviews it and can move the pin; the flag stays until they do.';
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
  String s2StockSavedPartial(int counted, int total) {
    return 'Saved $counted of $total — the rest are not counted, never empty';
  }

  @override
  String get s2JumpToUncounted => 'Jump to the first uncounted';

  @override
  String get s10NotFinal =>
      'Worked out on this phone. The final score comes back when the visit sends.';

  @override
  String get s10NotMeasured => 'Not measured on this visit';

  @override
  String get s10NothingCaptured =>
      'Nothing has been captured on this visit yet, so there is no score to work out.';

  @override
  String get s10NoScoreSemantics =>
      'No weighted total yet. Nothing has been captured on this visit.';

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

  @override
  String get s2TypeCountFirst => 'Type a count first';

  @override
  String sectionEntryName(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'competitor': 'Competitor',
      'risk': 'Risk',
      'other': 'Task',
    });
    return '$_temp0';
  }

  @override
  String sectionEntryNameLower(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'competitor': 'competitor',
      'risk': 'risk',
      'other': 'task',
    });
    return '$_temp0';
  }

  @override
  String get sectionEntryUnnamed => 'Not named yet';

  @override
  String get myWorkSendNow => 'Send now';

  @override
  String get myWorkSendNowBlocked => 'Nothing is waiting to send.';

  @override
  String myWorkSignedOutTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'You’re signed out. Sign in and your $count held captures will send.',
      one: 'You’re signed out. Sign in and your 1 held capture will send.',
    );
    return '$_temp0';
  }

  @override
  String get myWorkSignIn => 'Sign in';

  @override
  String get myWorkShowOlder => 'Show older';

  @override
  String myWorkSentCapped(int shown, int total) {
    return 'Showing the $shown most recently sent of $total';
  }

  @override
  String get myWorkEmptyBody =>
      'Everything you capture in a store shows up here until the server has it.';

  @override
  String get myWorkLoadErrorBody =>
      'Your work is still on this phone. Nothing is lost.';

  @override
  String get myWorkRetry => 'Try again';

  @override
  String get outboxWaiting => 'Waiting';

  @override
  String get outboxSending => 'Sending';

  @override
  String get outboxRetrying => 'Retrying';

  @override
  String get outboxSent => 'Sent';

  @override
  String get outboxNeedsYou => 'Needs you';

  @override
  String get outboxWaitingTurn => 'Waiting its turn';

  @override
  String get outboxWaitingSentence => 'Waiting for signal';

  @override
  String get outboxSendingSentence => 'Going up now';

  @override
  String get outboxSentSentence => 'The server has it';

  @override
  String outboxQueuedAt(String time) {
    return 'queued $time';
  }

  @override
  String outboxSentAt(String time) {
    return 'sent $time';
  }

  @override
  String outboxLastTriedAt(String time) {
    return 'last tried $time';
  }

  @override
  String outboxAttempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tried $count times',
      one: 'Tried once',
      zero: 'Not tried yet',
    );
    return '$_temp0';
  }

  @override
  String get outboxSendThisNow => 'Send this one now';

  @override
  String get outboxDiscard => 'Discard this capture';

  @override
  String get outboxDiscardConfirm => 'Yes, discard it';

  @override
  String get outboxDiscardKeep => 'Keep it';

  @override
  String outboxDiscardWhatIsLost(String item) {
    return 'This $item has not reached the server. Discard it and it is gone from this phone — there is no copy anywhere else.';
  }

  @override
  String outboxDiscardTakesDependents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count captures from this visit go with it, because they cannot send without the visit.',
      one:
          '1 capture from this visit goes with it, because it cannot send without the visit.',
    );
    return '$_temp0';
  }

  @override
  String get outboxNothingToDo => 'Nothing to do — the server has it.';

  @override
  String get outboxRejectedNote =>
      'The server refused this exactly as it is, so sending it again unchanged will fail the same way. Nothing has been altered for you.';

  @override
  String get outboxWaitingTurnNote =>
      'This sends itself as soon as the visit above it does. Nothing is wrong.';

  @override
  String get outboxSignedOutNote =>
      'Your session ended. Sign in and this sends itself.';

  @override
  String get outboxHeld => 'Held';

  @override
  String get outboxHeldUntilSignIn => 'Held until you sign in';

  @override
  String outboxItemId(int id, String type) {
    return 'Capture $id · $type';
  }

  @override
  String get pickerEmptyTitle => 'No stores here';

  @override
  String get pickerEmptyBodyMine =>
      'Nothing is filed under your territories yet. Switch to all stores, or add the one you are standing in.';

  @override
  String get pickerEmptyBodyAll =>
      'This client has no stores on the server yet. Add the one you are standing in.';

  @override
  String get pickerLoadErrorBody =>
      'Your stores are fetched from the server. Nothing you have captured is affected.';

  @override
  String get pickerScopeHeading => 'Which stores';

  @override
  String get pickerStoresHeading => 'Stores';

  @override
  String get syncBannerOpen => 'tap to open your work';

  @override
  String get commonClose => 'Close';

  @override
  String pickerStartVisitSemantics(String name, String code) {
    return '$name, $code. Double-tap to start a visit here.';
  }

  @override
  String syncBannerNeedsYou(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'need you',
      one: 'needs you',
    );
    return '$_temp0';
  }

  @override
  String get errorTooManyAttempts =>
      'Too many attempts. Wait a few minutes, then try again.';

  @override
  String get errorUpdateRequired =>
      'This version of the app is too old. Update TradeIQ to carry on.';

  @override
  String get passwordRuleHelp =>
      'At least 12 characters. Three ordinary words are easy to type and hard to guess.';

  @override
  String get passwordTooShort => 'Too short: use at least 12 characters.';

  @override
  String get passwordTooLong =>
      'Too long for a password here. Use fewer characters.';

  @override
  String get passwordIsEmail => 'Your password cannot be your email address.';

  @override
  String get passwordMismatch => 'The two new passwords do not match.';

  @override
  String get passwordRejected =>
      'That password was not accepted. Use at least 12 characters, not your email address and not an obvious phrase.';

  @override
  String get passwordShow => 'Show passwords';

  @override
  String get passwordNeedsNew => 'Choose a new password';

  @override
  String get passwordNeedsConfirm => 'Type the new password again';

  @override
  String get passwordFailedTitle => 'Your password was not changed';

  @override
  String get passwordOtherSessions =>
      'Other phones signed in to your account stay signed in until their session ends, up to 12 hours. If a phone is lost, ask your manager to switch the account off.';

  @override
  String get forgotTitle => 'Reset your password';

  @override
  String get forgotBack => 'Back to sign in';

  @override
  String get forgotIntro =>
      'Ask your manager for a reset code. They make it in TradeIQ and read it out to you. It works once, for 15 minutes.';

  @override
  String get forgotEmailLabel => 'Email';

  @override
  String get forgotCodeLabel => 'Reset code';

  @override
  String get forgotCodeHint => '8 digits';

  @override
  String get forgotNewPasswordLabel => 'New password';

  @override
  String get forgotConfirmLabel => 'New password again';

  @override
  String get forgotSubmit => 'Set new password';

  @override
  String get forgotNeedsEmail => 'Enter your email first';

  @override
  String get forgotNeedsCode => 'Enter the 8-digit code from your manager';

  @override
  String get forgotCodeRejectedTitle => 'That code did not work';

  @override
  String get forgotCodeRejectedBody =>
      'It may be mistyped, used already or older than 15 minutes. Check the email too. Your manager can make a new code.';

  @override
  String get forgotDoneTitle => 'Your password is changed';

  @override
  String get forgotDoneBody => 'Sign in with your new password.';

  @override
  String get forgotGoToSignIn => 'Go to sign in';

  @override
  String get changePasswordTitle => 'Change password';

  @override
  String get changePasswordBack => 'Back to settings';

  @override
  String get changeCurrentLabel => 'Current password';

  @override
  String get changeNeedsCurrent => 'Enter your current password';

  @override
  String get changeWrongCurrent => 'That is not your current password.';

  @override
  String get changeDoneTitle => 'Password changed';

  @override
  String get changeDoneBody =>
      'You stay signed in on this phone. Use the new password next time you sign in.';

  @override
  String get changeDone => 'Done';

  @override
  String get settingsAccountHeading => 'Your account';

  @override
  String get updateTitle => 'Update TradeIQ';

  @override
  String get updateBody =>
      'This version of the app is too old for the server. Install the newest version from where you got TradeIQ, then open it again.';

  @override
  String get updateNothingLost =>
      'Nothing saved on this phone is deleted by this.';

  @override
  String get updateTryAgain => 'Try again';

  @override
  String updateVersions(String current, String minimum) {
    return 'This phone has version $current. Version $minimum or newer is needed.';
  }

  @override
  String updateVersionNoMinimum(String current) {
    return 'This phone has version $current. A newer version is needed.';
  }

  @override
  String get submitSectionsUnread => 'Could not read which sections are done';

  @override
  String get submitSectionsUnreadTask => 'Your sections could not be read';

  @override
  String get submitSectionsUnreadRowLine =>
      'Something may be missing from this list';

  @override
  String get submitSectionsUnreadNote =>
      'A section that could not be confirmed may be missing from this list. Go back and open your sections to check before you submit.';

  @override
  String submitCapturedUnreadSemantics(String line) {
    return 'Could not read which sections are done. $line';
  }

  @override
  String get outcomePreviousUnknown =>
      'Your last visit here could not be loaded, so there is nothing to compare this score with.';

  @override
  String get outboxSeeScore => 'See how it scored';

  @override
  String get meTitle => 'Me';

  @override
  String get meEarnedHeading => 'What I\'ve earned';

  @override
  String get meVisitsHeading => 'My visits';

  @override
  String get meLedgerHeading => 'How you earned it';

  @override
  String get mePointsEyebrow => 'POINTS ALL TIME';

  @override
  String get meAllTime => 'All time';

  @override
  String get meRankEyebrow => 'RANK';

  @override
  String get meLoadErrorDetail =>
      'Your work is safe on this phone. This part comes from the server and fills in when it answers.';

  @override
  String get meNotRanked =>
      'Only field agents are ranked, so you do not have a place on this board.';

  @override
  String get meNoPointsYet =>
      'No points yet. Points arrive when a visit is submitted or a task is closed.';

  @override
  String get meNoScheme => 'No reward is running.';

  @override
  String meRewardProgress(String value, String total) {
    return '$value of $total';
  }

  @override
  String meRewardToGo(String remaining, String reward) {
    return '$remaining to go · $reward';
  }

  @override
  String meRewardReached(String reward) {
    return 'Reward reached — $reward.';
  }

  @override
  String meRewardPoints(int points) {
    String _temp0 = intl.Intl.pluralLogic(
      points,
      locale: localeName,
      other: '$points points',
      one: '1 point',
    );
    return '$_temp0';
  }

  @override
  String get mePointsHonesty =>
      'Points are worked out on the server. They can change if a visit is reviewed.';

  @override
  String get meLedgerEmpty => 'Nothing has earned points yet.';

  @override
  String get meVisitsEmpty => 'No visits yet';

  @override
  String get meVisitsEmptyDetail =>
      'Every store you check into shows up here — when you went, how long you stayed, and what it scored.';

  @override
  String get meVisitsLoadError => 'Your visits did not load';

  @override
  String meVisitsShowing(int shown) {
    return 'Showing $shown. There are older visits.';
  }

  @override
  String get meVisitsShowOlder => 'Show older visits';

  @override
  String get meVisitsMoreFailed => 'Older visits did not load';

  @override
  String get meNotScoredYet => 'Waiting to be scored';

  @override
  String get meVisitOpen => 'Still open on this phone';

  @override
  String meVisitMeta(String day, String dwell, String tasks) {
    return '$day · $dwell · $tasks';
  }

  @override
  String meDwellMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get meDwellUnknown => 'time not recorded';

  @override
  String meTasksRaised(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks raised',
      one: '1 task raised',
      zero: 'no tasks raised',
    );
    return '$_temp0';
  }

  @override
  String meCapturedCount(int captured, int total, int photos) {
    String _temp0 = intl.Intl.pluralLogic(
      photos,
      locale: localeName,
      other: '$photos photos',
      one: '1 photo',
      zero: 'no photos',
    );
    return '$captured of $total sections · $_temp0';
  }

  @override
  String meDistanceMeters(int metres) {
    return '$metres m from the door';
  }

  @override
  String get meDistanceUnknown => 'distance not measured';

  @override
  String get meOutOfFence => 'Out of fence';

  @override
  String get meReviewed => 'Reviewed';

  @override
  String get mePinReported => 'You reported the pin as wrong';

  @override
  String meOnThisPhone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count captures have not sent',
      one: '1 capture has not sent',
    );
    return '$_temp0';
  }

  @override
  String get meOnThisPhoneDetail =>
      'Showing what has reached the server. Today\'s work appears here once it sends.';

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
    return 'scored $score';
  }

  @override
  String meRewardSemantics(String value, String total, String line) {
    return 'Progress to reward: $value of $total. $line';
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
      other: 'plus $points points',
      one: 'plus 1 point',
    );
    return '$_temp0';
  }

  @override
  String mePointsMinus(int points) {
    String _temp0 = intl.Intl.pluralLogic(
      points,
      locale: localeName,
      other: 'minus $points points',
      one: 'minus 1 point',
    );
    return '$_temp0';
  }

  @override
  String get meEarningsLoadError => 'Your points did not load';

  @override
  String get meReasonVisitSubmitted => 'Visit submitted';

  @override
  String get meReasonTaskClosed => 'Task closed';

  @override
  String get meReasonScorecard => 'Scorecard';

  @override
  String get meReasonPoints => 'Points';

  @override
  String meLedgerScoreRowSemantics(String reason, String day, String score) {
    return '$reason, $day, scored $score';
  }

  @override
  String get meContestsDetail => 'See where you stand';

  @override
  String get contestsBackToMe => 'Back to Me';

  @override
  String get contestsBackToToday => 'Back to Today';

  @override
  String get contestRankEyebrow => 'Your rank';

  @override
  String get contestPointsEyebrow => 'Your points';

  @override
  String contestRankOutOf(int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'of $total agents',
      one: 'of 1 agent',
    );
    return '$_temp0';
  }

  @override
  String get contestNobodyRanked => 'Nobody has earned points yet.';

  @override
  String get wordOn => 'On';

  @override
  String get wordOff => 'Off';

  @override
  String get notificationsBackToMe => 'Back to Me';

  @override
  String get notificationsBackToToday => 'Back to Today';

  @override
  String get notificationsHeading => 'What reaches this phone';

  @override
  String get loginFailedTitle => 'We could not sign you in';

  @override
  String get menuTitle => 'Menu';

  @override
  String get menuSubtitle => 'Everything the four tabs do not hold.';

  @override
  String get menuThisApp => 'This app';

  @override
  String get menuThemeLight => 'Light theme';

  @override
  String get menuThemeDark => 'Dark theme';

  @override
  String get menuChangePassword => 'Change password';

  @override
  String get menuSignOut => 'Sign out';

  @override
  String get navGroupOperate => 'Operate';

  @override
  String get navGroupInsight => 'Insight';

  @override
  String get navGroupConfigure => 'Configure';

  @override
  String get navTheFloor => 'The Floor';

  @override
  String get navExecutionOverview => 'Execution overview';

  @override
  String get navHome => 'Home';

  @override
  String get navTasks => 'Tasks';

  @override
  String get navAlerts => 'Alerts';

  @override
  String get navOrders => 'Orders';

  @override
  String get navBeatPlans => 'Beat plans';

  @override
  String get navDispatch => 'Dispatch';

  @override
  String get navMessages => 'Messages';

  @override
  String get navOutlets => 'Outlets';

  @override
  String get navAskTradeIq => 'Ask TradeIQ';

  @override
  String get navReports => 'Reports';

  @override
  String get navTrends => 'Trends';

  @override
  String get navSalesTargets => 'Sales targets';

  @override
  String get navLeaderboard => 'Leaderboard';

  @override
  String get navContests => 'Contests';

  @override
  String get navFraudReview => 'Fraud review';

  @override
  String get navCampaigns => 'Campaigns';

  @override
  String get navAlertRules => 'Alert rules';

  @override
  String get navTerritories => 'Territories';

  @override
  String get navUsers => 'Users';

  @override
  String get navAuditTemplates => 'Audit templates';

  @override
  String get navIncentives => 'Incentives';

  @override
  String get navWebhooks => 'Webhooks';

  @override
  String get navScoringConfig => 'Scoring config';

  @override
  String get sessionEndedTitle => 'You have been signed out';

  @override
  String get sessionEndedBody =>
      'Everything you captured is still on this phone. It sends itself when you sign in.';

  @override
  String get sessionEndedSignIn => 'Sign in to send them';

  @override
  String get sessionEndedNotNow => 'Not now';

  @override
  String get sessionHeldWhatIsHeld => 'What is held';

  @override
  String sessionHeldEntry(int count, String kind) {
    return '$count × $kind';
  }

  @override
  String sessionHeldWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count captures are waiting to send.',
      one: '1 capture is waiting to send.',
    );
    return '$_temp0';
  }

  @override
  String get torchTryAgain => 'Try again';

  @override
  String get torchStillFetching => 'Still fetching · this is slower than usual';

  @override
  String get roleFieldAgent => 'Field agent';

  @override
  String get territoriesTitle => 'Territories';

  @override
  String get territoriesFact =>
      'A territory groups outlets and the agents who work them.';

  @override
  String get territoriesRefresh => 'Refresh the territories list';

  @override
  String get territoriesSectionAll => 'All territories';

  @override
  String get territoriesNew => 'New territory';

  @override
  String get territoriesEmptyHeadline => 'No territories yet';

  @override
  String get territoriesEmptyBody =>
      'A territory groups outlets and the agents who work them. Create one and outlets can be assigned to it.';

  @override
  String territoryOutlets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count outlets',
      one: '1 outlet',
      zero: 'No outlets',
    );
    return '$_temp0';
  }

  @override
  String territoryAgents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count agents',
      one: '1 agent',
      zero: 'No agents',
    );
    return '$_temp0';
  }

  @override
  String get territoryCoveredWord => 'Covered';

  @override
  String territoryCoveredPercent(int percent) {
    return '$percent% covered';
  }

  @override
  String get territoryCoverageLoading => 'Loading coverage';

  @override
  String get territoryCoverageFailed => 'Coverage did not load';

  @override
  String get territoryCoverageNoOutlets => 'No outlets to cover yet';

  @override
  String get territoryUnassigned => 'Unassigned';

  @override
  String get territoryUnassignedLine => 'Nobody works this territory yet.';

  @override
  String get territoryCoverageCluster => 'Coverage for this territory';

  @override
  String get territoryOutletsWord => 'Outlets';

  @override
  String get territoryAgentsWord => 'Agents';

  @override
  String territoryVisitedOf(int visited, int total) {
    return '$visited of $total visited in this window';
  }

  @override
  String territoryVisitedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count visited',
      one: '1 visited',
      zero: 'None visited',
    );
    return '$_temp0';
  }

  @override
  String get territoryOpenMap => 'Open the map';

  @override
  String get territoryAssign => 'Assign an agent';

  @override
  String territoryAssignTitle(String territory) {
    return 'Assign to $territory';
  }

  @override
  String get territoryAssignSubtitle =>
      'Pick a field agent to work this territory.';

  @override
  String get territoryFieldAgents => 'Field agents';

  @override
  String get territoryAgentPicked => 'Picked';

  @override
  String get territoryAgentInactive => 'No longer active';

  @override
  String get territoryAssignBlocked => 'Pick a field agent first.';

  @override
  String get territoryAssignBack => 'Back to coverage';

  @override
  String territoryAssignDone(String territory) {
    return 'Assigned to $territory.';
  }

  @override
  String get territoryAssignFailed =>
      'That agent was not assigned. Nothing changed.';

  @override
  String get territoryNoAgentsHeadline => 'No field agents yet';

  @override
  String get territoryNoAgentsBody =>
      'Add a field agent under Users, then assign them here.';

  @override
  String get territoryNewTitle => 'New territory';

  @override
  String get territoryNewFact =>
      'A code is what the back office quotes. It must be unique for this client.';

  @override
  String get territoryBackToList => 'Back to territories';

  @override
  String get territoryNameLabel => 'Name';

  @override
  String get territoryNameHelp =>
      'What people call this patch — Gauteng North.';

  @override
  String get territoryCodeLabel => 'Code';

  @override
  String get territoryCodeHelp =>
      'The short code outlets are filed under — GP-N.';

  @override
  String get territoryRegionLabel => 'Region';

  @override
  String get territoryRegionHelp => 'Optional. The wider area this sits in.';

  @override
  String get territoryFieldRequired => 'This is required.';

  @override
  String get territoryCreate => 'Create territory';

  @override
  String get territoryCreateBlocked => 'A name and a code are both required.';

  @override
  String territoryCreated(String territory) {
    return '$territory created.';
  }

  @override
  String get territoryMapTitle => 'Territory map';

  @override
  String get territoryMapEmptyHeadline => 'No outlets in this territory';

  @override
  String get territoryMapEmptyBody =>
      'Outlets are filed under a territory by its code. Give an outlet this territory\'s code and it appears here.';

  @override
  String territoryTilesOffBody(String territory) {
    return 'The map did not load, so $territory is listed below instead. Every store and its state is there.';
  }

  @override
  String get territoryOutletVisited => 'Visited';

  @override
  String get territoryOutletNotVisited => 'Not visited yet';

  @override
  String get territoryOutletVisitedLine =>
      'A visit landed here inside the coverage window.';

  @override
  String get territoryOutletNotVisitedLine =>
      'No visit has landed here inside the coverage window.';

  @override
  String get territoryOutletPosition => 'Pinned at';

  @override
  String get territoryNotFoundHeadline => 'We could not find that territory';

  @override
  String get territoryNotFoundBody =>
      'It may have been deleted, or the link may belong to another client.';

  @override
  String get dispatchTitle => 'Dispatch';

  @override
  String get dispatchFact =>
      'Agents are ranked in-territory first, then by distance from their last known location.';

  @override
  String get dispatchOutletSection => 'The outlet';

  @override
  String get dispatchChooseOutlet => 'Choose an outlet';

  @override
  String get dispatchChooseOutletHint =>
      'Ranking needs a destination to measure distance from.';

  @override
  String dispatchChangeOutlet(String outlet) {
    return 'Outlet: $outlet. Choose a different one.';
  }

  @override
  String get dispatchNoOutletHeadline => 'Pick an outlet to rank agents';

  @override
  String get dispatchNoOutletBody =>
      'Nobody can be ranked until there is somewhere to rank them against.';

  @override
  String get dispatchNoOutletsHeadline => 'No outlets yet';

  @override
  String get dispatchNoOutletsBody => 'Add an outlet and it can be dispatched.';

  @override
  String get dispatchCandidatesSection => 'Candidates';

  @override
  String get dispatchNoCandidatesHeadline => 'No agent can be ranked';

  @override
  String get dispatchNoCandidatesBody =>
      'Ranking needs agents assigned to a territory, or a last known location — neither is recorded yet.';

  @override
  String get dispatchInTerritory => 'In territory';

  @override
  String get dispatchOutsideTerritory => 'Outside territory';

  @override
  String get dispatchRecommended => 'Recommended';

  @override
  String dispatchMetresAway(int metres) {
    return '$metres m away';
  }

  @override
  String get dispatchNoLocation => 'No last-known location';

  @override
  String get trendsTitle => 'Trends';

  @override
  String get trendsFact => 'Server-side buckets — weeks start Monday, UTC.';

  @override
  String get trendsFilters => 'Filters';

  @override
  String get trendsOverTime => 'Over time';

  @override
  String get trendsCompare => 'Compare territories';

  @override
  String get trendsDaily => 'Daily';

  @override
  String get trendsWeekly => 'Weekly';

  @override
  String get trendsServerDefault => 'Server default';

  @override
  String get trendsCustomRange => 'Custom range';

  @override
  String get trendsClearRange => 'Clear the range';

  @override
  String get trendsViewAs => 'Show as';

  @override
  String get trendsAsChart => 'Chart';

  @override
  String get trendsAsTable => 'Table';

  @override
  String get trendsPeriod => 'Period';

  @override
  String get trendsNotMeasured => 'Not measured';

  @override
  String get trendsDashed => 'dashed';

  @override
  String get trendsScrubHint => 'Drag across the chart to read one bucket.';

  @override
  String trendsChartHint(String name, int count) {
    return '$name, $count buckets. The exact figures are in the table view.';
  }

  @override
  String trendsGapNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count buckets not measured',
      one: '1 bucket not measured',
    );
    return '$_temp0';
  }

  @override
  String get trendsEmptyHeadline => 'No data in range';

  @override
  String get trendsEmptyBody =>
      'Trends fill in as visits are submitted and scored.';

  @override
  String get trendScorecards => 'Scorecard trend';

  @override
  String get trendScorecardsSeries => 'Weighted execution score';

  @override
  String get trendAvailability => 'Availability trend';

  @override
  String get trendAvailabilitySeries => 'On-shelf availability';

  @override
  String get trendPerfectStore => 'Perfect store trend';

  @override
  String get trendPerfectStoreSeries => 'Outlets passing every gate';

  @override
  String get trendsMetric => 'Metric';

  @override
  String get trendsMetricScore => 'Score';

  @override
  String get trendsMetricPerfectStore => 'Perfect store';

  @override
  String get trendsMetricAvailability => 'Availability';

  @override
  String get trendsMetricShareOfShelf => 'Share of shelf';

  @override
  String get trendsClientAverage => 'Client average';

  @override
  String get trendsTarget => 'Target';

  @override
  String trendsUnassignedNote(String samples) {
    return 'Also includes $samples from outlets outside every territory.';
  }

  @override
  String get trendsNoTerritoriesHeadline => 'No territories set up';

  @override
  String get trendsNoTerritoriesBody =>
      'Add territories and each one can be read against the client average.';

  @override
  String get trendsCompareEmptyBody =>
      'The comparison fills in as visits are submitted and scored.';

  @override
  String get trendsAboveAverage => 'Above average';

  @override
  String get trendsBelowAverage => 'Below average';

  @override
  String get trendsAtAverage => 'At average';

  @override
  String trendsAboveBy(String points, String samples) {
    return '$points points above the client average · $samples';
  }

  @override
  String trendsBelowBy(String points, String samples) {
    return '$points points below the client average · $samples';
  }

  @override
  String trendsLevelWith(String samples) {
    return 'Level with the client average · $samples';
  }

  @override
  String get trendsSmallSample => 'Small sample';

  @override
  String trendsTooFewToCompare(String samples) {
    return 'Too few to compare · $samples';
  }

  @override
  String get trendsNothingMeasuredHere => 'Nothing measured in this window';

  @override
  String trendsRank(int rank) {
    return 'Ranked $rank';
  }

  @override
  String get trendsUnranked => 'Not ranked';

  @override
  String get trendsShowing => 'Showing';

  @override
  String trendsAgainstClient(String territory) {
    return '$territory against the client average';
  }

  @override
  String trendsMeterHint(String territory, int value, int average) {
    return '$territory: $value, client average $average';
  }

  @override
  String trendsSamplesScorecards(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count scorecards',
      one: '1 scorecard',
    );
    return '$_temp0';
  }

  @override
  String trendsSamplesStockLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stock lines',
      one: '1 stock line',
    );
    return '$_temp0';
  }

  @override
  String trendsSamplesFacings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count visits with facings',
      one: '1 visit with facings',
    );
    return '$_temp0';
  }

  @override
  String get outletsTitle => 'Stores';

  @override
  String get outletsSubtitle =>
      'A store without coordinates cannot be geofenced.';

  @override
  String get outletsRefresh => 'Reload the store list';

  @override
  String get outletsCreateStore => 'Add a store';

  @override
  String get outletsSectionHeading => 'Stores';

  @override
  String get outletsNoLocation => 'No location';

  @override
  String get outletsNoCoordinates => 'No coordinates on file';

  @override
  String get outletsPlaced => 'Placed';

  @override
  String get outletsEmptyHeadline => 'No stores yet.';

  @override
  String get outletsEmptyBody => 'Add a store to put it on a beat plan.';

  @override
  String get outletsLoadErrorHeadline => 'The store list did not load.';

  @override
  String get outletsRetry => 'Try again';

  @override
  String get outletsPinReportsHeading => 'Open pin reports';

  @override
  String get outletsPinReportsNote =>
      'Agents who could not check in where the pin says the store is.';

  @override
  String get outletsPinReported => 'Pin reported';

  @override
  String outletsPinReportStood(String agent, String distance) {
    return '$agent stood $distance away';
  }

  @override
  String outletsPinReportsShowing(int shown) {
    return 'Showing $shown. There are more open reports.';
  }

  @override
  String get outletsPinReportsShowMore => 'Show more reports';

  @override
  String get outletsPinReportsMoreFailed =>
      'The rest of the queue did not load';

  @override
  String get outletDetailTitle => 'Store';

  @override
  String get outletDetailBack => 'Back to stores';

  @override
  String get outletDetailLoadErrorHeadline => 'This store did not load.';

  @override
  String outletDetailDisputesHeadline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count agents reported this pin as wrong',
      one: 'One agent reported this pin as wrong',
    );
    return '$_temp0';
  }

  @override
  String get outletDetailDisputesBody =>
      'Each of these checked in anyway, flagged, and the visit is on the review queue. Correcting the pin closes the report; saving without moving it records that you looked and the pin stands.';

  @override
  String get outletDetailFormHeading => 'This store';

  @override
  String get outletFieldName => 'Store name';

  @override
  String get outletFieldCode => 'Store code';

  @override
  String get outletFieldChannel => 'Channel type';

  @override
  String get outletFieldChannelHelp =>
      'For example: supermarket, spaza, forecourt.';

  @override
  String get outletFieldTerritory => 'Territory';

  @override
  String get outletFieldLatitude => 'Latitude';

  @override
  String get outletFieldLongitude => 'Longitude';

  @override
  String get outletFieldLatitudeHelp =>
      'Between -90 and 90. Johannesburg is about -26.2.';

  @override
  String get outletFieldLongitudeHelp =>
      'Between -180 and 180. Johannesburg is about 28.0.';

  @override
  String get outletFieldStatus => 'Status';

  @override
  String get outletStatusActive => 'Active';

  @override
  String get outletStatusClosed => 'Closed';

  @override
  String get outletStatusClosedConsequence =>
      'Kept out of planning. Check-in still works — an agent at the door must be able to work.';

  @override
  String get outletStatusActiveConsequence => 'Planned as usual.';

  @override
  String get outletRequired => 'Required';

  @override
  String get outletCoordinateNotANumber =>
      'Enter a number, for example -26.2041';

  @override
  String get outletLatitudeOutOfRange => 'A latitude is between -90 and 90';

  @override
  String get outletLongitudeOutOfRange => 'A longitude is between -180 and 180';

  @override
  String get outletSave => 'Save';

  @override
  String get outletSaveBlocked =>
      'Fill in the store\'s name and both coordinates first.';

  @override
  String get outletSaved => 'Store updated.';

  @override
  String get outletSaveFailed => 'That store was not saved. It is unchanged.';

  @override
  String get outletUsingAttempt =>
      'Using an agent\'s recorded position. The server reads the coordinates from that check-in itself.';

  @override
  String get outletAttemptsHeading => 'Rejected check-ins';

  @override
  String get outletAttemptsNote =>
      'Where agents actually were when this store turned them away.';

  @override
  String get outletAttemptsEmptyHeadline => 'No rejected check-ins.';

  @override
  String get outletAttemptsEmptyBody =>
      'Nobody has been turned away by this pin.';

  @override
  String outletAttemptSubtitle(String distance, String agent) {
    return '$distance away · $agent';
  }

  @override
  String get outletUseThisPosition => 'Use this position';

  @override
  String get outletUseTheirPosition => 'Use their position';

  @override
  String get outletFixMocked =>
      'The device reported this position as a mock location. It cannot become this store\'s pin.';

  @override
  String get outletFixUnknown =>
      'The device did not report how accurate this position was.';

  @override
  String outletFixCoarse(String metres) {
    return 'Accurate to about $metres m — too coarse to set a pin with.';
  }

  @override
  String outletFixGood(String metres) {
    return 'Accurate to about $metres m.';
  }

  @override
  String get outletDisputesHeading => 'Pin reports';

  @override
  String outletDisputeStood(String position, String distance, String pin) {
    return 'Stood at $position — $distance from the pin, which then read $pin.';
  }

  @override
  String get outletDisputeSoleVisitor =>
      'No other agent has ever visited this store, so nobody else\'s check-ins can disagree with a pin moved here.';

  @override
  String get outletDisputeOpen => 'Open';

  @override
  String get outletDisputeAnswering => 'Answering this report on save.';

  @override
  String get outletDisputeAnswer => 'Answer this report';

  @override
  String outletDisputeApplied(String who) {
    return 'Applied by $who';
  }

  @override
  String outletDisputeRejected(String who) {
    return 'Rejected by $who';
  }

  @override
  String get outletDisputeResolvedByManager => 'a manager';

  @override
  String get outletPhotoCamera => 'Taken with the camera';

  @override
  String get outletPhotoGallery => 'Chosen from the gallery';

  @override
  String get outletPhotoUnknownSource => 'Source not recorded';

  @override
  String outletPhotoPhoneSaid(String when) {
    return 'Phone said $when';
  }

  @override
  String outletPhotoReceived(String when) {
    return 'Received $when';
  }

  @override
  String get outletPhotoAlt => 'Storefront photograph from this pin report';

  @override
  String get outletPhotoMissing => 'That photograph did not load.';

  @override
  String get outletChangesHeading => 'Change history';

  @override
  String outletChangePinMoved(String before, String after) {
    return 'Pin moved from $before to $after';
  }

  @override
  String get outletChangePinFromAgent => 'from an agent\'s recorded position';

  @override
  String outletChangeRenamed(String before, String after) {
    return 'Renamed from \"$before\" to \"$after\"';
  }

  @override
  String outletChangeStatus(String before, String after) {
    return 'Status $before to $after';
  }

  @override
  String get outletChangeOther => 'Changed';

  @override
  String get outletChangeUnknownCoordinate => 'not recorded';

  @override
  String get createOutletTitle => 'Add a store';

  @override
  String get createOutletBack => 'Back to stores';

  @override
  String get createOutletSubmit => 'Add the store';

  @override
  String get createOutletBlocked =>
      'Fill in the name, code, channel, territory and both coordinates first.';

  @override
  String get createOutletFailed =>
      'That store was not created. Nothing was saved.';

  @override
  String get createOutletLocationHeading => 'Where this store is';

  @override
  String get createOutletLocating => 'Finding where this phone is…';

  @override
  String get createOutletLocationDenied =>
      'This phone will not say where it is. Type the store\'s coordinates instead.';

  @override
  String get createOutletLocationFailed =>
      'This phone could not find where it is. Type the store\'s coordinates instead.';

  @override
  String get createOutletLocationFound =>
      'Seeded from this phone. Type over it if you are not standing in the store.';

  @override
  String get createOutletUseThisPhone => 'Use this phone\'s position';

  @override
  String get createOutletTerritoriesLoading => 'Loading territories…';

  @override
  String get createOutletTerritoriesFailed =>
      'The territory list did not load.';

  @override
  String get createOutletTerritoriesRetry => 'Try again';

  @override
  String get createOutletNoTerritories =>
      'No territories yet — create one under Territories first.';

  @override
  String get createOutletTerritoryNotChosen => 'Choose a territory';

  @override
  String get ordersTitle => 'Orders';

  @override
  String get ordersSubtitle =>
      'Captured in the field. A submitted order is waiting on a decision.';

  @override
  String get ordersRefresh => 'Reload the order list';

  @override
  String get ordersSectionHeading => 'Orders';

  @override
  String get ordersNewOrder => 'New order';

  @override
  String get ordersAwaitingEyebrow => 'Awaiting a decision';

  @override
  String ordersAwaitingSubordinates(String confirmed, String cancelled) {
    return '$confirmed confirmed · $cancelled cancelled';
  }

  @override
  String get ordersValueEyebrow => 'Value of these orders';

  @override
  String ordersValuePartial(String shown) {
    return 'Summed over the $shown orders loaded, not the whole history.';
  }

  @override
  String ordersCountPartial(String shown) {
    return 'At least this many: counted over the $shown orders loaded.';
  }

  @override
  String get ordersStatusSubmitted => 'Submitted';

  @override
  String get ordersStatusConfirmed => 'Confirmed';

  @override
  String get ordersStatusCancelled => 'Cancelled';

  @override
  String ordersStatusOther(String status) {
    return 'Status $status';
  }

  @override
  String ordersLineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines',
      one: '1 line',
    );
    return '$_temp0';
  }

  @override
  String ordersRowSubtitle(String status, String lines) {
    return '$status · $lines';
  }

  @override
  String get ordersUnknownStore => 'Store not on this list';

  @override
  String get ordersEmptyHeadline => 'No orders yet.';

  @override
  String get ordersEmptyBody =>
      'Orders appear here as agents capture them on a visit.';

  @override
  String get ordersLoadErrorHeadline => 'The order list did not load.';

  @override
  String get ordersRetry => 'Try again';

  @override
  String ordersFooterMore(String shown) {
    return 'Showing the first $shown. There are more.';
  }

  @override
  String ordersFooterOf(String shown, String total) {
    return 'Showing the $shown newest of $total orders.';
  }

  @override
  String ordersFooterScope(String shown) {
    return 'The figures above are of these $shown.';
  }

  @override
  String get orderFormTitle => 'New order';

  @override
  String get orderFormBack => 'Back to orders';

  @override
  String get orderFormStoreHeading => 'Which store';

  @override
  String get orderFormStore => 'Store';

  @override
  String get orderFormStoreNotChosen =>
      'Not chosen yet. A store decides what can be ordered.';

  @override
  String get orderFormStoresFailed => 'The store list did not load.';

  @override
  String get orderFormLinesHeading => 'Line items';

  @override
  String get orderFormPickStoreFirst => 'Choose a store to see what it stocks.';

  @override
  String get orderFormSkusFailed => 'That store\'s products did not load.';

  @override
  String get orderFormNoSkusHeadline => 'Nothing is stocked here.';

  @override
  String get orderFormNoSkusBody =>
      'This store has no products on its list, so there is nothing to order.';

  @override
  String get orderFormTotal => 'Order total';

  @override
  String get orderFormSubmit => 'Create the order';

  @override
  String get orderFormBlocked =>
      'Choose a store and set a quantity on at least one line first.';

  @override
  String get orderFormFailed => 'That order was not created. Nothing was sent.';

  @override
  String get orderFormQuantity => 'Quantity';

  @override
  String get orderFormOneFewer => 'One fewer';

  @override
  String get orderFormOneMore => 'One more';

  @override
  String get orderFormTypeQuantity => 'Type a quantity';

  @override
  String get orderFormTypeQuantityFirst => 'Type a quantity first.';

  @override
  String get orderFormNotOrdered => 'Not on this order';

  @override
  String get orderFormNoneOrdered => 'None of this one';

  @override
  String get orderFormNoneOrderedLine => 'A line at nought is not sent.';

  @override
  String get orderFormCancel => 'Cancel';

  @override
  String get orderFormSet => 'Set';

  @override
  String get beatPlansTitle => 'Beat plans';

  @override
  String get beatPlansSubtitle =>
      'A plan is a day of store stops, in visit order.';

  @override
  String get beatPlansRefresh => 'Reload the beat plans';

  @override
  String get beatPlansSectionHeading => 'Plans';

  @override
  String get beatPlansNewPlan => 'New plan';

  @override
  String get beatPlansEmptyHeadline => 'No beat plans.';

  @override
  String get beatPlansEmptyBody =>
      'A plan is a day of store stops in visit order. Build one to give an agent a route.';

  @override
  String get beatPlansLoadErrorHeadline => 'The beat plans did not load.';

  @override
  String get beatPlansRetry => 'Try again';

  @override
  String beatPlansFooterMore(String shown) {
    return 'Showing the first $shown. There are more.';
  }

  @override
  String beatPlansFooterOf(String shown, String total) {
    return 'Showing $shown of $total plans.';
  }

  @override
  String get beatPlanStatusScheduled => 'Scheduled';

  @override
  String get beatPlanStatusInProgress => 'In progress';

  @override
  String get beatPlanStatusCompleted => 'Completed';

  @override
  String get beatPlanStatusMissed => 'Missed';

  @override
  String get beatPlanStatusCancelled => 'Cancelled';

  @override
  String beatPlanStatusOther(String status) {
    return 'Status $status';
  }

  @override
  String get beatPlanDetailTitle => 'Beat plan';

  @override
  String get beatPlanDetailBack => 'Back to beat plans';

  @override
  String get beatPlanDetailLoadErrorHeadline => 'This beat plan did not load.';

  @override
  String get beatPlanAdherenceEyebrow => 'Stops worked';

  @override
  String beatPlanAdherenceOf(String visited, String total) {
    return '$visited of $total stops';
  }

  @override
  String get beatPlanAdherenceNoStops =>
      'This plan has no stops, so there is nothing to work.';

  @override
  String get beatPlanStopsHeading => 'Stops';

  @override
  String get beatPlanStopsEmptyHeadline => 'No stops on this plan.';

  @override
  String get beatPlanStopsEmptyBody =>
      'Add stores to the plan to give the agent a route.';

  @override
  String beatPlanStopLabel(String sequence) {
    return 'Stop $sequence';
  }

  @override
  String get beatPlanStopVisited => 'Worked';

  @override
  String get beatPlanStopNotVisited => 'Not yet';

  @override
  String beatPlanStopToggle(String stop) {
    return 'Mark $stop as worked';
  }

  @override
  String get beatPlanStopFailed =>
      'That stop was not changed. It is as it was.';

  @override
  String get beatPlanFormTitle => 'New beat plan';

  @override
  String get beatPlanFormBack => 'Back to beat plans';

  @override
  String get beatPlanFormPlanHeading => 'The day';

  @override
  String get beatPlanFormName => 'Plan name';

  @override
  String get beatPlanFormNameHelp =>
      'What the agent will see at the top of their day.';

  @override
  String get beatPlanFormDate => 'Scheduled date';

  @override
  String get beatPlanFormDateNotChosen => 'Not chosen yet.';

  @override
  String get beatPlanFormPickDate => 'Pick a date';

  @override
  String get beatPlanFormChangeDate => 'Change the date';

  @override
  String get beatPlanFormAgent => 'Field agent';

  @override
  String get beatPlanFormAgentNotChosen =>
      'Not chosen yet. A plan belongs to one agent.';

  @override
  String get beatPlanFormAgentsFailed => 'The agent list did not load.';

  @override
  String get beatPlanFormNoAgents => 'No field agents on this account yet.';

  @override
  String get beatPlanFormTerritory => 'Territory';

  @override
  String get beatPlanFormTerritoryOptional =>
      'Optional. It narrows reporting, not the stops.';

  @override
  String get beatPlanFormTerritoryNone => 'No territory';

  @override
  String get beatPlanFormStopsHeading => 'Stops, in order';

  @override
  String get beatPlanFormStopsEmpty =>
      'No stops yet. Add stores from the list below.';

  @override
  String get beatPlanFormAvailableHeading => 'Stores to add';

  @override
  String get beatPlanFormAvailableEmpty =>
      'Every store is already on this plan.';

  @override
  String get beatPlanFormStoresFailed => 'The store list did not load.';

  @override
  String beatPlanFormAddStop(String store) {
    return 'Add $store to the plan';
  }

  @override
  String beatPlanFormRemoveStop(String store) {
    return 'Take $store off the plan';
  }

  @override
  String beatPlanFormMoveUp(String store) {
    return 'Move $store earlier';
  }

  @override
  String beatPlanFormMoveDown(String store) {
    return 'Move $store later';
  }

  @override
  String beatPlanFormStopCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stops',
      one: '1 stop',
      zero: 'No stops',
    );
    return '$_temp0';
  }

  @override
  String get beatPlanFormSubmit => 'Create the plan';

  @override
  String get beatPlanFormBlocked =>
      'Name the plan, pick a date and an agent, and add at least one stop first.';

  @override
  String get beatPlanFormFailed =>
      'That plan was not created. Nothing was saved.';

  @override
  String get salesTargetsTitle => 'Sales targets';

  @override
  String get salesTargetsSubtitle =>
      'Units ordered through TradeIQ, not what shoppers bought.';

  @override
  String get salesSellIn => 'Sell-in (orders)';

  @override
  String get salesTargetsHelp =>
      'Set one target per SKU for the whole account, a territory, or a single store.';

  @override
  String get salesTargetsUpload => 'Upload a CSV of targets';

  @override
  String salesMonthPrevious(String month) {
    return 'The month before $month';
  }

  @override
  String salesMonthNext(String month) {
    return 'The month after $month';
  }

  @override
  String salesTimeZone(String zone) {
    return 'Local days in $zone';
  }

  @override
  String get salesLevelsHeading => 'Against target';

  @override
  String get salesLevelAccount => 'Account-wide';

  @override
  String get salesLevelTerritories => 'Territories';

  @override
  String get salesLevelOutlets => 'Stores';

  @override
  String get salesLevelNoTargets =>
      'No target is set at this level, so there is nothing to attain.';

  @override
  String salesLevelSubordinates(String actual, String target, int targets) {
    String _temp0 = intl.Intl.pluralLogic(
      targets,
      locale: localeName,
      other: '$targets targets',
      one: '1 target',
    );
    return '$actual of $target units · $_temp0';
  }

  @override
  String get salesBandOnTarget => 'On target';

  @override
  String get salesBandClose => 'Close';

  @override
  String get salesBandBehind => 'Behind';

  @override
  String get salesNoTarget => 'No target';

  @override
  String salesNoTargetsHeadline(String month) {
    return 'No targets for $month.';
  }

  @override
  String get salesNoTargetsBody =>
      'Set a target on a SKU below, or upload a CSV of targets.';

  @override
  String get salesSkusHeading => 'SKUs';

  @override
  String salesSkusTruncated(String shown) {
    return 'Showing the first $shown.';
  }

  @override
  String get salesSkusEmptyHeadline => 'No SKUs on this account.';

  @override
  String get salesSkusEmptyBody =>
      'Targets are set per SKU, so there is nothing to set one on yet.';

  @override
  String salesRowFigures(String metric, String actual, String target) {
    return '$metric $actual · target $target units';
  }

  @override
  String salesRowNoTargetFigures(String metric, String actual) {
    return '$metric $actual · no target set';
  }

  @override
  String get salesScopeTerritory => 'Territory';

  @override
  String get salesScopeOutlet => 'Store';

  @override
  String get salesScopeAccount => 'Whole account';

  @override
  String get salesScopeUnknown => 'Scope not on this list';

  @override
  String salesScopedRowTitle(String sku, String scope) {
    return '$sku · $scope';
  }

  @override
  String get salesSetTarget => 'Set a target';

  @override
  String get salesEditTarget => 'Edit the target';

  @override
  String get salesRemoveTarget => 'Remove the target';

  @override
  String get salesRemoveFailed =>
      'That target was not removed. It is still set.';

  @override
  String get salesTargetSheetSet => 'Set a sales target';

  @override
  String get salesTargetSheetEdit => 'Edit a sales target';

  @override
  String salesTargetSheetSubtitle(String metric, String month) {
    return 'Units of $metric for $month.';
  }

  @override
  String get salesTargetSku => 'SKU';

  @override
  String get salesTargetSkuNotChosen =>
      'Not chosen yet. A target belongs to one SKU.';

  @override
  String get salesTargetSkuLocked =>
      'A target is identified by its SKU, so an edit cannot move it.';

  @override
  String get salesTargetScope => 'Applies to';

  @override
  String get salesTargetScopeLocked =>
      'A target is identified by its scope, so an edit cannot move it.';

  @override
  String get salesTargetScopeAccountConsequence =>
      'Every store on the account counts towards it.';

  @override
  String get salesTargetScopeTerritoryConsequence =>
      'Only stores in the chosen territory count.';

  @override
  String get salesTargetScopeOutletConsequence =>
      'Only the chosen store counts.';

  @override
  String get salesTargetTerritoryNotChosen =>
      'Not chosen yet. A territory target needs one.';

  @override
  String get salesTargetOutletNotChosen =>
      'Not chosen yet. A store target needs one.';

  @override
  String get salesTargetUnits => 'Target units';

  @override
  String get salesTargetUnitsHelp => 'A whole number of units, for the month.';

  @override
  String get salesTargetUnitsMissing => 'Enter a whole number of units.';

  @override
  String get salesTargetSave => 'Save the target';

  @override
  String get salesTargetBlocked =>
      'Choose a SKU and a scope, and enter a whole number of units.';

  @override
  String get salesTargetCancel => 'Cancel';

  @override
  String get salesTargetsLoadErrorHeadline => 'The targets did not load.';

  @override
  String get salesTargetsRetry => 'Try again';

  @override
  String get salesImportTitle => 'Upload sales targets';

  @override
  String get salesImportSubtitle =>
      'Preview what a file would do, then apply the rows that are good.';

  @override
  String get salesImportFormat =>
      'It needs a header row: month (YYYY-MM), sku (id or name), targetUnits, and optionally territory or outlet (id or code). Existing targets for the same SKU, month and scope are replaced.';

  @override
  String get salesImportChooseFile => 'Choose a CSV file';

  @override
  String get salesImportChooseAnother => 'Choose another file';

  @override
  String get salesImportRemoveFile => 'Remove the file';

  @override
  String get salesImportPasteLabel => 'Or paste a CSV';

  @override
  String get salesImportPasteHint => 'month,sku,targetUnits,territory,outlet';

  @override
  String get salesImportFileHeld =>
      'Preview to see what this file would do. Remove it to paste a CSV instead.';

  @override
  String get salesImportFileUnreadable => 'That file could not be read.';

  @override
  String get salesImportPreview => 'Preview';

  @override
  String get salesImportApply => 'Apply';

  @override
  String salesImportApplyRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Apply $count rows',
      one: 'Apply 1 row',
    );
    return '$_temp0';
  }

  @override
  String get salesImportBlockedPreview =>
      'Preview the file first. What gets written is always what was shown.';

  @override
  String get salesImportBlockedNoRows => 'No row in this file can be written.';

  @override
  String get salesImportReadyEyebrow => 'Rows ready to write';

  @override
  String get salesImportErrorsEyebrow => 'Rows with errors';

  @override
  String salesImportWouldDo(String created, String updated) {
    return 'Would create $created and update $updated.';
  }

  @override
  String get salesImportErrorsHeading => 'What is wrong';

  @override
  String salesImportRowError(String row, String message) {
    return 'Row $row: $message';
  }

  @override
  String salesImportRowErrorColumn(String row, String column, String message) {
    return 'Row $row · $column: $message';
  }

  @override
  String salesImportMoreErrors(String count) {
    return '…and $count more.';
  }

  @override
  String get salesImportNothingWrong =>
      'Every row in this file can be written.';

  @override
  String salesImportApplied(String created, String updated) {
    return '$created created, $updated updated.';
  }

  @override
  String salesImportAppliedSkipped(
    String created,
    String updated,
    String skipped,
  ) {
    return '$created created, $updated updated, $skipped rows skipped.';
  }

  @override
  String get salesPanelTitle => 'Sell-in vs target';

  @override
  String salesPanelSubtitle(String metric, String month) {
    return '$metric · $month — not consumer sales';
  }

  @override
  String get salesPanelThisMonth => 'this month';

  @override
  String get salesPanelLink => 'Targets';

  @override
  String get salesPanelEmptyBody =>
      'Set monthly SKU targets under Sales targets to track sell-in against them.';

  @override
  String get templatesTitle => 'Audit templates';

  @override
  String get templatesFact =>
      'A template is the form an agent fills in on a visit.';

  @override
  String get templatesRefresh => 'Refresh the templates';

  @override
  String get templatesSkeleton => 'templates';

  @override
  String get templatesSection => 'Templates';

  @override
  String get templatesEmptyHeadline => 'No templates yet.';

  @override
  String get templatesEmptyBody =>
      'Templates published to this client appear here.';

  @override
  String get templatesInAuditsSection => 'Used in field audits';

  @override
  String get templatesInAuditsChecking => 'Checking which template is in use…';

  @override
  String get templatesInAuditsFailed =>
      'Could not load the template used in audits.';

  @override
  String get templatesInAuditsNone => 'No template is used in audits.';

  @override
  String templatesInAuditsNamed(String name, int version) {
    return '“$name” (v$version)';
  }

  @override
  String get templatesInAuditsSubtitle =>
      'Client questions, after the standard audit sections';

  @override
  String get templatesInAuditsMeta =>
      'Agents answer its questions on every visit, as an extra section after the standard audit. Required questions must be answered before a visit can be submitted. It does not change the perfect store score.';

  @override
  String get templatesStopUsing => 'Stop using';

  @override
  String get templatesStopping => 'Stopping…';

  @override
  String templatesInAuditsSemantics(String headline) {
    return 'Used in field audits. $headline';
  }

  @override
  String get templatesCleared => 'No template is used in audits now.';

  @override
  String templatesNowInAudits(String name) {
    return '“$name” is now used in audits.';
  }

  @override
  String templatesChangeFailed(String reason) {
    return 'The audit template was not changed. $reason';
  }

  @override
  String get templateWordInAudits => 'In audits';

  @override
  String get templateWordActive => 'Active';

  @override
  String get templateWordPaused => 'Paused';

  @override
  String templateVersionShort(int version) {
    return 'v$version';
  }

  @override
  String templateVersionAndIndustry(int version, String industry) {
    return 'v$version · $industry';
  }

  @override
  String templateVersionSpoken(int version) {
    return 'version $version';
  }

  @override
  String get templateUseInAudits => 'Use in audits';

  @override
  String get templateSwitching => 'Switching…';

  @override
  String get templateOpensPreview => 'Opens a preview of its form';

  @override
  String get templatePreviewTitle => 'Template preview';

  @override
  String get templatePreviewBack => 'Back to Audit templates';

  @override
  String get templatePreviewSkeleton => 'the template';

  @override
  String get templatePreviewFact => 'Preview — nothing is saved';

  @override
  String templatePreviewSection(int index, int count) {
    return 'Section $index of $count';
  }

  @override
  String get templatePreviewNext => 'Next section';

  @override
  String get templatePreviewFinish => 'Finish preview';

  @override
  String get templatePreviewBackSection => 'Back a section';

  @override
  String templatePreviewBlockedOne(String label) {
    return '“$label” still needs an answer.';
  }

  @override
  String templatePreviewBlockedMany(int count) {
    return '$count required questions in this section still need answers.';
  }

  @override
  String get templatePreviewDoneTitle => 'Preview complete';

  @override
  String templatePreviewDoneBody(int answered, int total) {
    return 'You answered $answered of $total visible questions. Nothing was saved — a preview writes no answers, and saving them against a visit arrives with the audit-flow integration.';
  }

  @override
  String get templateFormNoSectionsHeadline =>
      'This template has no form sections yet.';

  @override
  String get templateFormNoSectionsBody =>
      'Publish a section to it and the preview will walk through it.';

  @override
  String get templateFormSectionEmpty =>
      'Nothing to answer in this section yet.';

  @override
  String get templateFormScoreEyebrow => 'Score preview';

  @override
  String templateFormScoreOutOf(String maximum) {
    return 'Out of $maximum for the whole template.';
  }

  @override
  String get templateFieldRequired =>
      'Required before a visit can be submitted.';

  @override
  String get templateFieldNotAnsweredLine => 'Not answered yet.';

  @override
  String get templateFieldNotAnswered => 'Not answered yet';

  @override
  String get templateFieldYes => 'Yes';

  @override
  String get templateFieldNo => 'No';

  @override
  String get templateFieldClear => 'Clear this answer';

  @override
  String templateFieldChoiceSemantics(String label, String answer) {
    return '$label. $answer. Opens the list of answers.';
  }

  @override
  String get templateFieldPhotoSubtitle => 'Cannot be answered yet';

  @override
  String get templateFieldPhotoMeta =>
      'Photo capture arrives with the audit-flow integration. This question does not block a submit.';

  @override
  String templateFieldPhotoSemantics(String label) {
    return '$label. Cannot be answered yet. Photo capture arrives with the audit-flow integration.';
  }

  @override
  String get reportsTitle => 'Reports';

  @override
  String get reportsFact => 'Definitions run on demand against live data.';

  @override
  String get reportsRefresh => 'Refresh the saved reports';

  @override
  String get reportsSkeleton => 'reports';

  @override
  String get reportsSection => 'Reports';

  @override
  String get reportsSchedules => 'Schedules';

  @override
  String get reportsEmptyHeadline => 'No saved reports.';

  @override
  String get reportsEmptyBody =>
      'Build one, then run it to see how many rows it returns.';

  @override
  String get reportsNew => 'New report';

  @override
  String reportsFooterMore(String shown) {
    return 'Showing the first $shown. There are more.';
  }

  @override
  String reportsFooterOf(String shown, String total) {
    return 'Showing the first $shown of $total.';
  }

  @override
  String get reportRun => 'Run';

  @override
  String get reportRunning => 'Running…';

  @override
  String get reportDelete => 'Delete';

  @override
  String get reportWordRunning => 'Running';

  @override
  String get reportWordReady => 'Ready';

  @override
  String get reportWordFailed => 'Could not run';

  @override
  String get reportWordZeroRows => '0 rows — the query matched nothing';

  @override
  String get reportWordGenerated => 'Generated';

  @override
  String reportRowsAndFile(String rows, String filename) {
    return '$rows rows · $filename';
  }

  @override
  String reportRowsSpoken(String rows) {
    return '$rows rows';
  }

  @override
  String reportDownloaded(String filename) {
    return 'Downloaded $filename.';
  }

  @override
  String reportSavedTo(String filename, String location) {
    return 'Saved $filename to $location.';
  }

  @override
  String reportDeleteAction(String name) {
    return 'Delete $name?';
  }

  @override
  String get reportDeleteConsequenceEveryone =>
      'The definition is removed for everyone on this client.';

  @override
  String get reportDeleteConsequenceSchedules =>
      'Any schedule that runs it stops running.';

  @override
  String get reportDeleteConsequenceFiles =>
      'Files already downloaded are not affected.';

  @override
  String get reportDeleteCommit => 'Delete this report';

  @override
  String get reportDeleteCancel => 'Keep it';

  @override
  String reportDeleteFailed(String reason) {
    return 'That report was not deleted. $reason';
  }

  @override
  String get reportTypeVisits => 'Visits';

  @override
  String get reportTypeScorecards => 'Scorecards';

  @override
  String get reportTypeTasks => 'Tasks';

  @override
  String get reportTypeOrders => 'Orders';

  @override
  String get reportTypeVisitsConsequence => 'One row per submitted visit.';

  @override
  String get reportTypeScorecardsConsequence => 'One row per scored visit.';

  @override
  String get reportTypeTasksConsequence => 'One row per task raised.';

  @override
  String get reportTypeOrdersConsequence =>
      'One row per order captured in store.';

  @override
  String get reportTypeOtherConsequence => 'One row per record.';

  @override
  String get reportFilterDateFormat =>
      'Use the form 2026-09-20, or leave it blank for any date.';

  @override
  String get reportFormTitle => 'New report';

  @override
  String get reportFormFact => 'It runs on demand against live data.';

  @override
  String get reportFormBack => 'Back to Reports';

  @override
  String get reportFormCommit => 'Create this report';

  @override
  String get reportFormSaving => 'Saving…';

  @override
  String get reportFormBlockedName => 'Give the report a name first.';

  @override
  String get reportFormBlockedFrom =>
      'The From date is not a date. Use the form 2026-09-20.';

  @override
  String get reportFormBlockedTo =>
      'The To date is not a date. Use the form 2026-09-20.';

  @override
  String get reportFormBlockedOrder => 'The To date is before the From date.';

  @override
  String get reportFormSectionReport => 'Report';

  @override
  String get reportFormSectionNarrowed => 'Narrowed to';

  @override
  String get reportFormName => 'Name';

  @override
  String get reportFormNameHint => 'Outlet coverage, September';

  @override
  String get reportFormNameHelp => 'What a manager will look for in the list.';

  @override
  String get reportFormType => 'What it queries';

  @override
  String get reportFormTypeNotAnswered => 'Pick what the report is about.';

  @override
  String get reportFormFrom => 'From';

  @override
  String get reportFormTo => 'To';

  @override
  String get reportFormDateHelp => 'Leave blank for any date.';

  @override
  String get reportFormOutlet => 'Outlet';

  @override
  String get reportFormAllOutlets => 'All outlets';

  @override
  String reportFormOutletSemantics(String outlet) {
    return 'Outlet. $outlet. Choose an outlet.';
  }

  @override
  String get reportFormFailed => 'The report was not created.';

  @override
  String get reportOutletSheetSubtitle =>
      'The report is narrowed to the one you pick.';

  @override
  String get reportOutletSheetSkeleton => 'outlets';

  @override
  String get reportOutletSheetEmptyHeadline => 'No outlets on this client yet.';

  @override
  String get reportOutletSheetEmptyBody =>
      'The report will cover every outlet added later.';

  @override
  String get cadenceDaily => 'Daily';

  @override
  String get cadenceWeekly => 'Weekly';

  @override
  String get schedulesTitle => 'Report schedules';

  @override
  String get schedulesFact =>
      'A schedule runs its report server-side and delivers the result.';

  @override
  String get schedulesRefresh => 'Refresh the schedules';

  @override
  String get schedulesSkeleton => 'report schedules';

  @override
  String get schedulesDeliveryNote =>
      'Active schedules run automatically on their cadence and are sent to your webhooks subscribed to report.generated. Recipients are emailed when email is set up on the server.';

  @override
  String get schedulesBackToReports => 'Back to reports';

  @override
  String get schedulesEmptyHeadline => 'No schedules.';

  @override
  String get schedulesEmptyBody =>
      'A report runs on demand until you schedule it.';

  @override
  String get schedulesNew => 'New schedule';

  @override
  String get schedulesGroupActive => 'Active';

  @override
  String get schedulesGroupOff => 'Off';

  @override
  String get schedulesGroupActiveEmpty => 'Nothing is running on its own.';

  @override
  String get schedulesGroupOffEmpty => 'Nothing is paused.';

  @override
  String get scheduleUntitledReport => 'Untitled report';

  @override
  String get scheduleNeverRun => 'Never run';

  @override
  String scheduleLastRun(String stamp) {
    return 'Last run $stamp';
  }

  @override
  String scheduleNextRun(String stamp) {
    return 'Next run $stamp';
  }

  @override
  String get scheduleNextRunNone => 'Next run not scheduled';

  @override
  String get schedulePausedNoNextRun => 'Paused, no next run';

  @override
  String get scheduleNoRecipients => 'No recipients';

  @override
  String get scheduleNoRecipientsLine =>
      'No recipients — this schedule delivers to nobody by email.';

  @override
  String scheduleRecipientCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipients',
      one: '1 recipient',
    );
    return '$_temp0';
  }

  @override
  String get scheduleRunsOnItsOwn => 'Runs on its own';

  @override
  String get scheduleOn => 'On';

  @override
  String get scheduleOff => 'Off';

  @override
  String get scheduleWaitingForServer => 'Waiting for the server.';

  @override
  String get scheduleRunningOnItsOwn => 'Running on its own';

  @override
  String get scheduleShowRecipients => 'Show recipients';

  @override
  String get scheduleHideRecipients => 'Hide recipients';

  @override
  String get scheduleRunNow => 'Run now';

  @override
  String get scheduleHistory => 'History';

  @override
  String get scheduleEdit => 'Edit';

  @override
  String get scheduleDelete => 'Delete';

  @override
  String get scheduleDeleteAction => 'Delete this schedule?';

  @override
  String scheduleDeleteConsequenceStops(String name) {
    return '$name stops running on its own.';
  }

  @override
  String get scheduleDeleteConsequenceReportKept =>
      'The saved report itself is kept.';

  @override
  String get scheduleDeleteConsequenceRuns =>
      'Runs already delivered are not withdrawn.';

  @override
  String get scheduleDeleteCommit => 'Delete this schedule';

  @override
  String get scheduleDeleteCancel => 'Keep it';

  @override
  String get scheduleDeleteFailed => 'Could not delete the schedule.';

  @override
  String get scheduleResumeFailed => 'Could not resume the schedule.';

  @override
  String get schedulePauseFailed => 'Could not pause the schedule.';

  @override
  String get scheduleRunFailed => 'Run failed.';

  @override
  String scheduleFailureToast(String lead, String reason) {
    return '$lead $reason';
  }

  @override
  String runNowGeneratedRows(String rowsText, int rows) {
    String _temp0 = intl.Intl.pluralLogic(
      rows,
      locale: localeName,
      other: 'rows',
      one: 'row',
    );
    return 'Generated $rowsText $_temp0.';
  }

  @override
  String runNowQueuedWebhooks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count webhooks',
      one: '1 webhook',
    );
    return 'Queued for $_temp0.';
  }

  @override
  String get runNowWebhookFailed => 'Webhook delivery failed.';

  @override
  String get runNowNoSubscriber =>
      'Not sent: no webhook is subscribed to report.generated.';

  @override
  String runNowEmailing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipients',
      one: '1 recipient',
    );
    return 'Emailing $_temp0.';
  }

  @override
  String get runNowEmailNotConfigured => 'Email is not set up on the server.';

  @override
  String get runNowEmailNoSubscribers =>
      'Not emailed: no valid email recipients.';

  @override
  String get runNowEmailFailed => 'Email delivery failed.';

  @override
  String get runStatusDelivering => 'Delivering';

  @override
  String get runStatusDelivered => 'Delivered';

  @override
  String get runStatusPartial => 'Partly delivered';

  @override
  String get runStatusFailed => 'Failed';

  @override
  String get runStatusNotSent => 'Not sent';

  @override
  String get runStatusUnknown => 'Unknown';

  @override
  String get runTitleScheduled => 'Scheduled run';

  @override
  String get runTitleManual => 'Run now';

  @override
  String runGeneratedAt(String stamp) {
    return 'Generated $stamp';
  }

  @override
  String runDueAndGenerated(String due, String generated) {
    return 'Due $due · $generated';
  }

  @override
  String runRowCount(String rowsText, int rows) {
    String _temp0 = intl.Intl.pluralLogic(
      rows,
      locale: localeName,
      other: 'rows',
      one: 'row',
    );
    return '$rowsText $_temp0';
  }

  @override
  String runHistoryFooterMore(String shown) {
    return 'Showing the $shown most recent. There are more.';
  }

  @override
  String runHistoryFooterOf(String shown, String total) {
    return 'Showing the $shown most recent of $total.';
  }

  @override
  String runCountDelivered(int count) {
    return '$count delivered';
  }

  @override
  String runCountPending(int count) {
    return '$count pending';
  }

  @override
  String runCountFailed(int count) {
    return '$count failed';
  }

  @override
  String runCountSent(int count) {
    return '$count sent';
  }

  @override
  String get runCountsQueued => 'queued';

  @override
  String runWebhooksLine(String counts) {
    return 'Webhooks: $counts';
  }

  @override
  String get runWebhooksNoneSubscribed => 'Webhooks: none subscribed';

  @override
  String get runWebhooksFailedLine => 'Webhooks: failed';

  @override
  String runEmailLine(String counts) {
    return 'Email: $counts';
  }

  @override
  String runEmailNotSetUpLine(int count) {
    return 'Email: not set up ($count not emailed)';
  }

  @override
  String get runEmailNoRecipientsLine => 'Email: no valid recipients';

  @override
  String get runEmailFailedLine => 'Email: failed';

  @override
  String get runNoDeliveryRecorded => 'No delivery recorded';

  @override
  String get deliveryWordQueued => 'Queued';

  @override
  String get deliveryWordDelivered => 'Delivered';

  @override
  String get deliveryWordSent => 'Sent';

  @override
  String get deliveryWordRetrying => 'Retrying';

  @override
  String get deliveryWordGaveUp => 'Gave up';

  @override
  String get deliveryWordEmailFailed => 'Failed';

  @override
  String deliveryAttempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attempts',
      one: '1 attempt',
    );
    return '$_temp0';
  }

  @override
  String deliveryHttpStatus(int code) {
    return 'HTTP $code';
  }

  @override
  String get deliveryNotSentYet => 'Not sent yet';

  @override
  String get deliveryNoResponse => 'No response';

  @override
  String get runNoCsvLinkNote =>
      'No download link. Links need signed links set up on the server, and stop working 7 days after the run.';

  @override
  String get runHistoryTitle => 'Run history';

  @override
  String get runHistoryBack => 'Back to Report schedules';

  @override
  String get runHistorySkeleton => 'report runs';

  @override
  String get runHistoryRefresh => 'Refresh';

  @override
  String get runHistorySection => 'Runs';

  @override
  String get runHistoryEmptyHeadline => 'No runs yet.';

  @override
  String get runHistoryEmptyBody =>
      'A run appears each time the schedule fires or you use Run now.';

  @override
  String get runHistoryLoadMore => 'Load more';

  @override
  String get runShowDetails => 'Show run details';

  @override
  String get runHideDetails => 'Hide run details';

  @override
  String get runDownloadCsv => 'Download CSV';

  @override
  String runRowSubtitle(String rows, String delivery) {
    return '$rows · $delivery';
  }

  @override
  String get runDetailSectionWebhooks => 'Webhooks';

  @override
  String get runDetailSectionEmail => 'Email';

  @override
  String get runDetailSectionFile => 'The file';

  @override
  String get runSignedLink => 'Signed download link.';

  @override
  String runSignedLinkUntil(String stamp) {
    return 'Signed download link, works until $stamp.';
  }

  @override
  String get runWebhookNoSubscriber =>
      'Not sent: no webhook is subscribed to report.generated.';

  @override
  String get runWebhookDeliveryFailed => 'Webhook delivery failed.';

  @override
  String runWebhookDeliveryFailedWhy(String detail) {
    return 'Webhook delivery failed: $detail';
  }

  @override
  String get runWebhookTargetsDeleted =>
      'The webhooks this run was sent to have since been deleted.';

  @override
  String get runWebhookNoneRecorded => 'No webhook delivery was recorded.';

  @override
  String runEmailNotConfiguredDetail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipients',
      one: '1 recipient',
    );
    return 'Not emailed to $_temp0: email is not set up on the server.';
  }

  @override
  String get runEmailNoRecipientsDetail =>
      'Not emailed: no valid email recipients.';

  @override
  String get runEmailDeliveryFailed => 'Email delivery failed.';

  @override
  String runEmailDeliveryFailedWhy(String detail) {
    return 'Email delivery failed: $detail';
  }

  @override
  String get runEmailNoneRecorded => 'No email delivery was recorded.';

  @override
  String get runEmailSkeleton => 'email deliveries';

  @override
  String get runEmailNoneQueued => 'No emails were queued for this run.';

  @override
  String get csvLinkSheetSubtitle =>
      'Open this link in a browser to download the report. Anyone with the link can download it.';

  @override
  String csvLinkSheetSubtitleUntil(String stamp) {
    return 'Open this link in a browser to download the report. Anyone with the link can download it until $stamp.';
  }

  @override
  String get csvLinkCopy => 'Copy the link';

  @override
  String get scheduleFormTitleNew => 'New schedule';

  @override
  String get scheduleFormTitleEdit => 'Edit schedule';

  @override
  String get scheduleFormFact => 'It runs server-side and delivers the result.';

  @override
  String get scheduleFormBack => 'Back to Report schedules';

  @override
  String get scheduleFormCommitNew => 'Create this schedule';

  @override
  String get scheduleFormCommitEdit => 'Save these changes';

  @override
  String get scheduleFormSaving => 'Saving…';

  @override
  String get scheduleFormBlockedLoading => 'Loading the saved reports.';

  @override
  String get scheduleFormBlockedReportsFailed =>
      'The saved reports could not be loaded, so there is nothing to schedule yet.';

  @override
  String get scheduleFormBlockedNoReports =>
      'There are no saved reports yet. Build one on Reports first.';

  @override
  String get scheduleFormBlockedNoReport =>
      'Pick the report this schedule runs.';

  @override
  String get scheduleFormBlockedNoCadence => 'Pick how often it runs.';

  @override
  String get scheduleFormSectionReport => 'Report';

  @override
  String get scheduleFormSectionSchedule => 'Schedule';

  @override
  String get scheduleFormReportLocked => 'Locked';

  @override
  String get scheduleFormReportLockedNote =>
      'The report on a schedule cannot be changed. To schedule a different report, create a new schedule.';

  @override
  String scheduleFormReportLockedSemantics(String name, String note) {
    return '$name. Locked. $note';
  }

  @override
  String get scheduleFormReportsSkeleton => 'saved reports';

  @override
  String get scheduleFormNoReportsHeadline => 'No saved reports yet.';

  @override
  String get scheduleFormNoReportsBody =>
      'Build one on the Reports screen, then schedule it.';

  @override
  String get scheduleFormReportNotPicked => 'Not picked yet';

  @override
  String scheduleFormReportSemantics(String report) {
    return 'Report. $report. Choose the report this schedule runs.';
  }

  @override
  String get scheduleFormCadence => 'How often';

  @override
  String get scheduleFormCadenceDailyConsequence => 'Every day, 06:00 UTC.';

  @override
  String get scheduleFormCadenceWeeklyConsequence => 'Every Monday, 06:00 UTC.';

  @override
  String get scheduleFormCadenceHelp =>
      'Runs automatically on this cadence (UTC), is sent to webhooks subscribed to report.generated, and is emailed to the recipients when email is set up on the server.';

  @override
  String get scheduleFormRecipients => 'Recipients';

  @override
  String get scheduleFormRecipientsHelp =>
      'Email addresses, one per line or separated by commas.';

  @override
  String get scheduleFormRecipientsEmpty => 'Add at least one recipient';

  @override
  String scheduleFormRecipientsInvalid(String entry) {
    return 'Not an email address: $entry';
  }

  @override
  String scheduleFormRecipientsTooMany(int max) {
    return 'At most $max recipients';
  }

  @override
  String get scheduleFormFailedNew => 'The schedule was not created.';

  @override
  String get scheduleFormFailedEdit => 'The changes were not saved.';

  @override
  String scheduleFormFailedBody(String headline, String reason) {
    return '$headline $reason';
  }

  @override
  String get scheduleReportSheetSubtitle =>
      'The schedule runs this definition on its cadence.';

  @override
  String get relativeJustNow => 'just now';

  @override
  String get relativeUnderAMinute => 'in under a minute';

  @override
  String relativeMinutesAgo(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String relativeHoursAgo(int hours) {
    return '${hours}h ago';
  }

  @override
  String relativeDaysAgo(int days) {
    return '${days}d ago';
  }

  @override
  String relativeInMinutes(int minutes) {
    return 'in ${minutes}m';
  }

  @override
  String relativeInHours(int hours) {
    return 'in ${hours}h';
  }

  @override
  String relativeInDays(int days) {
    return 'in ${days}d';
  }

  @override
  String get webhookEventVisitSubmitted => 'Visit submitted';

  @override
  String get webhookEventAlertRaised => 'Alert raised';

  @override
  String get webhookEventOrderCreated => 'Order created';

  @override
  String get webhookEventReportGenerated => 'Report generated';

  @override
  String get webhookHealthHealthy => 'Healthy';

  @override
  String get webhookHealthFailing => 'Failing';

  @override
  String get webhookHealthUnhealthy => 'Unhealthy';

  @override
  String get webhookDeliveryQueued => 'Queued';

  @override
  String get webhookDeliveryDelivered => 'Delivered';

  @override
  String get webhookDeliveryRetrying => 'Retrying';

  @override
  String get webhookDeliveryGaveUp => 'Gave up';

  @override
  String get webhooksTitle => 'Webhooks';

  @override
  String get webhooksFactPost =>
      'Each endpoint receives a POST when its event fires.';

  @override
  String get webhooksFactRetries =>
      'Failed deliveries retry for about eight hours.';

  @override
  String get webhooksRefresh => 'Refresh the endpoints';

  @override
  String get webhooksSkeleton => 'webhooks';

  @override
  String get webhooksSection => 'Endpoints';

  @override
  String webhooksUnhealthyNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count endpoints are not receiving. A delivery to them has given up after every retry.',
      one:
          '1 endpoint is not receiving. A delivery to it has given up after every retry.',
    );
    return '$_temp0';
  }

  @override
  String get webhooksEmptyHeadline => 'No endpoints registered.';

  @override
  String get webhooksEmptyBody =>
      'Add one to forward events to an external system.';

  @override
  String get webhookAdd => 'Add an endpoint';

  @override
  String get webhookNoDeliveriesYet => 'No deliveries yet';

  @override
  String webhookLastDelivery(String when) {
    return 'Last delivery $when';
  }

  @override
  String get webhookSigned => 'Signed — deliveries carry an HMAC signature.';

  @override
  String get webhookNotSigned => 'Not signed — deliveries carry no signature.';

  @override
  String get webhookSignedShort => 'Signed';

  @override
  String get webhookNotSignedShort => 'Not signed';

  @override
  String get webhookReceivingEvents => 'Receiving events';

  @override
  String get webhookOn => 'On';

  @override
  String get webhookOff => 'Off';

  @override
  String get webhookWaitingForServer => 'Waiting for the server.';

  @override
  String get webhookReceiving => 'Receiving';

  @override
  String get webhookPaused => 'Paused';

  @override
  String get webhookShowDeliveries => 'Show deliveries';

  @override
  String get webhookHideDeliveries => 'Hide deliveries';

  @override
  String get webhookDelete => 'Delete';

  @override
  String webhookResumeFailed(String reason) {
    return 'That endpoint was not resumed. $reason';
  }

  @override
  String webhookPauseFailed(String reason) {
    return 'That endpoint was not paused. $reason';
  }

  @override
  String get webhookDeleteAction => 'Delete this endpoint?';

  @override
  String get webhookDeleteConsequenceStops =>
      'It stops receiving events immediately.';

  @override
  String get webhookDeleteConsequenceHistory =>
      'Its delivery history is removed with it.';

  @override
  String get webhookDeleteConsequenceDelivered =>
      'Nothing already delivered is withdrawn.';

  @override
  String get webhookDeleteCommit => 'Delete this endpoint';

  @override
  String get webhookDeleteCancel => 'Keep it';

  @override
  String webhookDeleteFailed(String reason) {
    return 'That endpoint was not deleted. $reason';
  }

  @override
  String get webhookDeliveriesSection => 'Recent deliveries';

  @override
  String webhookDeliveriesShowing(int shown) {
    return 'Showing the $shown most recent. There are more.';
  }

  @override
  String get webhookDeliveriesSkeleton => 'deliveries';

  @override
  String get webhookDeliveriesEmptyHeadline => 'No deliveries yet.';

  @override
  String get webhookDeliveriesEmptyBody =>
      'One appears each time the event fires.';

  @override
  String webhookDeliveredWhen(String when) {
    return 'Delivered $when';
  }

  @override
  String webhookNextRetryWhen(String when) {
    return 'Next retry $when';
  }

  @override
  String get webhookNoMoreRetries => 'No more retries';

  @override
  String webhookCreatedWhen(String when) {
    return 'Created $when';
  }

  @override
  String webhookHttpStatus(int code) {
    return 'HTTP $code';
  }

  @override
  String get webhookNotSentYet => 'Not sent yet';

  @override
  String get webhookNoResponse => 'No response';

  @override
  String webhookAttempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attempts',
      one: '1 attempt',
    );
    return '$_temp0';
  }

  @override
  String get webhookRedeliver => 'Redeliver';

  @override
  String get webhookQueueing => 'Queueing…';

  @override
  String get webhookRedeliveryQueued => 'Redelivery queued.';

  @override
  String webhookRedeliverFailed(String reason) {
    return 'That delivery was not re-queued. $reason';
  }

  @override
  String get webhookCreateSubtitle =>
      'It receives a POST every time its event fires.';

  @override
  String get webhookCreateAddress => 'Address';

  @override
  String get webhookCreateAddressHelp =>
      'A public http or https address the server can reach.';

  @override
  String get webhookCreateNotAUrl => 'That is not a web address.';

  @override
  String get webhookCreateWrongScheme =>
      'The address has to start with http:// or https://.';

  @override
  String get webhookCreateBlockedUrl => 'Give the endpoint a web address.';

  @override
  String get webhookCreateBlockedEvent => 'Pick the event it listens for.';

  @override
  String get webhookCreateEvent => 'Event';

  @override
  String get webhookCreateSecret => 'Signing secret (optional)';

  @override
  String get webhookCreateSecretHelp =>
      'Deliveries are signed with it. It is stored on the server and never shown again — keep your own copy.';

  @override
  String get webhookCreateFailed => 'The endpoint was not added.';

  @override
  String get webhookCreateCommit => 'Add this endpoint';

  @override
  String get webhookCreateAdding => 'Adding…';

  @override
  String get webhookCreateCancel => 'Cancel';

  @override
  String get messagesTitle => 'Messages';

  @override
  String get messagesFact => 'Everything the team can see.';

  @override
  String get messagesRefresh => 'Refresh the team channel';

  @override
  String get messagesWhichFeed => 'Which feed';

  @override
  String get messagesFeedAnnouncements => 'Announcements';

  @override
  String get messagesSkeleton => 'messages';

  @override
  String get announcementsSkeleton => 'announcements';

  @override
  String get messagesEmptyHeadline => 'No messages yet.';

  @override
  String get messagesEmptyBody =>
      'Anything you send below reaches the whole team.';

  @override
  String messagesShowing(int shown) {
    return 'Showing $shown. There are older messages.';
  }

  @override
  String get messagesShowOlder => 'Show older messages';

  @override
  String announcementsShowing(int shown) {
    return 'Showing $shown. There are older announcements.';
  }

  @override
  String get announcementsShowOlder => 'Show older announcements';

  @override
  String get feedMoreFailed => 'Older items did not load';

  @override
  String get announcementsEmptyHeadline => 'No announcements yet.';

  @override
  String get announcementsEmptyBodyCanPost =>
      'Post one and every user on this client sees it.';

  @override
  String get announcementsEmptyBodyReadOnly =>
      'Your managers post here when something affects everyone.';

  @override
  String get announcementNew => 'New announcement';

  @override
  String get announcementPosted => 'Posted to everyone on this client.';

  @override
  String announcementPostFailed(String reason) {
    return 'That announcement was not posted. $reason';
  }

  @override
  String get messagePhotoOne => 'Photo';

  @override
  String messagePhotoMany(int count) {
    return '$count photos';
  }

  @override
  String get messageDirect => 'Direct';

  @override
  String get messageBroadcast => 'Broadcast';

  @override
  String messageFrom(String name) {
    return 'From $name';
  }

  @override
  String messageTo(String name) {
    return 'To $name';
  }

  @override
  String get messageToTeam => 'To the whole team';

  @override
  String get messageDirectUnknownRecipient => 'Direct message';

  @override
  String messageSenderNotOnRoster(String id) {
    return 'Sender not on the roster: $id';
  }

  @override
  String messageRecipientNotOnRoster(String id) {
    return 'Recipient not on the roster: $id';
  }

  @override
  String messagePhotoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '1 photo',
    );
    return '$_temp0';
  }

  @override
  String messagePhotoOfCount(int index, int count) {
    return 'Photo $index of $count';
  }

  @override
  String get messageLongPressForId => 'Long press to copy the message id';

  @override
  String get messageIdCopied => 'Message id copied.';

  @override
  String get announcementSubtitle => 'Broadcast to the whole client';

  @override
  String announcementSemantics(String title, String body) {
    return '$title. $body. Broadcast to the whole client.';
  }

  @override
  String get attachSheetTitle => 'Add a photo';

  @override
  String get attachSheetSubtitle =>
      'It is uploaded when the message is sent, not before.';

  @override
  String get attachCamera => 'Take a photo';

  @override
  String get attachGallery => 'Choose from the library';

  @override
  String get announcementSheetSubtitle => 'Every user on this client sees it.';

  @override
  String get announcementSheetHeadline => 'Headline';

  @override
  String get announcementSheetBody => 'What it says';

  @override
  String get announcementSheetBlockedTitle =>
      'Give the announcement a headline.';

  @override
  String get announcementSheetBlockedBody => 'Say what it is about.';

  @override
  String get announcementSheetCommit => 'Post this announcement';

  @override
  String get announcementSheetCancel => 'Cancel';

  @override
  String get composerLabel => 'Message the team';

  @override
  String get composerNotSent => 'Not sent.';

  @override
  String get composerSend => 'Send';

  @override
  String get composerSending => 'Sending…';

  @override
  String get composerBlockedEmpty => 'Write something, or add a photo.';

  @override
  String get composerAddPhoto => 'Add a photo to this message';

  @override
  String composerPhotoCap(int max) {
    return 'Up to $max photos per message';
  }

  @override
  String composerPhotoCapLine(int max) {
    return 'Up to $max photos.';
  }

  @override
  String composerPhotosAttached(int count, int max) {
    return '$count of $max photos attached.';
  }

  @override
  String get composerPhotoFailed =>
      'Could not add a photo. Check camera and photo permissions.';

  @override
  String composerUploadFailed(String reason) {
    return 'A photo failed to upload, so nothing was sent. $reason Your draft is kept.';
  }

  @override
  String composerSendFailed(String reason) {
    return 'Message not sent. $reason Your draft is kept.';
  }

  @override
  String pendingPhotoReady(int index) {
    return 'Photo $index ready to send';
  }

  @override
  String pendingPhotoRemove(int index) {
    return 'Take photo $index out of this message';
  }

  @override
  String get attachmentSheetTitle => 'Photo';

  @override
  String get attachmentSheetSkeleton => 'the photo';

  @override
  String get attachmentSheetClose => 'Close';

  @override
  String get attachmentUndecodableHeadline =>
      'This photo could not be displayed.';

  @override
  String get attachmentUndecodableBody =>
      'The file arrived, but it is not an image this device can decode.';

  @override
  String get figureSmallSample => 'small sample';

  @override
  String get figureNotScored => 'not scored';

  @override
  String get figureProvisional => 'Provisional';

  @override
  String get pickerSelected => 'Selected';

  @override
  String outletDisputePhotoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count storefront photographs attached',
      one: '1 storefront photograph attached',
    );
    return '$_temp0';
  }

  @override
  String get ordersStoreListLoading => 'Store list still loading';

  @override
  String get ordersStoreListUnavailable => 'Store list did not load';

  @override
  String get beatPlanStopUnknownStore => 'Store not on this list';

  @override
  String get beatPlanStopStoreLoading => 'Store list still loading';

  @override
  String get beatPlanStopStoreUnavailable => 'Store list did not load';

  @override
  String get salesLevelZeroTarget =>
      'Every target at this level is 0 units, so there is nothing to attain.';

  @override
  String get salesLevelAttainmentUnknown =>
      'The share of target was not worked out for this level.';

  @override
  String get salesZeroTarget => 'Target of 0 units';

  @override
  String get trailTitle => 'Agent trail';

  @override
  String get trailRefresh => 'Refresh this day';

  @override
  String get trailPickDay => 'Pick another day';

  @override
  String get trailSkeleton => 'this day';

  @override
  String get trailRetry => 'Try again';

  @override
  String get trailEmptyHeadline => 'No check-ins on this day.';

  @override
  String get trailEmptyBody =>
      'A pin appears here when an agent confirms a check-in. Pick another day to see one that has some.';

  @override
  String trailAgentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count agents',
      one: '1 agent',
    );
    return '$_temp0';
  }

  @override
  String trailStopCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stops',
      one: '1 stop',
    );
    return '$_temp0';
  }

  @override
  String get trailHowToRead => 'How to read it';

  @override
  String get trailLegendPins =>
      'Numbered pins are confirmed check-ins, in order, and the last one of each agent is filled. Dashed lines connect them — they are not a recorded route.';

  @override
  String trailLegendLive(String when) {
    return 'Squares are live positions from the agent app, labelled with their age first. Last updated $when.';
  }

  @override
  String get trailFooterSummary => 'Showing the first 200 agents only.';

  @override
  String get trailFooterNarrow =>
      'A partial map that looks complete is worse than no map: the rest of the day is not here.';

  @override
  String get trailStillInShop => 'Still in this shop';

  @override
  String get trailLastStop => 'Last stop';

  @override
  String trailCheckedInAt(String time) {
    return 'checked in at $time';
  }

  @override
  String get trailNoMapHeadline => 'No map in the sun.';

  @override
  String get trailNoMapBody =>
      'A dark basemap read outdoors is a black rectangle. Every stop is listed below, in order, with the time it was confirmed.';

  @override
  String get trailMapOfflineHeadline => 'The map will not load.';

  @override
  String get trailMapOfflineBody =>
      'The tiles are not arriving. Every stop is listed below, in order: nothing about the day is missing, only the picture of it.';

  @override
  String liveLastNear(String when) {
    return 'last near $when';
  }

  @override
  String liveLastCheckIn(String when) {
    return 'last check-in $when';
  }

  @override
  String liveNear(String place) {
    return 'Near $place';
  }

  @override
  String get liveNeverShared => 'never shared';

  @override
  String liveLocationOf(String description) {
    return 'Live location: $description';
  }

  @override
  String get liveLocationFailed =>
      'Live location could not load. Trying again shortly.';

  @override
  String get liveLocationLoading => 'Live location: loading…';

  @override
  String get liveLocationHeading => 'Live location';

  @override
  String liveLastUpdated(String when) {
    return 'Last updated $when';
  }

  @override
  String get liveLocationNote =>
      'Sent by the agent app only while it is open. Each row starts with how old that position was at the last update.';

  @override
  String get liveCouldNotRefresh =>
      'Could not refresh. Showing the last update.';

  @override
  String get liveFirst200 => 'Showing the first 200 agents.';

  @override
  String get fraudTitle => 'Fraud review';

  @override
  String get fraudFact =>
      'Risk is scored 0–100 on submit. The signals are the evidence.';

  @override
  String get fraudRefresh => 'Refresh the review queue';

  @override
  String get fraudSkeleton => 'flagged visits';

  @override
  String get fraudRetry => 'Try again';

  @override
  String get fraudFilterRail => 'Which flagged visits';

  @override
  String get fraudFilterOpen => 'Open';

  @override
  String get fraudFilterDecided => 'Decided';

  @override
  String get fraudFilterAll => 'All';

  @override
  String get fraudSectionOpen => 'Open';

  @override
  String get fraudSectionDecided => 'Decided';

  @override
  String get fraudSectionAll => 'Every flagged visit';

  @override
  String get fraudEmptyLineOpen => 'Nothing waiting on a ruling.';

  @override
  String get fraudEmptyLineDecided => 'Nothing ruled on yet.';

  @override
  String get fraudEmptyLineAll => 'Nothing flagged.';

  @override
  String get fraudEmptyHeadlineOpen => 'Nothing waiting on you.';

  @override
  String get fraudEmptyHeadlineDecided => 'No rulings recorded yet.';

  @override
  String get fraudEmptyHeadlineAll => 'Nothing flagged.';

  @override
  String get fraudEmptyBodyOpen =>
      'A visit appears here when the fraud engine scores one above the review threshold. Ruled visits move to Decided.';

  @override
  String get fraudEmptyBodyDecided =>
      'A visit appears here once somebody records a ruling on it.';

  @override
  String get fraudEmptyBodyAll =>
      'Visits appear here when the fraud engine scores one above the review threshold.';

  @override
  String fraudFooterShowing(String count) {
    return 'Showing the $count riskiest.';
  }

  @override
  String fraudUnscoredNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count submitted visits have not been scored yet and are not listed here.',
      one: '1 submitted visit has not been scored yet and is not listed here.',
    );
    return '$_temp0';
  }

  @override
  String get fraudUnknownAgent => 'Unknown agent';

  @override
  String get fraudUnnamedOutlet => 'Outlet name unavailable';

  @override
  String get fraudVisitIdentifier => 'Visit';

  @override
  String fraudRisk(String score) {
    return 'Risk $score';
  }

  @override
  String fraudRiskOf100(String score) {
    return 'Risk $score of 100';
  }

  @override
  String get fraudNotYetReviewed => 'Not yet reviewed';

  @override
  String get fraudVerdictCleared => 'Cleared';

  @override
  String get fraudVerdictConfirmed => 'Confirmed';

  @override
  String get fraudVerdictNeedsEvidence => 'Needs evidence';

  @override
  String get fraudBandHigh => 'High risk';

  @override
  String get fraudBandElevated => 'Elevated';

  @override
  String get fraudBandLow => 'Low risk';

  @override
  String get fraudRuleOnThisVisit => 'Rule on this visit';

  @override
  String get fraudSeeTheRuling => 'See the ruling';

  @override
  String get fraudSeeTheVisit => 'See the visit';

  @override
  String get fraudReviewerFallback => 'A reviewer';

  @override
  String fraudRuledIt(String who, String verdict) {
    return '$who ruled it $verdict.';
  }

  @override
  String get fraudVerdictClearedPast => 'cleared';

  @override
  String get fraudVerdictConfirmedPast => 'confirmed';

  @override
  String get fraudVerdictNeedsEvidencePast => 'as needing evidence';

  @override
  String get fraudSeenUnscored => 'The visit was unscored at the time.';

  @override
  String fraudSeenAtRisk(String score) {
    return 'They were looking at risk $score.';
  }

  @override
  String fraudSheetSubtitle(String outlet, String score, String band) {
    return '$outlet · risk $score of 100 · $band';
  }

  @override
  String get fraudWhatEngineFound => 'What the engine found';

  @override
  String get fraudNoSignalsHeadline => 'No signals recorded.';

  @override
  String get fraudNoSignalsBody =>
      'The visit scored above the threshold but the rules that fired were not stored with it. Open the visit to judge it on its own record.';

  @override
  String get fraudYourRuling => 'Your ruling';

  @override
  String get fraudRecordThisRuling => 'Record this ruling';

  @override
  String get fraudNoteLabel => 'Note';

  @override
  String get fraudNoteHint => 'What you checked, and what you found';

  @override
  String get fraudNoteHelp =>
      'Whoever reads this decision next sees only what you write here.';

  @override
  String get fraudNotChosenLine => 'No ruling chosen yet';

  @override
  String get fraudChooseFirst => 'Choose a ruling first.';

  @override
  String get fraudConsequenceCleared =>
      'The visit stands and leaves the queue. The agent keeps its points.';

  @override
  String get fraudConsequenceConfirmed =>
      'The work is recorded as faked. This is the one ruling that accuses a person.';

  @override
  String get fraudConsequenceNeedsEvidence =>
      'Nobody can tell yet. It leaves the open queue and the note is what somebody works from.';

  @override
  String get fraudNeedsEvidenceNoteBecause =>
      'Say what evidence is missing, so somebody can go and get it. \"Needs evidence\" with no note is a visit that was processed rather than reviewed.';

  @override
  String get fraudNotNow => 'Not now';

  @override
  String get fraudClose => 'Close';

  @override
  String get fraudRulingStands => 'The ruling that stands';

  @override
  String get fraudStandingUnscored =>
      'The visit was unscored at the time, so there is no number behind this decision.';

  @override
  String fraudStandingAtRisk(String score) {
    return 'They were looking at risk $score of 100. A rescore since then does not move the ruling.';
  }

  @override
  String get fraudRuledOnce =>
      'A visit is ruled once. Reopening it is a change to the record and is not done from here.';

  @override
  String get leaderboardTitle => 'Leaderboard';

  @override
  String get leaderboardFact =>
      'Points: the average scorecard, plus 5 a closed task and 2 a submitted visit.';

  @override
  String get leaderboardRefresh => 'Refresh the leaderboard';

  @override
  String get leaderboardContests => 'Contests';

  @override
  String get leaderboardSkeleton => 'the leaderboard';

  @override
  String get leaderboardRetry => 'Try again';

  @override
  String get leaderboardEmptyHeadline => 'Nobody on the board yet.';

  @override
  String get leaderboardEmptyBody =>
      'Agents appear here once there is a field agent on this client to measure.';

  @override
  String get leaderboardRanked => 'Ranked';

  @override
  String get leaderboardRankedEmptyLine =>
      'Nobody has a place in this window yet.';

  @override
  String get leaderboardNotRanked => 'Not ranked yet';

  @override
  String get leaderboardUnrankedNote =>
      'Nothing measured for these agents in this window — no submitted visit, no closed task, no scorecard. They are not last; nobody has measured them.';

  @override
  String leaderboardRank(String rank) {
    return 'Rank $rank';
  }

  @override
  String leaderboardRowTrailing(String rank, String points) {
    return 'Rank $rank, $points points';
  }

  @override
  String get pointsRefresh => 'Refresh this points history';

  @override
  String get pointsBackToLeaderboard => 'Back to the leaderboard';

  @override
  String get pointsTitle => 'Points history';

  @override
  String get pointsSkeleton => 'this points history';

  @override
  String get pointsRetry => 'Try again';

  @override
  String get pointsLedgerHeading => 'Ledger';

  @override
  String get pointsNothingRecorded => 'Nothing recorded yet.';

  @override
  String get pointsEmptyHeadline => 'No points yet.';

  @override
  String get pointsEmptyBody =>
      'Entries appear as this agent submits visits, closes tasks and is scored.';

  @override
  String pointsTwoFigures(String name) {
    return 'Two figures for $name.';
  }

  @override
  String get pointsEarnedEyebrow => 'Points earned';

  @override
  String get pointsUnitWord => 'pts';

  @override
  String get pointsStateLine =>
      'The average scorecard, plus 5 a closed task and 2 a submitted visit.';

  @override
  String get pointsPayoutAbsent =>
      'Nothing recorded for this agent in this window.';

  @override
  String get pointsAverageEyebrow => 'Average scorecard';

  @override
  String get pointsNoScoredVisit => 'No scored visit in this window.';

  @override
  String pointsCounts(String visits, String tasks) {
    return '$visits visits submitted · $tasks tasks closed';
  }

  @override
  String pointsFooterSummary(String count) {
    return 'Showing the $count newest entries. There are more.';
  }

  @override
  String pointsScored(String score) {
    return 'scored $score';
  }

  @override
  String pointsSpokenPoints(String points) {
    return '$points points';
  }

  @override
  String get incentivesTitle => 'Incentives';

  @override
  String get incentivesFact =>
      'A scheme awards points when an agent reaches its threshold on the chosen metric. Paused schemes stop awarding.';

  @override
  String get incentivesRefresh => 'Refresh the incentive schemes';

  @override
  String get incentivesSkeleton => 'incentive schemes';

  @override
  String get incentivesRetry => 'Try again';

  @override
  String incentivesAwardingFact(String awarding, String total) {
    return '$awarding of $total awarding';
  }

  @override
  String get incentivesSchemes => 'Schemes';

  @override
  String get incentivesNoneConfigured => 'None configured.';

  @override
  String get incentivesAddScheme => 'Add a scheme';

  @override
  String get incentivesEmptyHeadline => 'No schemes configured.';

  @override
  String get incentivesEmptyBody =>
      'Add one to start rewarding agents who clear a threshold. Nothing pays out until there is a scheme.';

  @override
  String get incentivesAwarding => 'Awarding';

  @override
  String get incentivesPaused => 'Paused';

  @override
  String incentivesRuleWithUnit(
    String state,
    String metric,
    String threshold,
    String unit,
    String reward,
  ) {
    return '$state · $metric · $threshold $unit · $reward';
  }

  @override
  String incentivesRuleNoUnit(
    String state,
    String metric,
    String threshold,
    String reward,
  ) {
    return '$state · $metric · at least $threshold · $reward';
  }

  @override
  String incentivesPauseScheme(String name) {
    return 'Pause $name';
  }

  @override
  String incentivesStartScheme(String name) {
    return 'Start $name awarding';
  }

  @override
  String get incentivesSeeEveryone => 'See everyone';

  @override
  String get incentivesDeleteScheme => 'Delete this scheme';

  @override
  String incentivesCouldNotStart(String name) {
    return 'Could not start $name awarding.';
  }

  @override
  String incentivesCouldNotPause(String name) {
    return 'Could not pause $name.';
  }

  @override
  String incentivesDeleteAction(String name) {
    return 'Delete $name?';
  }

  @override
  String get incentivesDeleteStops => 'It stops awarding immediately.';

  @override
  String get incentivesDeleteKeeps =>
      'Points already awarded stay on the agents who earned them.';

  @override
  String incentivesEarnedSoFar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count agents have earned it so far.',
      one: '1 agent has earned it so far.',
    );
    return '$_temp0';
  }

  @override
  String incentivesCouldNotDelete(String name) {
    return 'Could not delete $name. It is still awarding.';
  }

  @override
  String incentivesUnknownMetric(String metric) {
    return 'This client does not recognise the metric \"$metric\", so progress toward it cannot be shown here.';
  }

  @override
  String get incentivesNoBoard =>
      'No agent figures loaded, so progress toward this reward is not shown.';

  @override
  String incentivesNobodyMeasured(String metric) {
    return 'Nobody has been measured on $metric in this window, so there is no progress toward this reward to show yet.';
  }

  @override
  String get incentivesEverybodyEarned =>
      'Everybody this metric can measure has earned it.';

  @override
  String incentivesClosest(String name) {
    return 'Closest: $name';
  }

  @override
  String incentivesFractionUnit(String value, String threshold, String unit) {
    return '$value of $threshold $unit';
  }

  @override
  String incentivesFraction(String value, String threshold) {
    return '$value of $threshold';
  }

  @override
  String incentivesRewardAt(String reward, String threshold, String unit) {
    return '$reward at $threshold $unit';
  }

  @override
  String incentivesRewardPoints(String points) {
    return '$points pts';
  }

  @override
  String incentivesEarnedOf(int count, String earned) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$earned of $count agents have earned it.',
      one: '$earned of 1 agent has earned it.',
    );
    return '$_temp0';
  }

  @override
  String get incentiveMetricScorecard => 'Average scorecard';

  @override
  String get incentiveMetricTasksClosed => 'Tasks closed';

  @override
  String get incentiveMetricVisits => 'Visits submitted';

  @override
  String get incentiveUnitPoints => 'points';

  @override
  String get incentiveUnitTasks => 'tasks';

  @override
  String get incentiveUnitVisits => 'visits';

  @override
  String get schemeFormTitle => 'Add a scheme';

  @override
  String get schemeFormSubtitle => 'It starts awarding as soon as it is saved.';

  @override
  String get schemeFormName => 'Name';

  @override
  String get schemeFormNameHint =>
      'What a manager will call it — \"Twenty visits\"';

  @override
  String get schemeFormNameError => 'Give the scheme a name.';

  @override
  String get schemeFormMetricLabel => 'What it pays on';

  @override
  String get schemeFormMetricNotAnswered => 'No metric chosen yet';

  @override
  String get schemeFormMetricError => 'Choose what the scheme pays on.';

  @override
  String get schemeFormScorecardConsequence =>
      'Pays when the agent\'s 0–100 mean clears the threshold.';

  @override
  String get schemeFormTasksConsequence => 'Pays on a count of closures.';

  @override
  String get schemeFormVisitsConsequence =>
      'Pays on a count of submitted visits.';

  @override
  String get schemeFormThreshold => 'Threshold';

  @override
  String get schemeFormThresholdHelp => 'What an agent has to reach.';

  @override
  String schemeFormThresholdHelpUnit(String unit) {
    return 'What an agent has to reach, in $unit.';
  }

  @override
  String get schemeFormThresholdError =>
      'Say the figure an agent has to reach.';

  @override
  String get schemeFormThresholdZero =>
      'A threshold of nought is a scheme that pays out to everybody the moment it is created.';

  @override
  String get schemeFormReward => 'Reward';

  @override
  String get schemeFormRewardHelp => 'What clearing it awards.';

  @override
  String get schemeFormRewardError => 'Say how many points it awards.';

  @override
  String get schemeFormRewardZero => 'A reward of nought is not a reward.';

  @override
  String get schemeFormSave => 'Save this scheme';

  @override
  String get schemeFormBlocked =>
      'A scheme needs a name, a metric, a threshold and a reward.';

  @override
  String get schemeFormNotNow => 'Not now';

  @override
  String get schemeProgressEveryone => 'Everyone';

  @override
  String schemeProgressSubtitle(String metric, String reward) {
    return '$metric · $reward';
  }

  @override
  String get schemeProgressEmptyHeadline => 'No agent figures loaded.';

  @override
  String get schemeProgressEmptyBody =>
      'Progress toward this reward is read from the board, and the board has not answered.';

  @override
  String get schemeProgressUnmeasured => 'Not measured on this metric yet.';

  @override
  String get schemeProgressEarned => 'Earned';

  @override
  String get schemeProgressNobodyMeasured =>
      'Nobody above has been measured on this metric in this window, so there is nothing to count yet.';

  @override
  String get schemeProgressClose => 'Close';

  @override
  String get liveStateAtStore => 'At store';

  @override
  String get liveStateNearStore => 'Near store';

  @override
  String get liveStateInTransit => 'In transit';

  @override
  String get liveStateStale => 'Stale';

  @override
  String get liveStateOffline => 'Offline';

  @override
  String get liveStateNotSharing => 'Not sharing';

  @override
  String liveAgeSeconds(String seconds) {
    return '${seconds}s';
  }

  @override
  String liveAgeMinutes(String minutes) {
    return '$minutes min';
  }

  @override
  String liveAgeHours(String hours) {
    return '$hours h';
  }

  @override
  String liveAgeHoursMinutes(String hours, String minutes) {
    return '$hours h $minutes min';
  }

  @override
  String liveAgeDays(String days) {
    return '$days d';
  }

  @override
  String liveAtOutlet(String outlet) {
    return 'at $outlet';
  }

  @override
  String liveNearOutlet(String outlet) {
    return 'near $outlet';
  }

  @override
  String liveAgeOld(String age) {
    return '$age old';
  }

  @override
  String trailPinLabel(
    String agent,
    String ordinal,
    String outlet,
    String time,
  ) {
    return '$agent, stop $ordinal, $outlet, $time';
  }

  @override
  String get dashOverviewTitle => 'Execution overview';

  @override
  String get dashRefresh => 'Refresh every panel';

  @override
  String get dashFilters => 'Filters';

  @override
  String get dashAllTerritories => 'All territories';

  @override
  String get dashOneTerritory => 'One territory';

  @override
  String get dashTerritory => 'Territory';

  @override
  String get dashTerritorySheetBody =>
      'Every figure below is scoped to this choice.';

  @override
  String get dashSelected => 'Selected';

  @override
  String get dashRangeLast7 => 'Last 7 days';

  @override
  String get dashRangeLast30 => 'Last 30 days';

  @override
  String get dashRangeLast90 => 'Last 90 days';

  @override
  String get dashRangeYtd => 'Year to date';

  @override
  String get dashRangeAll => 'All time';

  @override
  String get dashExecutionScore => 'Execution score';

  @override
  String dashExecutionScoreSupports(int target) {
    return 'Weighted S2–S8, all outlets · target $target';
  }

  @override
  String get dashScoreTrend => 'Execution score over time';

  @override
  String get dashVsWindowBefore => 'vs the window before';

  @override
  String get dashNeedsAttention => 'Needs attention';

  @override
  String get dashViewAllAlerts => 'All alerts';

  @override
  String get dashCriticalAlerts => 'Critical alerts open';

  @override
  String get dashWarningAlerts => 'Warnings awaiting acknowledgement';

  @override
  String get dashTasksOpen => 'Tasks still open';

  @override
  String get dashNothingOutstanding => 'Nothing outstanding';

  @override
  String get dashNoneAtCritical => 'None at critical priority';

  @override
  String dashNAtCritical(int count) {
    return '$count at critical priority';
  }

  @override
  String get dashSeverityCritical => 'Critical';

  @override
  String get dashSeverityWatch => 'Watch';

  @override
  String get dashAgainstStandard => 'Where we sit against the standard';

  @override
  String get dashTickMarksTarget => 'The tick marks the target.';

  @override
  String get dashKpiOsa => 'On-shelf availability';

  @override
  String get dashKpiOsaNote => 'Floor 95% · target 97–99%';

  @override
  String get dashKpiPerfectStore => 'Perfect-store rate';

  @override
  String get dashKpiPerfectStoreNote =>
      'Healthy 80–90% · below 70% is an execution gap';

  @override
  String get dashKpiPrice => 'Price compliance';

  @override
  String get dashKpiPriceNote => 'Within tolerance of the recommended price';

  @override
  String get dashKpiVisibility => 'Visibility compliance';

  @override
  String get dashKpiVisibilityNote => 'Planogram threshold';

  @override
  String get dashKpiShareOfShelf => 'Share of shelf';

  @override
  String get dashKpiShareOfShelfNote => 'Category fair share';

  @override
  String get dashKpiWeighted => 'Weighted distribution';

  @override
  String get dashKpiWeightedNote => 'Volume-weighted';

  @override
  String get dashKpiNumeric => 'Numeric distribution';

  @override
  String get dashKpiNumericNote => 'Outlets stocking';

  @override
  String get dashStandingCritical => 'Below the standard';

  @override
  String get dashStandingWatch => 'Close to the standard';

  @override
  String get dashStandingOnTarget => 'On the standard';

  @override
  String dashTargetIs(String target) {
    return 'Target $target';
  }

  @override
  String get dashDistribution => 'Perfect-store distribution';

  @override
  String get dashHealthyBand =>
      'Outlets by their latest scored visit · healthy band 80–90.';

  @override
  String dashBandOutlets(int count, String band) {
    return '$count outlets scoring $band';
  }

  @override
  String get dashByTerritory => 'Execution score by territory';

  @override
  String get dashNoTerritories => 'No territories defined';

  @override
  String get dashNoTerritoriesBody =>
      'Add a territory to compare scores across the field.';

  @override
  String get dashNoTerritoryScores => 'No territory scores yet';

  @override
  String get dashNoTerritoryScoresBody =>
      'Scores appear once visits in this window have been scored.';

  @override
  String get dashAvailabilityByPeriod => 'On-shelf availability by period';

  @override
  String get dashWhereAgents => 'Where are my agents';

  @override
  String get dashTodaysCheckIns =>
      'Today’s confirmed check-ins. A pin is where somebody checked in, not where they are now.';

  @override
  String get dashViewMap => 'Open the map';

  @override
  String get dashNoAgentsHeadline => 'Nobody to show';

  @override
  String get dashNoAgentsYet => 'No field agents yet.';

  @override
  String get dashNoAgentsForFilter => 'No agents match this territory filter.';

  @override
  String dashNoAgentsIn(String name) {
    return 'No agents are assigned to $name.';
  }

  @override
  String get dashNoOutletsToPlot =>
      'No outlets yet — add outlets to see them here.';

  @override
  String dashOnTheMap(int plotted, int notPlotted) {
    return '$plotted on the map · $notPlotted not checked in today';
  }

  @override
  String get dashFirst200Agents =>
      'Showing the first 200 agents. Filter by territory to narrow.';

  @override
  String get dashNoCheckIn => 'No check-in';

  @override
  String get dashNoCheckInToday => 'no check-in today';

  @override
  String get dashUnknownStore => 'unknown store';

  @override
  String get dashInTransit => 'in transit';

  @override
  String dashLeft(String outlet) {
    return 'left $outlet';
  }

  @override
  String dashOutletPin(String outlet) {
    return '$outlet outlet';
  }

  @override
  String get dashNoVisitsInWindow => 'No visits in this window';

  @override
  String get dashFirstRunHeadline => 'Nothing on the books yet';

  @override
  String get dashFirstRunBody =>
      'Add outlets and territories, and this console fills in as visits are submitted and scored.';

  @override
  String get dashStubCaveat =>
      'Visibility compliance and share of shelf are derived from the Phase-1 computer-vision stub.';

  @override
  String get visitReviewTitle => 'Visit review';

  @override
  String get visitBackToList => 'Back to the list you came from';

  @override
  String get visitBackToFloor => 'Back to The Floor';

  @override
  String get visitInProgress => 'Unfinished';

  @override
  String get visitOutsideFence => 'Outside the fence';

  @override
  String get visitInsideFence => 'Inside the fence';

  @override
  String get visitPinReported => 'The agent reported the pin is wrong';

  @override
  String get visitTheVisit => 'The visit';

  @override
  String get visitCheckedIn => 'Checked in';

  @override
  String get visitDeviceClock => 'From the phone\'s own clock';

  @override
  String get visitSubmitted => 'Submitted';

  @override
  String get visitNotYet => 'Not yet';

  @override
  String visitMinutesOnSite(int minutes) {
    return '$minutes minutes on site';
  }

  @override
  String get visitGeofence => 'Distance from the store';

  @override
  String get visitNoDistance => 'No distance was recorded';

  @override
  String get visitPin => 'Pin';

  @override
  String get visitPinMoved => 'The pin was moved';

  @override
  String visitPinMovedBy(String name) {
    return 'The pin was moved by $name';
  }

  @override
  String get visitPinKept => 'The pin was kept';

  @override
  String visitPinKeptBy(String name) {
    return 'The pin was kept by $name';
  }

  @override
  String get visitPinWaiting => 'Waiting for review';

  @override
  String get visitScoreHeading => 'Perfect store score';

  @override
  String get visitNotScored => 'Not scored';

  @override
  String get visitScoredOnSubmit =>
      'The score is calculated when the visit is submitted.';

  @override
  String get visitNoScorecard =>
      'No scorecard has been generated for this visit.';

  @override
  String get visitUnbanded => 'Unbanded';

  @override
  String visitScoreMeterSemantics(int value, int target) {
    return '$value out of 100, target $target';
  }

  @override
  String get visitHowScored => 'How it was scored';

  @override
  String get visitOnTarget => 'On target';

  @override
  String get visitBelowTarget => 'Below target';

  @override
  String visitAnsweredVersion(int version) {
    return 'Answered against v$version';
  }

  @override
  String visitAnsweredOlderVersion(int version, int current) {
    return 'Answered against v$version · the template is now v$current, and the labels below come from the current version';
  }

  @override
  String visitAnswerOrphan(String field) {
    return '$field (no longer in the template)';
  }

  @override
  String visitRequiredQuestion(String label) {
    return '$label (required)';
  }

  @override
  String visitTemplateScore(String score, String max) {
    return 'Template score $score of $max';
  }

  @override
  String get visitTemplateScoreNote =>
      'The template score is the client\'s own measure. It is not part of the perfect store score.';

  @override
  String get visitNoAnswersHeadline => 'No answers were recorded';

  @override
  String get visitNoAnswersBody =>
      'The template was attached to this visit and nothing was filled in.';

  @override
  String get visitNotCaptured => 'Not captured in the app';

  @override
  String get visitNotAnswered => 'Not answered';

  @override
  String get visitYes => 'Yes';

  @override
  String get visitNo => 'No';

  @override
  String get visitWhatWasCaptured => 'What was captured';

  @override
  String get visitNothingCaptured => 'Nothing was captured';

  @override
  String get visitCaptured => 'Captured';

  @override
  String visitNCaptured(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count captured',
      one: '1 captured',
    );
    return '$_temp0';
  }

  @override
  String get visitClear => 'Clear';

  @override
  String visitNFlagged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count flagged',
      one: '1 flagged',
    );
    return '$_temp0';
  }

  @override
  String get visitNotCapturedSection => 'Not captured';

  @override
  String get visitNoFindings => 'No findings.';

  @override
  String get visitNothingRecorded => 'Nothing was recorded in this section.';

  @override
  String get visitFindingsTruncated =>
      'Findings drawn from the first 500 rows.';

  @override
  String get visitSeverityCritical => 'Critical';

  @override
  String get visitSeverityWatch => 'Watch';

  @override
  String get visitPhotos => 'Photos';

  @override
  String get visitNoPhotos => 'No photos were captured on this visit.';

  @override
  String visitShowingOf(int shown, int total) {
    return 'Showing $shown of $total';
  }

  @override
  String visitPhotoSemantics(String outlet, String section, String time) {
    return '$outlet, $section, $time';
  }

  @override
  String get visitFraudSignals => 'Fraud signals';

  @override
  String get visitRiskOfHundred => 'of 100';

  @override
  String visitRiskSemantics(int value, String band) {
    return 'Risk $value out of 100. $band.';
  }

  @override
  String get visitNotFoundHeadline => 'This visit is not here';

  @override
  String get visitNotFoundBody =>
      'It does not exist, or it belongs to another client.';

  @override
  String get visitBackToAlerts => 'Back to alerts';

  @override
  String visitReviewScoreSemantics(int value, String band) {
    return '$value out of 100. $band.';
  }

  @override
  String visitReviewClientQuestions(String template) {
    return 'Client questions · $template';
  }

  @override
  String get artifactTitleView => 'View';

  @override
  String get artifactBackToAsk => 'Back to Ask TradeIQ';

  @override
  String get artifactBackToFloor => 'Back to The Floor';

  @override
  String get artifactFilters => 'Filters';

  @override
  String get artifactUndo => 'Undo';

  @override
  String get artifactPeriod => 'Period';

  @override
  String get artifactPeriodToday => 'Today';

  @override
  String get artifactPeriodYesterday => 'Yesterday';

  @override
  String get artifactPeriodLastWeek => 'Last week';

  @override
  String get artifactPeriodMonthToDate => 'Month to date';

  @override
  String get artifactPeriodYearToDate => 'Year to date';

  @override
  String get artifactPeriodSelected => 'Selected period';

  @override
  String get artifactPickDates => 'Pick dates';

  @override
  String artifactCustomRange(String from, String to) {
    return '$from to $to';
  }

  @override
  String get artifactCustomPeriod => 'Custom period';

  @override
  String get artifactGranularity => 'Granularity';

  @override
  String get artifactDaily => 'Daily';

  @override
  String get artifactWeekly => 'Weekly';

  @override
  String get artifactCompareWith => 'Compare with';

  @override
  String get artifactCompareNone => 'None';

  @override
  String get artifactComparePreviousPeriod => 'The period before';

  @override
  String get artifactCompareLastYear => 'Same period last year';

  @override
  String get artifactCompareTerritory => 'Another territory';

  @override
  String get artifactCompared => 'Compared';

  @override
  String get artifactComparison => 'Comparison';

  @override
  String get artifactTerritory => 'Territory';

  @override
  String get artifactWholeBusiness => 'The whole business';

  @override
  String get artifactTerritorySheetBody =>
      'Every figure in this view is scoped to this choice.';

  @override
  String get artifactTerritoriesLoading => 'Loading territories…';

  @override
  String get artifactTerritoriesUnavailable =>
      'Territories are unavailable — showing the whole business.';

  @override
  String get artifactNoTerritoriesHeadline => 'No territories yet';

  @override
  String get artifactNoTerritoriesBody =>
      'Add a territory to scope this view to part of the business.';

  @override
  String get artifactBusyReason => 'The last change is still being applied.';

  @override
  String get artifactRerunsTheQuery =>
      'Changing a filter re-runs the same query. It does not ask the assistant again.';

  @override
  String get artifactExportPdf => 'Export as a PDF';

  @override
  String get artifactPreparing => 'Preparing…';

  @override
  String get artifactExportBlocked => 'The figures are still being replaced.';

  @override
  String get artifactExportNote =>
      'The chart as an image, every figure as text you can select.';

  @override
  String get artifactExportFailed =>
      'That view could not be exported. Please try again.';

  @override
  String get artifactExportUnavailable =>
      'Exporting is not available in this build of the app. Reload the page — if it keeps happening, the build needs replacing.';

  @override
  String get artifactCouldNotOpenHeadline => 'That view could not be opened';

  @override
  String get artifactCouldNotOpenBody =>
      'It may have been removed, or it belongs to a tool you do not have.';

  @override
  String get artifactRefining => 'Applying the change…';

  @override
  String get artifactNoFiguresHeadline =>
      'No figures were returned for this period';

  @override
  String get artifactNoFiguresBody =>
      'Widen the period, or clear the territory filter.';

  @override
  String get artifactNothingToTabulate => 'Nothing to tabulate';

  @override
  String get artifactNoBaseline => 'no baseline';

  @override
  String get artifactNoFilters => 'No filters applied.';

  @override
  String artifactRangeInWords(String from, String to) {
    return '$from to $to';
  }

  @override
  String get artifactDailyBuckets => 'daily buckets';

  @override
  String get artifactWeeklyBuckets => 'weekly buckets';

  @override
  String get artifactOneTerritory => 'one territory';

  @override
  String get artifactComparedPreviousPeriod =>
      'compared with the period before';

  @override
  String get artifactComparedLastYear =>
      'compared with the same period last year';

  @override
  String get artifactComparedTerritory => 'compared with another territory';

  @override
  String get artifactByDay => 'By day';

  @override
  String get artifactByWeek => 'By week';

  @override
  String artifactVersus(String label) {
    return 'vs $label';
  }

  @override
  String get artifactTitleRanking => 'Ranking';

  @override
  String get artifactTitleKeyFigures => 'Key figures';

  @override
  String get artifactTitleTrend => 'Trend';

  @override
  String get artifactTitleSalesFigures => 'Sales figures';

  @override
  String get artifactTitleStockFigures => 'Stock figures';

  @override
  String get artifactTitleVisibilityFigures => 'Visibility figures';

  @override
  String get artifactTitleCompetitionFigures => 'Competition figures';

  @override
  String get artifactTitleFigures => 'Figures';

  @override
  String get artifactToolSalesPerformance => 'Sales performance';

  @override
  String get artifactToolSkuMovement => 'SKU movement';

  @override
  String get artifactToolStockLevels => 'Stock levels';

  @override
  String get artifactToolShareOfShelf => 'Share of shelf';

  @override
  String get artifactToolVisibility => 'Visibility compliance';

  @override
  String get artifactToolCompetitor => 'Competitor activity';

  @override
  String get artifactToolVisits => 'Visits';

  @override
  String get artifactToolFlaggedVisits => 'Flagged visits';

  @override
  String get artifactToolAgentScorecard => 'Agent scorecard';

  @override
  String get artifactToolTrend => 'Trend';
}
