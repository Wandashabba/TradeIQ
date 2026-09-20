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
  String get pickerSelected => 'Selected';

  @override
  String get outletsPinReported => 'Pin reported';

  @override
  String outletsPinReportStood(String agent, String distance) {
    return '$agent stood $distance away';
  }

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
  String get salesLevelZeroTarget =>
      'Every target at this level is 0 units, so there is nothing to attain.';

  @override
  String get salesLevelAttainmentUnknown =>
      'The share of target was not worked out for this level.';

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
  String get salesZeroTarget => 'Target of 0 units';

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
}
