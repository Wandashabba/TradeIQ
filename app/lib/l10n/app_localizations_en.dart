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
  String get visitPinReportedHeld =>
      'Reported on this phone. It has not been sent anywhere yet — there is nowhere to send it.';

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
  String get meTitle => 'Me';

  @override
  String get meEarnedHeading => 'What I\'ve earned';

  @override
  String get meVisitsHeading => 'My visits';

  @override
  String get meLedgerHeading => 'How you earned it';

  @override
  String get mePointsEyebrow => 'POINTS THIS MONTH';

  @override
  String get meRankEyebrow => 'RANK';

  @override
  String get meLoadErrorDetail =>
      'Your work is safe on this phone. This part comes from the server and fills in when it answers.';

  @override
  String get meNotRanked =>
      'Not ranked yet — too few agents have points this month.';

  @override
  String get meNoPointsYet =>
      'No points yet this month. Points arrive when a visit is submitted or a task is closed.';

  @override
  String get meNoScheme => 'No reward is running this month.';

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
  String get meLedgerEmpty => 'Nothing has earned points yet this month.';

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
  String get meContestsDetail => 'See where you stand';
}
