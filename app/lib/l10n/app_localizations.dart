import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_af.dart';
import 'app_localizations_en.dart';

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
    Locale('af'),
    Locale('en'),
  ];

  /// Tooltip on the agent app bar's language menu button.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageMenuTooltip;

  /// Language menu option: follow the device language.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// Language menu option. Always shown as the language's own name.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Language menu option. Always shown as the language's own name.
  ///
  /// In en, this message translates to:
  /// **'Afrikaans'**
  String get languageAfrikaans;

  /// Tooltip on the agent app bar's back button.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get agentBackTooltip;

  /// Tooltip on the agent app bar's light/dark toggle.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get agentThemeTooltip;

  /// Tooltip on the agent app bar's log-out button.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get agentLogOutTooltip;

  /// Relative time for something under a minute old. Lower case: it is embedded in sentences such as 'Last sent just now'.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get agoJustNow;

  /// Relative time, under an hour.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min ago'**
  String agoMinutes(int minutes);

  /// Relative time, under a day.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String agoHours(int hours);

  /// Relative time, a day or more.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String agoDays(int days);

  /// Sync chip while uploading.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Sending 1 capture…} other{Sending {count} captures…}}'**
  String syncSendingTitle(int count);

  /// Sync chip subtitle while uploading.
  ///
  /// In en, this message translates to:
  /// **'Keep going — you don’t have to wait'**
  String get syncSendingSubtitle;

  /// Sync chip when captures failed and need the agent.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item needs your attention} other{{count} items need your attention}}'**
  String syncAttentionTitle(int count);

  /// No description provided for @syncAttentionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'They will not send on their own — tap to see'**
  String get syncAttentionSubtitle;

  /// Sync chip when work is queued offline.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 capture held on this phone} other{{count} captures held on this phone}}'**
  String syncHeldTitle(int count);

  /// No description provided for @syncHeldSubtitle.
  ///
  /// In en, this message translates to:
  /// **'They will send themselves · nothing is lost'**
  String get syncHeldSubtitle;

  /// No description provided for @syncAllSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Everything is sent'**
  String get syncAllSentTitle;

  /// No description provided for @syncNothingWaiting.
  ///
  /// In en, this message translates to:
  /// **'Nothing waiting'**
  String get syncNothingWaiting;

  /// 'ago' is a relative time from agoJustNow/agoMinutes/agoHours/agoDays.
  ///
  /// In en, this message translates to:
  /// **'Last sent {ago}'**
  String syncLastSent(String ago);

  /// Screen-reader label on a count stepper's minus key.
  ///
  /// In en, this message translates to:
  /// **'One fewer'**
  String get kitStepperFewer;

  /// Screen-reader label on a count stepper's plus key.
  ///
  /// In en, this message translates to:
  /// **'One more'**
  String get kitStepperMore;

  /// Tooltip on the guided photo screen's close button.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get captureCancelTooltip;

  /// Status chip beside a photo capture error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get captureErrorChip;

  /// Shown when the camera/gallery fails. 'error' is the technical error text.
  ///
  /// In en, this message translates to:
  /// **'Could not capture a photo: {error}'**
  String captureError(String error);

  /// Guided photo screen: button that opens the camera.
  ///
  /// In en, this message translates to:
  /// **'Open camera'**
  String get captureButton;

  /// Guided photo screen: button that opens the photo gallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get captureGalleryButton;

  /// Default framing hint on the guided photo screen. 'label' is the photo field's label, already lower-cased.
  ///
  /// In en, this message translates to:
  /// **'Frame the {label} inside the guides, edge to edge.'**
  String photoFieldDefaultHint(String label);

  /// Tile that opens the guided photo screen.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get photoFieldAdd;

  /// Status chip beside a captured photo preview.
  ///
  /// In en, this message translates to:
  /// **'Captured'**
  String get photoFieldCaptured;

  /// Button to re-take a captured photo.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get photoFieldRetake;

  /// Sign-in error on a 401 (wrong email or password).
  ///
  /// In en, this message translates to:
  /// **'Invalid credentials'**
  String get loginInvalidCredentials;

  /// Tooltip on the sign-in screen's back button (to the splash).
  ///
  /// In en, this message translates to:
  /// **'Back to welcome'**
  String get loginBackTooltip;

  /// Small uppercase kicker above the sign-in title.
  ///
  /// In en, this message translates to:
  /// **'WELCOME BACK'**
  String get loginKicker;

  /// Sign-in screen title and submit button.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginSignIn;

  /// Sign-in screen subtitle.
  ///
  /// In en, this message translates to:
  /// **'Use your TradeIQ work account.'**
  String get loginSubtitle;

  /// Sign-in email field label.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get loginEmailLabel;

  /// Sign-in email field placeholder.
  ///
  /// In en, this message translates to:
  /// **'you@company.com'**
  String get loginEmailHint;

  /// Validation message when the email is empty.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get loginEmailRequired;

  /// Sign-in password field label.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPasswordLabel;

  /// Sign-in password field placeholder.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get loginPasswordHint;

  /// Tooltip on the password visibility toggle.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get loginShowPassword;

  /// Tooltip on the password visibility toggle.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get loginHidePassword;

  /// Validation message when the password is empty.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get loginPasswordRequired;

  /// Sign-in 'keep me signed in' checkbox label.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get loginRememberMe;

  /// Sign-in forgot-password link.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get loginForgotPassword;

  /// Title of the agent’s day screen.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayTitle;

  /// No description provided for @todayLoadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load your route'**
  String get todayLoadErrorTitle;

  /// No description provided for @todayLoadErrorDetail.
  ///
  /// In en, this message translates to:
  /// **'You can still start a visit yourself.'**
  String get todayLoadErrorDetail;

  /// No description provided for @todayNoRouteTitle.
  ///
  /// In en, this message translates to:
  /// **'No route planned for today'**
  String get todayNoRouteTitle;

  /// Shown when no beat plan exists for today.
  ///
  /// In en, this message translates to:
  /// **'No beat plan for today. You can still pick a store yourself.'**
  String get todayNoPlanDetail;

  /// No description provided for @todayEmptyPlanDetail.
  ///
  /// In en, this message translates to:
  /// **'Today’s beat plan has no stops on it yet.'**
  String get todayEmptyPlanDetail;

  /// Section heading above the stops; shown upper-cased.
  ///
  /// In en, this message translates to:
  /// **'Your route'**
  String get todayYourRouteHeading;

  /// No description provided for @todayVisitAnotherStore.
  ///
  /// In en, this message translates to:
  /// **'Visit a store not on my route'**
  String get todayVisitAnotherStore;

  /// Follows the big done-count number, e.g. "3" + " of 8 stores". Keep the leading space.
  ///
  /// In en, this message translates to:
  /// **'{total, plural, =1{ of 1 store} other{ of {total} stores}}'**
  String todayStoresOfTotal(int total);

  /// Pill: stores still to visit today.
  ///
  /// In en, this message translates to:
  /// **'{count} left'**
  String todayStoresLeft(int count);

  /// Pill when every stop is visited.
  ///
  /// In en, this message translates to:
  /// **'Route done'**
  String get todayRouteDone;

  /// Location permission off / no GPS fix. Not an error.
  ///
  /// In en, this message translates to:
  /// **'Distances are off — this phone will not say where it is.'**
  String get todayDistancesOff;

  /// Small upper-case tag on a visited stop.
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get todayStopDoneTag;

  /// Small upper-case tag on the next stop.
  ///
  /// In en, this message translates to:
  /// **'NEXT'**
  String get todayStopNextTag;

  /// No description provided for @todayPickStore.
  ///
  /// In en, this message translates to:
  /// **'Pick a store to visit'**
  String get todayPickStore;

  /// Heading above the next-stop card; shown upper-cased.
  ///
  /// In en, this message translates to:
  /// **'Next up'**
  String get todayNextUpHeading;

  /// Heading above remaining stops; shown upper-cased.
  ///
  /// In en, this message translates to:
  /// **'The rest of the day'**
  String get todayRestOfDayHeading;

  /// Tiny label under "done/total" in the progress ring; shown upper-cased.
  ///
  /// In en, this message translates to:
  /// **'Stores'**
  String get todayStoresRingLabel;

  /// Sequence of the stop on the route, zero-padded, e.g. "Stop 03".
  ///
  /// In en, this message translates to:
  /// **'Stop {number}'**
  String todayStopNumber(String number);

  /// No description provided for @todayCheckInHere.
  ///
  /// In en, this message translates to:
  /// **'Check in here'**
  String get todayCheckInHere;

  /// No description provided for @pickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Select an Outlet'**
  String get pickerTitle;

  /// No description provided for @pickerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap a store to start a visit'**
  String get pickerSubtitle;

  /// No description provided for @pickerAddStore.
  ///
  /// In en, this message translates to:
  /// **'Add a store'**
  String get pickerAddStore;

  /// Scope segment: only stores in the agent’s territories.
  ///
  /// In en, this message translates to:
  /// **'My territories'**
  String get pickerScopeMine;

  /// Scope segment: every store for the client.
  ///
  /// In en, this message translates to:
  /// **'All stores'**
  String get pickerScopeAll;

  /// Mentions the pickerScopeAll segment label by name.
  ///
  /// In en, this message translates to:
  /// **'{count} in your territories · tap All stores to see every shop'**
  String pickerScopeMineSummary(int count);

  /// No description provided for @pickerScopeAllSummary.
  ///
  /// In en, this message translates to:
  /// **'All {count} stores across this client'**
  String pickerScopeAllSummary(int count);

  /// No description provided for @pickerLoadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load your stores'**
  String get pickerLoadErrorTitle;

  /// No description provided for @pickerRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get pickerRetry;

  /// No description provided for @myWorkTitle.
  ///
  /// In en, this message translates to:
  /// **'My work'**
  String get myWorkTitle;

  /// No description provided for @myWorkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Everything you’ve captured'**
  String get myWorkSubtitle;

  /// No description provided for @myWorkSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Try sending now'**
  String get myWorkSyncNow;

  /// No description provided for @myWorkLoadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not read your work'**
  String get myWorkLoadErrorTitle;

  /// Group heading for failed captures; shown upper-cased.
  ///
  /// In en, this message translates to:
  /// **'Needs you'**
  String get myWorkNeedsYouHeading;

  /// Group heading; shown upper-cased.
  ///
  /// In en, this message translates to:
  /// **'Waiting to send'**
  String get myWorkWaitingHeading;

  /// Group heading; shown upper-cased.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get myWorkSentHeading;

  /// No description provided for @myWorkEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing captured yet'**
  String get myWorkEmpty;

  /// No description provided for @myWorkFooter.
  ///
  /// In en, this message translates to:
  /// **'Captures send themselves when you have signal. Nothing is lost.'**
  String get myWorkFooter;

  /// No description provided for @myWorkSendingTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Sending 1 item…} other{Sending {count} items…}}'**
  String myWorkSendingTitle(int count);

  /// No description provided for @myWorkSendingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You don’t have to wait for this'**
  String get myWorkSendingSubtitle;

  /// No description provided for @myWorkFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item will not send} other{{count} items will not send}}'**
  String myWorkFailedTitle(int count);

  /// No description provided for @myWorkFailedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Everything else is safe'**
  String get myWorkFailedSubtitle;

  /// No description provided for @myWorkHeldTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item held on this phone} other{{count} items held on this phone}}'**
  String myWorkHeldTitle(int count);

  /// No description provided for @myWorkHeldSubtitle.
  ///
  /// In en, this message translates to:
  /// **'They will send themselves'**
  String get myWorkHeldSubtitle;

  /// Row state word; shown upper-cased.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get myWorkStateSent;

  /// Row state word; shown upper-cased.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get myWorkStateFailed;

  /// Row state word; shown upper-cased.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get myWorkStateWaiting;

  /// Why a queued capture has not sent: its visit (check-in) must reach the server first. Clears itself.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the visit to send first'**
  String get syncErrorWaitingForVisit;

  /// Why a queued capture has not sent: no signal.
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get syncErrorNoConnection;

  /// Why a queued capture has not sent: the session ended (401/403).
  ///
  /// In en, this message translates to:
  /// **'Signed out — sign in again'**
  String get syncErrorSignedOut;

  /// Why a queued capture has not sent: the server refuses its size (413).
  ///
  /// In en, this message translates to:
  /// **'Too large to send'**
  String get syncErrorTooLarge;

  /// Why a queued capture has not sent: a server error (5xx). Retried automatically.
  ///
  /// In en, this message translates to:
  /// **'Server problem — will retry'**
  String get syncErrorServerProblem;

  /// Why a queued capture has not sent: the server refused it. 'status' is the HTTP status code, e.g. 422.
  ///
  /// In en, this message translates to:
  /// **'Rejected by the server ({status})'**
  String syncErrorRejected(int status);

  /// Why a queued capture has not sent: any other failure.
  ///
  /// In en, this message translates to:
  /// **'Could not send'**
  String get syncErrorCouldNotSend;

  /// Your work row label for a queued visit check-in.
  ///
  /// In en, this message translates to:
  /// **'Check-in'**
  String get syncItemCheckIn;

  /// Your work row label for a queued visit submission.
  ///
  /// In en, this message translates to:
  /// **'Submitted visit'**
  String get syncItemSubmittedVisit;

  /// Your work row label for queued stock (S2) captures.
  ///
  /// In en, this message translates to:
  /// **'Stock count'**
  String get syncItemStockCount;

  /// Your work row label for queued visibility & display (S3/S4) captures.
  ///
  /// In en, this message translates to:
  /// **'Visibility & display'**
  String get syncItemVisibility;

  /// Your work row label for queued pricing (S5) captures.
  ///
  /// In en, this message translates to:
  /// **'Pricing'**
  String get syncItemPricing;

  /// Your work row label for queued competitive (S6) captures.
  ///
  /// In en, this message translates to:
  /// **'Competitive'**
  String get syncItemCompetitive;

  /// Your work row label for queued team capability (S7) captures.
  ///
  /// In en, this message translates to:
  /// **'Team capability'**
  String get syncItemCapability;

  /// Your work row label for queued risks (S8).
  ///
  /// In en, this message translates to:
  /// **'Risks'**
  String get syncItemRisks;

  /// Your work row label for a queued action-plan task (S9).
  ///
  /// In en, this message translates to:
  /// **'Action plan'**
  String get syncItemActionPlan;

  /// Your work row label for the queued scorecard (S10).
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get syncItemScore;

  /// Your work row label for a queued section photo.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get syncItemPhoto;

  /// Your work row label for a queued in-store order (#36).
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get syncItemOrder;

  /// App bar title while the outlet list loads before check-in.
  ///
  /// In en, this message translates to:
  /// **'Starting visit'**
  String get visitStartingTitle;

  /// App bar title on the visit screen when there is no outlet name to show.
  ///
  /// In en, this message translates to:
  /// **'Visit'**
  String get visitTitle;

  /// No description provided for @visitOutletLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load outlet: {error}'**
  String visitOutletLoadFailed(String error);

  /// No description provided for @visitOutletNotFound.
  ///
  /// In en, this message translates to:
  /// **'Outlet not found'**
  String get visitOutletNotFound;

  /// Shown on the visit hub and the submit gate when the visit's local data cannot be read.
  ///
  /// In en, this message translates to:
  /// **'Could not read this visit: {error}'**
  String visitReadFailed(String error);

  /// Visit hub subtitle: checked in less than a minute ago.
  ///
  /// In en, this message translates to:
  /// **'In store just now'**
  String get visitInStoreJustNow;

  /// Visit hub subtitle: how long the agent has been in the store, under an hour.
  ///
  /// In en, this message translates to:
  /// **'In store {minutes} min'**
  String visitInStoreMinutes(int minutes);

  /// Visit hub subtitle: how long the agent has been in the store, under a day.
  ///
  /// In en, this message translates to:
  /// **'In store {hours}h'**
  String visitInStoreHours(int hours);

  /// Visit hub subtitle: how long the agent has been in the store, a day or more.
  ///
  /// In en, this message translates to:
  /// **'In store {days}d'**
  String visitInStoreDays(int days);

  /// Heading above the list of audit sections on the visit hub.
  ///
  /// In en, this message translates to:
  /// **'The audit'**
  String get visitAuditHeading;

  /// No description provided for @visitAnyOrderHint.
  ///
  /// In en, this message translates to:
  /// **'Any order. Everything saves as you go, even with no signal.'**
  String get visitAnyOrderHint;

  /// Note above the disabled submit button. 'sections' is a list of section names joined with visitSectionsAnd.
  ///
  /// In en, this message translates to:
  /// **'Finish {sections} to submit'**
  String visitFinishToSubmit(String sections);

  /// Joins section names in a list: 'Stock & availability and Team capability'. Applied repeatedly for longer lists.
  ///
  /// In en, this message translates to:
  /// **'{first} and {second}'**
  String visitSectionsAnd(String first, String second);

  /// Button that submits the visit (hub and submit gate).
  ///
  /// In en, this message translates to:
  /// **'Submit visit'**
  String get visitSubmitButton;

  /// Subtitle on an open audit section.
  ///
  /// In en, this message translates to:
  /// **'Saves as you go'**
  String get visitSectionSavesAsYouGo;

  /// Bottom button on an open audit section; returns to the hub.
  ///
  /// In en, this message translates to:
  /// **'Done · back to visit'**
  String get visitSectionDoneBack;

  /// Follows a big animated count: '3 of 8 sections'. Note the leading space.
  ///
  /// In en, this message translates to:
  /// **' of {total} sections'**
  String visitProgressOfSections(int total);

  /// No description provided for @visitReadyToSubmit.
  ///
  /// In en, this message translates to:
  /// **'Ready to submit'**
  String get visitReadyToSubmit;

  /// Pill: number of required sections not yet done.
  ///
  /// In en, this message translates to:
  /// **'{count} still required'**
  String visitStillRequired(int count);

  /// Small caption next to 'n/8' on the glass hub.
  ///
  /// In en, this message translates to:
  /// **'Sections captured'**
  String get visitSectionsCaptured;

  /// Detail line under the Score section.
  ///
  /// In en, this message translates to:
  /// **'Calculated when you submit'**
  String get visitScoreCalculatedOnSubmit;

  /// No description provided for @visitSectionNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get visitSectionNotStarted;

  /// No description provided for @visitSectionOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get visitSectionOptional;

  /// Small uppercase badge on a required section that is not done.
  ///
  /// In en, this message translates to:
  /// **'REQUIRED TO SUBMIT'**
  String get visitRequiredToSubmitBadge;

  /// Screen-reader label for the short REQ pill.
  ///
  /// In en, this message translates to:
  /// **'Required to submit'**
  String get visitRequiredToSubmit;

  /// Very short uppercase pill (tiny monospace) on a required section tile. Keep to 3-5 letters.
  ///
  /// In en, this message translates to:
  /// **'REQ'**
  String get visitRequiredShort;

  /// Audit section S1 name.
  ///
  /// In en, this message translates to:
  /// **'Outlet info'**
  String get visitSectionOutletInfo;

  /// Audit section S2 name.
  ///
  /// In en, this message translates to:
  /// **'Stock & availability'**
  String get visitSectionStock;

  /// Audit sections S3/S4 name.
  ///
  /// In en, this message translates to:
  /// **'Visibility & display'**
  String get visitSectionVisibility;

  /// Audit section S5 name.
  ///
  /// In en, this message translates to:
  /// **'Pricing & promotions'**
  String get visitSectionPricing;

  /// Audit section S6 name.
  ///
  /// In en, this message translates to:
  /// **'Competitive'**
  String get visitSectionCompetitive;

  /// Audit section S7 name.
  ///
  /// In en, this message translates to:
  /// **'Team capability'**
  String get visitSectionCapability;

  /// Audit section S8 name.
  ///
  /// In en, this message translates to:
  /// **'Risks'**
  String get visitSectionRisks;

  /// Audit section S9 name.
  ///
  /// In en, this message translates to:
  /// **'Action plan'**
  String get visitSectionActionPlan;

  /// Audit section S10 name.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get visitSectionScore;

  /// Title while waiting for a GPS fix to check in.
  ///
  /// In en, this message translates to:
  /// **'Finding you…'**
  String get visitCheckInFinding;

  /// No description provided for @visitCheckInWithinHint.
  ///
  /// In en, this message translates to:
  /// **'Check in within 50 m of the store. This proves the visit happened.'**
  String get visitCheckInWithinHint;

  /// No description provided for @visitRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get visitRetry;

  /// No description provided for @visitBackToRoute.
  ///
  /// In en, this message translates to:
  /// **'Back to route'**
  String get visitBackToRoute;

  /// No description provided for @visitTooFarTitle.
  ///
  /// In en, this message translates to:
  /// **'You’re too far away'**
  String get visitTooFarTitle;

  /// No description provided for @visitTooFarBody.
  ///
  /// In en, this message translates to:
  /// **'Move closer and try again. Nothing is lost — the visit hasn’t started.'**
  String get visitTooFarBody;

  /// Measured distance from the store against the 50 m check-in fence.
  ///
  /// In en, this message translates to:
  /// **'{meters} m away · need 50 m or closer'**
  String visitTooFarDistance(int meters);

  /// No description provided for @visitTooFarFraudNote.
  ///
  /// In en, this message translates to:
  /// **'This attempt is recorded. Retrying from far away is itself a fraud signal — walk closer instead.'**
  String get visitTooFarFraudNote;

  /// No description provided for @visitNoLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Can’t find your location'**
  String get visitNoLocationTitle;

  /// No description provided for @visitCheckInFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not start the visit'**
  String get visitCheckInFailedTitle;

  /// No description provided for @visitCheckInFailedNothingLost.
  ///
  /// In en, this message translates to:
  /// **'Nothing is lost — the visit hadn’t started.'**
  String get visitCheckInFailedNothingLost;

  /// Submit gate subtitle: outlet name and minutes since check-in.
  ///
  /// In en, this message translates to:
  /// **'{outlet} · {minutes} min in store'**
  String submitSubtitleInStore(String outlet, int minutes);

  /// No description provided for @submitOfflineNote.
  ///
  /// In en, this message translates to:
  /// **'No signal? Submitting still works — it saves on the phone and sends itself.'**
  String get submitOfflineNote;

  /// No description provided for @submitIntro.
  ///
  /// In en, this message translates to:
  /// **'Check this before it goes to your manager — you cannot change it after.'**
  String get submitIntro;

  /// Heading above the list of tasks the submission will raise for the manager.
  ///
  /// In en, this message translates to:
  /// **'This will raise'**
  String get submitWillRaiseHeading;

  /// Note under the tasks the visit will raise. count is at least 1.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{You are telling the manager one thing is wrong in this store. It comes from what you captured — nothing is added. If it is already open, it is not raised twice.} other{You are telling the manager {count} things are wrong in this store. They come from what you captured — nothing is added. Anything already open is not raised twice.}}'**
  String submitAccusation(int count);

  /// No description provided for @submitSectionsComplete.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} sections complete'**
  String submitSectionsComplete(int done, int total);

  /// Line under a task the visit will raise. 'priority' comes from submitPriority.
  ///
  /// In en, this message translates to:
  /// **'Task for the manager · {priority}'**
  String submitTaskForManager(String priority);

  /// A task priority word, lower case. The select values are the server's priority codes.
  ///
  /// In en, this message translates to:
  /// **'{priority, select, critical{critical} high{high} normal{normal} low{low} other{{priority}}}'**
  String submitPriority(String priority);

  /// No description provided for @submitNothingToRaise.
  ///
  /// In en, this message translates to:
  /// **'Nothing to raise. No stockouts, no risks — this store is in good shape.'**
  String get submitNothingToRaise;

  /// Second line on the submit gate's captured block when sections are can't-confirm.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 section could not be confirmed — the manager is told} other{{count} sections could not be confirmed — the manager is told}}'**
  String submitNotConfirmedLine(int count);

  /// Title of a can't-confirm row on the submit gate.
  ///
  /// In en, this message translates to:
  /// **'{section} could not be confirmed'**
  String submitCantConfirmTask(String section);

  /// Meta line under a can't-confirm row on the submit gate.
  ///
  /// In en, this message translates to:
  /// **'The manager is told · not confirmed'**
  String get submitCantConfirmTaskLine;

  /// Screen-reader line for an urgent raised task.
  ///
  /// In en, this message translates to:
  /// **'Urgent. {title}. {line}'**
  String submitTaskSemanticsUrgent(String title, String line);

  /// Screen-reader line for a routine raised task.
  ///
  /// In en, this message translates to:
  /// **'Routine. {title}. {line}'**
  String submitTaskSemanticsRoutine(String title, String line);

  /// Screen-reader line for a can't-confirm row on the submit gate.
  ///
  /// In en, this message translates to:
  /// **'Not confirmed. {section}. {reason}'**
  String submitCantConfirmSemantics(String section, String reason);

  /// Screen-reader label for the submit gate's primary button.
  ///
  /// In en, this message translates to:
  /// **'Submit this visit to your manager'**
  String get submitPrimarySemantics;

  /// Screen-reader line for the submit gate's captured block.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} sections complete. {line}'**
  String submitCapturedSemantics(int done, int total, String line);

  /// Headline of the clean-store block on the submit gate.
  ///
  /// In en, this message translates to:
  /// **'Nothing to raise'**
  String get submitNothingToRaiseHeadline;

  /// Ghost action under the submit gate's primary.
  ///
  /// In en, this message translates to:
  /// **'Go back and change something'**
  String get submitGateBack;

  /// App bar title on the screen shown after a visit is submitted.
  ///
  /// In en, this message translates to:
  /// **'Visit submitted'**
  String get outcomeTitle;

  /// Bottom button: go back to Today for the next store.
  ///
  /// In en, this message translates to:
  /// **'Next store'**
  String get outcomeNextStore;

  /// Shown while the visit is being sent and scored.
  ///
  /// In en, this message translates to:
  /// **'Sending your visit…'**
  String get outcomeSending;

  /// Heading when the visit is submitted but still queued on the phone.
  ///
  /// In en, this message translates to:
  /// **'Your visit is safe on this phone'**
  String get outcomeHeldTitle;

  /// Body when the visit is held on the phone because reading the score from the server failed.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server. It sends itself when signal returns — you can close the app.'**
  String get outcomeHeldBodyUnreachable;

  /// Body when the visit is held on the phone because there is no signal.
  ///
  /// In en, this message translates to:
  /// **'No signal. It sends itself when signal returns — you can close the app.'**
  String get outcomeHeldBodyNoSignal;

  /// Banner title: the score is only worked out once the visit is sent.
  ///
  /// In en, this message translates to:
  /// **'Scored when it sends'**
  String get outcomeScoredWhenSends;

  /// Banner subtitle under outcomeScoredWhenSends.
  ///
  /// In en, this message translates to:
  /// **'Worked out on the server, not on the phone'**
  String get outcomeScoredOnServer;

  /// Explains why no score is shown while the visit is still on the phone.
  ///
  /// In en, this message translates to:
  /// **'Your real score — the one your manager sees — appears once this reaches the server.'**
  String get outcomeNoGuess;

  /// The scorecard's rating band spelled out beside its non-colour mark, on every surface that shows a band. 'band' is the wire value green/amber/red, which is unchanged — only the display name differs, because the design system reserves amber for the brand and cannot name a severity after it.
  ///
  /// In en, this message translates to:
  /// **'{band, select, green{Healthy} amber{Watch} other{Gap}}'**
  String ratingBand(String band);

  /// Score is unchanged since the agent's last visit to this store. 'previous' is that visit's score.
  ///
  /// In en, this message translates to:
  /// **'Same as your last visit here ({previous}).'**
  String outcomeDeltaSame(int previous);

  /// Bold first half of the score change line; followed by outcomeDeltaFromLast in a lighter style.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Up 1 point} other{Up {count} points}}'**
  String outcomeDeltaUp(int count);

  /// Bold first half of the score change line; followed by outcomeDeltaFromLast in a lighter style.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Down 1 point} other{Down {count} points}}'**
  String outcomeDeltaDown(int count);

  /// Second half of the score change line, after outcomeDeltaUp/outcomeDeltaDown (a space is added in code). 'previous' is the last visit's score.
  ///
  /// In en, this message translates to:
  /// **'from your last visit here ({previous}).'**
  String outcomeDeltaFromLast(int previous);

  /// Heading above the per-dimension score list (shown upper-cased).
  ///
  /// In en, this message translates to:
  /// **'How it was scored'**
  String get outcomeHowScored;

  /// Kicker above the big score figure (shown upper-cased).
  ///
  /// In en, this message translates to:
  /// **'Perfect-store score'**
  String get outcomePerfectStoreScore;

  /// Scorecard dimension name.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get outcomeDimensionAvailability;

  /// Scorecard dimension name.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get outcomeDimensionVisibility;

  /// Scorecard dimension name.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get outcomeDimensionDisplay;

  /// Scorecard dimension name.
  ///
  /// In en, this message translates to:
  /// **'Pricing'**
  String get outcomeDimensionPricing;

  /// Scorecard dimension name (the 'competitive' dimension).
  ///
  /// In en, this message translates to:
  /// **'Share of shelf'**
  String get outcomeDimensionCompetitive;

  /// Scorecard dimension name (the 'salesCapability' dimension).
  ///
  /// In en, this message translates to:
  /// **'Team capability'**
  String get outcomeDimensionSalesCapability;

  /// Why the share-of-shelf dimension has no score.
  ///
  /// In en, this message translates to:
  /// **'No competitor on shelf — not counted against you.'**
  String get outcomeUnmeasurableCompetitive;

  /// Why the team-capability dimension has no score.
  ///
  /// In en, this message translates to:
  /// **'No staff on shift — not counted against you.'**
  String get outcomeUnmeasurableSalesCapability;

  /// Card title on the outlet info section.
  ///
  /// In en, this message translates to:
  /// **'Outlet check-in'**
  String get s1Title;

  /// Explains the values below come from check-in, not agent input.
  ///
  /// In en, this message translates to:
  /// **'Confirmed at check-in'**
  String get s1ConfirmedAtCheckin;

  /// Label for the check-in timestamp.
  ///
  /// In en, this message translates to:
  /// **'Checked in'**
  String get s1CheckedIn;

  /// Shown instead of a timestamp when no check-in time was recorded.
  ///
  /// In en, this message translates to:
  /// **'Not recorded'**
  String get s1NotRecorded;

  /// Label for the geofence check result.
  ///
  /// In en, this message translates to:
  /// **'Geofence'**
  String get s1Geofence;

  /// Geofence check result.
  ///
  /// In en, this message translates to:
  /// **'Passed'**
  String get s1Passed;

  /// Shown when the SKU list fails to load. 'error' is the technical error text.
  ///
  /// In en, this message translates to:
  /// **'Failed to load SKUs: {error}'**
  String s2LoadFailed(String error);

  /// No description provided for @s2NoSkus.
  ///
  /// In en, this message translates to:
  /// **'No SKUs configured for this client.'**
  String get s2NoSkus;

  /// Read-only sales context under a SKU. 'velocity' is average units per day, one decimal.
  ///
  /// In en, this message translates to:
  /// **'Selling ~{velocity}/day'**
  String s2ContextSelling(String velocity);

  /// Read-only sales context under a SKU. 'velocity' is average units per day; 'days' is days out of stock ('d' = days).
  ///
  /// In en, this message translates to:
  /// **'Selling ~{velocity}/day · out of stock {days}d'**
  String s2ContextSellingOutOfStock(String velocity, int days);

  /// Read-only sales context under a SKU with no velocity yet.
  ///
  /// In en, this message translates to:
  /// **'No sales history yet'**
  String get s2ContextNoHistory;

  /// Read-only sales context under a SKU. 'days' is days out of stock ('d' = days).
  ///
  /// In en, this message translates to:
  /// **'No sales history yet · out of stock {days}d'**
  String s2ContextNoHistoryOutOfStock(int days);

  /// Recommended retail price beside a SKU name. 'price' is formatted with two decimals.
  ///
  /// In en, this message translates to:
  /// **'RRP {price}'**
  String s2Rrp(String price);

  /// Warning when a SKU is counted as zero.
  ///
  /// In en, this message translates to:
  /// **'Out of stock — this raises a task for the manager'**
  String get s2OutOfStockRaisesTask;

  /// Why an out-of-stock matters.
  ///
  /// In en, this message translates to:
  /// **'70% of shoppers switch brand when the product is missing.'**
  String get s2ShoppersSwitch;

  /// Button that saves the stock section.
  ///
  /// In en, this message translates to:
  /// **'Save stock'**
  String get s2SaveStock;

  /// Confirmation after saving stock.
  ///
  /// In en, this message translates to:
  /// **'Stock saved — queued for sync'**
  String get s2StockSaved;

  /// Label of the field for typing a SKU's shelf count.
  ///
  /// In en, this message translates to:
  /// **'Units on shelf'**
  String get s2UnitsOnShelf;

  /// Count dialog: cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get s2Cancel;

  /// Count dialog: apply the typed count.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get s2Set;

  /// No description provided for @s10ComputeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not compute the scorecard. Try refreshing.'**
  String get s10ComputeFailed;

  /// Card title above the per-dimension scores.
  ///
  /// In en, this message translates to:
  /// **'Dimension scores'**
  String get s10DimensionScores;

  /// Label above the weighted total score.
  ///
  /// In en, this message translates to:
  /// **'Weighted total'**
  String get s10WeightedTotal;

  /// Button that queues the scorecard for the server.
  ///
  /// In en, this message translates to:
  /// **'Finalize scorecard'**
  String get s10Finalize;

  /// Button that recomputes the on-device scorecard.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get s10Refresh;

  /// Confirmation after finalizing the scorecard.
  ///
  /// In en, this message translates to:
  /// **'Scorecard queued for sync'**
  String get s10Queued;

  /// On-device scorecard dimension name.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get s10DimensionAvailability;

  /// On-device scorecard dimension name.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get s10DimensionVisibility;

  /// On-device scorecard dimension name.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get s10DimensionDisplay;

  /// On-device scorecard dimension name.
  ///
  /// In en, this message translates to:
  /// **'Pricing'**
  String get s10DimensionPricing;

  /// On-device scorecard dimension name.
  ///
  /// In en, this message translates to:
  /// **'Competitive'**
  String get s10DimensionCompetitive;

  /// On-device scorecard dimension name.
  ///
  /// In en, this message translates to:
  /// **'Sales Capability'**
  String get s10DimensionSalesCapability;

  /// S3–S4 branding checklist option.
  ///
  /// In en, this message translates to:
  /// **'Poster'**
  String get s34BrandingPoster;

  /// S3–S4 branding checklist option.
  ///
  /// In en, this message translates to:
  /// **'Shelf strip'**
  String get s34BrandingShelfStrip;

  /// S3–S4 branding checklist option (a POS wobbler sign).
  ///
  /// In en, this message translates to:
  /// **'Wobbler'**
  String get s34BrandingWobbler;

  /// S3–S4 label above the branding checklist.
  ///
  /// In en, this message translates to:
  /// **'Branding elements present'**
  String get s34BrandingLabel;

  /// S3–S4 field label.
  ///
  /// In en, this message translates to:
  /// **'Planogram compliance %'**
  String get s34PlanogramLabel;

  /// S3–S4 field label.
  ///
  /// In en, this message translates to:
  /// **'Facings count'**
  String get s34FacingsLabel;

  /// S3–S4 field label.
  ///
  /// In en, this message translates to:
  /// **'Cleanliness score'**
  String get s34CleanlinessLabel;

  /// S3–S4 toggle label.
  ///
  /// In en, this message translates to:
  /// **'High-traffic location'**
  String get s34HighTrafficLabel;

  /// S3–S4 photo capture label.
  ///
  /// In en, this message translates to:
  /// **'Shelf photo'**
  String get s34PhotoLabel;

  /// S3–S4 photo capture helper text.
  ///
  /// In en, this message translates to:
  /// **'Optional. Evidence for this section, and training data for automatic planogram scoring.'**
  String get s34PhotoHelper;

  /// S3–S4 save button.
  ///
  /// In en, this message translates to:
  /// **'Save visibility'**
  String get s34SaveButton;

  /// S3–S4 confirmation after saving.
  ///
  /// In en, this message translates to:
  /// **'Visibility saved — queued for sync'**
  String get s34Saved;

  /// S5 error when the SKU list fails to load.
  ///
  /// In en, this message translates to:
  /// **'Failed to load SKUs: {error}'**
  String s5LoadError(String error);

  /// S5 empty state.
  ///
  /// In en, this message translates to:
  /// **'No SKUs configured for this client.'**
  String get s5NoSkus;

  /// S5 per-SKU field label.
  ///
  /// In en, this message translates to:
  /// **'Actual price'**
  String get s5ActualPriceLabel;

  /// S5 per-SKU toggle label.
  ///
  /// In en, this message translates to:
  /// **'Promotion active'**
  String get s5PromoActiveLabel;

  /// S5 per-SKU field label.
  ///
  /// In en, this message translates to:
  /// **'Comms rating (1-5)'**
  String get s5CommsRatingLabel;

  /// S5 photo capture label.
  ///
  /// In en, this message translates to:
  /// **'Shelf-price photo'**
  String get s5PhotoLabel;

  /// S5 photo capture helper text.
  ///
  /// In en, this message translates to:
  /// **'Optional. Evidence for the prices you typed, and training data for automatic price reading.'**
  String get s5PhotoHelper;

  /// S5 save button.
  ///
  /// In en, this message translates to:
  /// **'Save pricing'**
  String get s5SaveButton;

  /// S5 confirmation after saving.
  ///
  /// In en, this message translates to:
  /// **'Pricing saved — queued for sync'**
  String get s5Saved;

  /// S6 card title; number is the 1-based row number.
  ///
  /// In en, this message translates to:
  /// **'Competitor {number}'**
  String s6CompetitorTitle(int number);

  /// S6 field label.
  ///
  /// In en, this message translates to:
  /// **'Competitor SKU'**
  String get s6SkuLabel;

  /// S6 field hint.
  ///
  /// In en, this message translates to:
  /// **'What the rival is selling'**
  String get s6SkuHint;

  /// S6 field label.
  ///
  /// In en, this message translates to:
  /// **'Competitor price'**
  String get s6PriceLabel;

  /// S6 field label (point-of-sale materials).
  ///
  /// In en, this message translates to:
  /// **'POSM type'**
  String get s6PosmLabel;

  /// S6 field hint.
  ///
  /// In en, this message translates to:
  /// **'Poster, wobbler, gondola…'**
  String get s6PosmHint;

  /// S6 field label.
  ///
  /// In en, this message translates to:
  /// **'Facings on shelf'**
  String get s6FacingsLabel;

  /// S6 field help text.
  ///
  /// In en, this message translates to:
  /// **'How much shelf this competitor holds'**
  String get s6FacingsHelp;

  /// S6 toggle label.
  ///
  /// In en, this message translates to:
  /// **'Promoter present'**
  String get s6PromoterLabel;

  /// S6 add-row button.
  ///
  /// In en, this message translates to:
  /// **'Add competitor'**
  String get s6AddButton;

  /// S6 save button.
  ///
  /// In en, this message translates to:
  /// **'Save competitive'**
  String get s6SaveButton;

  /// S6 confirmation after saving.
  ///
  /// In en, this message translates to:
  /// **'Competitive intel saved — queued for sync'**
  String get s6Saved;

  /// S7 training checklist option.
  ///
  /// In en, this message translates to:
  /// **'Product knowledge'**
  String get s7TrainingProductKnowledge;

  /// S7 training checklist option.
  ///
  /// In en, this message translates to:
  /// **'Merchandising'**
  String get s7TrainingMerchandising;

  /// S7 training checklist option.
  ///
  /// In en, this message translates to:
  /// **'POS systems'**
  String get s7TrainingPosSystems;

  /// S7 field label.
  ///
  /// In en, this message translates to:
  /// **'Staff headcount confirmed'**
  String get s7HeadcountLabel;

  /// S7 field hint.
  ///
  /// In en, this message translates to:
  /// **'Reps on the floor'**
  String get s7HeadcountHint;

  /// S7 label above the training checklist.
  ///
  /// In en, this message translates to:
  /// **'Rep training completed'**
  String get s7TrainingLabel;

  /// S7 field label.
  ///
  /// In en, this message translates to:
  /// **'Quiz score (0-100)'**
  String get s7QuizLabel;

  /// S7 save button.
  ///
  /// In en, this message translates to:
  /// **'Save capability'**
  String get s7SaveButton;

  /// S7 confirmation after saving.
  ///
  /// In en, this message translates to:
  /// **'Capability saved — queued for sync'**
  String get s7Saved;

  /// S8 severity choice.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get s8SeverityCritical;

  /// S8 severity choice.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get s8SeverityHigh;

  /// S8 severity choice.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get s8SeverityNormal;

  /// S8 card title; number is the 1-based row number.
  ///
  /// In en, this message translates to:
  /// **'Risk {number}'**
  String s8RiskTitle(int number);

  /// S8 field label.
  ///
  /// In en, this message translates to:
  /// **'Flag type'**
  String get s8FlagTypeLabel;

  /// S8 field hint.
  ///
  /// In en, this message translates to:
  /// **'What was flagged'**
  String get s8FlagTypeHint;

  /// S8 label above the severity choices.
  ///
  /// In en, this message translates to:
  /// **'Severity'**
  String get s8SeverityLabel;

  /// S8 field label.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get s8NoteLabel;

  /// S8 field hint.
  ///
  /// In en, this message translates to:
  /// **'Optional detail'**
  String get s8NoteHint;

  /// S8 add-row button.
  ///
  /// In en, this message translates to:
  /// **'Flag a risk'**
  String get s8AddButton;

  /// S8 save button.
  ///
  /// In en, this message translates to:
  /// **'Save risks'**
  String get s8SaveButton;

  /// S8 confirmation after saving.
  ///
  /// In en, this message translates to:
  /// **'Risks saved — queued for sync; follow-up tasks will be auto-created'**
  String get s8Saved;

  /// S8 glass note on a critical or high risk card. severity is the wire value 'critical' or 'high'.
  ///
  /// In en, this message translates to:
  /// **'{severity, select, critical{Critical risk — saving it raises a follow-up task} other{High risk — saving it raises a follow-up task}}'**
  String s8SeverityNote(String severity);

  /// S9 task priority choice.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get s9PriorityCritical;

  /// S9 task priority choice.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get s9PriorityHigh;

  /// S9 task priority choice.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get s9PriorityNormal;

  /// S9 intro text.
  ///
  /// In en, this message translates to:
  /// **'Risks flagged in S8 auto-create tasks with an SLA. Add extra tasks below.'**
  String get s9Intro;

  /// S9 field label.
  ///
  /// In en, this message translates to:
  /// **'Finding type'**
  String get s9FindingTypeLabel;

  /// S9 field hint.
  ///
  /// In en, this message translates to:
  /// **'What needs fixing'**
  String get s9FindingTypeHint;

  /// S9 field label.
  ///
  /// In en, this message translates to:
  /// **'Required fix'**
  String get s9RequiredFixLabel;

  /// S9 field hint.
  ///
  /// In en, this message translates to:
  /// **'The corrective action'**
  String get s9RequiredFixHint;

  /// S9 label above the priority choices.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get s9PriorityLabel;

  /// S9 add-task button.
  ///
  /// In en, this message translates to:
  /// **'Add task'**
  String get s9AddButton;

  /// S9 confirmation after adding a task.
  ///
  /// In en, this message translates to:
  /// **'Task queued for sync'**
  String get s9Saved;

  /// Shared error copy: an authenticated request was refused because the sign-in expired.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again.'**
  String get errorSessionExpired;

  /// Shared error copy: no connection, or the request timed out. Often shown after a prefix such as 'Failed to load photo.'
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server. Check your connection and try again.'**
  String get errorUnreachable;

  /// Shared error copy for any other failure (server error, bug). Never shows technical detail.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// Check-in: the agent (or the phone) refused the app access to location. Shown under 'Can’t find your location'.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied'**
  String get checkInLocationPermissionDenied;

  /// Check-in: the phone's location (GPS) is switched off. Shown under 'Can’t find your location'.
  ///
  /// In en, this message translates to:
  /// **'Location services are disabled'**
  String get checkInLocationServicesDisabled;

  /// Check-in: no GPS fix arrived in time. Shown under 'Can’t find your location'.
  ///
  /// In en, this message translates to:
  /// **'Took too long. Check location is on for TradeIQ, then try again.'**
  String get checkInLocationTimedOut;

  /// Check-in: the location lookup failed with an unexpected error.
  ///
  /// In en, this message translates to:
  /// **'Failed to get current location: {error}'**
  String checkInLocationFailed(String error);

  /// Visit hub, outlet info tile: nothing to capture, it was confirmed by checking in.
  ///
  /// In en, this message translates to:
  /// **'Confirmed at check-in'**
  String get progressConfirmedAtCheckIn;

  /// Visit hub, stock or pricing tile part-way through: SKUs captured out of the store's SKU list.
  ///
  /// In en, this message translates to:
  /// **'{items} of {total} SKUs'**
  String progressSkusOfTotal(int items, int total);

  /// Visit hub, stock tile: every SKU counted, none out of stock.
  ///
  /// In en, this message translates to:
  /// **'{items} SKUs counted'**
  String progressStockCounted(int items);

  /// Visit hub, stock tile: SKUs counted, and how many were at zero.
  ///
  /// In en, this message translates to:
  /// **'{items} SKUs · {outOfStock} out of stock'**
  String progressStockOutOfStock(int items, int outOfStock);

  /// Visit hub, pricing tile.
  ///
  /// In en, this message translates to:
  /// **'{items} SKUs priced'**
  String progressSkusPriced(int items);

  /// Visit hub, competitive tile: saved with no competitor products on the shelf.
  ///
  /// In en, this message translates to:
  /// **'None on shelf'**
  String get progressNoCompetitors;

  /// Visit hub, competitive tile: number of competitor products recorded (at least 1).
  ///
  /// In en, this message translates to:
  /// **'{items} competitor(s)'**
  String progressCompetitors(int items);

  /// Visit hub tile for a section that has been saved (visibility, capability, action plan).
  ///
  /// In en, this message translates to:
  /// **'Captured'**
  String get progressCaptured;

  /// Visit hub, risks tile: saved with no risks flagged.
  ///
  /// In en, this message translates to:
  /// **'None raised'**
  String get progressNoRisks;

  /// Visit hub, risks tile: number of risks flagged (at least 1).
  ///
  /// In en, this message translates to:
  /// **'{items} raised'**
  String progressRisksRaised(int items);

  /// Submit gate: a task the visit will raise because a SKU was counted at zero.
  ///
  /// In en, this message translates to:
  /// **'{sku} is out of stock'**
  String taskStockoutTitle(String sku);

  /// Submit gate: as taskStockoutTitle, when the SKU's name is not known.
  ///
  /// In en, this message translates to:
  /// **'This SKU is out of stock'**
  String get taskStockoutTitleUnnamed;

  /// Why a stock-out task is raised.
  ///
  /// In en, this message translates to:
  /// **'You counted zero on shelf'**
  String get taskStockoutReason;

  /// Submit gate: title of a task raised for a risk with no note; flagType is what the agent typed as the kind of flag.
  ///
  /// In en, this message translates to:
  /// **'{flagType} flagged'**
  String taskRiskTitle(String flagType);

  /// Submit gate: title of a task raised for a risk with no note and no flag type.
  ///
  /// In en, this message translates to:
  /// **'Risk flagged'**
  String get taskRiskTitleUntyped;

  /// Why a risk task is raised, with the kind of flag the agent typed.
  ///
  /// In en, this message translates to:
  /// **'Risk you raised · {flagType}'**
  String taskRiskReason(String flagType);

  /// Why a risk task is raised, when the agent gave no flag type.
  ///
  /// In en, this message translates to:
  /// **'Risk you raised · flagged'**
  String get taskRiskReasonUntyped;

  /// Submit gate: title of an action-plan task the agent left without a required fix.
  ///
  /// In en, this message translates to:
  /// **'Action you asked for'**
  String get taskActionPlanTitleUntitled;

  /// Why an action-plan task is raised.
  ///
  /// In en, this message translates to:
  /// **'Action plan you wrote'**
  String get taskActionPlanReason;

  /// Submit gate summary line, first part. Parts are separated by ' · '.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 SKU counted} other{{count} SKUs counted}}'**
  String reviewSkusCounted(int count);

  /// Submit gate summary line part: competitor products recorded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 competitor} other{{count} competitors}}'**
  String reviewCompetitors(int count);

  /// Submit gate summary line part: photos taken.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo} other{{count} photos}}'**
  String reviewPhotos(int count);

  /// Visit hub and the client-questions section: labels the extra section built from the client's own audit template (#122). The template name itself is client-authored and not translated.
  ///
  /// In en, this message translates to:
  /// **'Client questions'**
  String get visitTemplateSectionKicker;

  /// Visit hub tile/row line under the client template's name: the section kind, then its state (e.g. "2 of 5 answered" or "Optional").
  ///
  /// In en, this message translates to:
  /// **'Client questions · {detail}'**
  String visitTemplateTileDetail(String detail);

  /// Client-questions section: one-line intro above the questions.
  ///
  /// In en, this message translates to:
  /// **'Asked on every visit. Answer the required ones to submit.'**
  String get visitTemplateSectionIntro;

  /// Client-questions progress: visible questions answered out of visible questions.
  ///
  /// In en, this message translates to:
  /// **'{answered} of {total} answered'**
  String visitTemplateProgressAnswered(int answered, int total);

  /// Client-questions section and hub: required questions still unanswered, which block the submit.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 required question left} other{{count} required questions left}}'**
  String visitTemplateRequiredLeft(int count);

  /// Client-questions section: shown once nothing required is left.
  ///
  /// In en, this message translates to:
  /// **'All required questions answered'**
  String get visitTemplateAllRequiredAnswered;

  /// Client-questions section: marker on a question that must be answered before submitting.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get visitTemplateFieldRequired;

  /// Client-questions section: shown on an unanswered required question after the agent saves.
  ///
  /// In en, this message translates to:
  /// **'Answer this before you submit'**
  String get visitTemplateFieldRequiredError;

  /// Client-questions section: save button. Answers are queued for sync.
  ///
  /// In en, this message translates to:
  /// **'Save answers'**
  String get visitTemplateSave;

  /// Client-questions section: confirmation after saving.
  ///
  /// In en, this message translates to:
  /// **'Answers saved — queued for sync'**
  String get visitTemplateSaved;

  /// Client-questions section: shown on a photo question, which cannot be captured in the form yet and never blocks the submit.
  ///
  /// In en, this message translates to:
  /// **'Photo questions can’t be answered in the app yet'**
  String get visitTemplatePhotoUnsupported;

  /// Client-questions section: the template has no renderable questions.
  ///
  /// In en, this message translates to:
  /// **'This client’s template has no questions yet'**
  String get visitTemplateNoQuestions;

  /// Title of the one-time location notice (#153, POPIA). Shown before the app sends any location.
  ///
  /// In en, this message translates to:
  /// **'Your location is shared with your manager'**
  String get locationNoticeTitle;

  /// Body of the one-time location notice: what is shared, with whom, how often, and when it stops.
  ///
  /// In en, this message translates to:
  /// **'Your manager can see which store you are at.\n\nWhile TradeIQ is open and you are signed in, it sends your location {minutes, plural, =1{every minute} other{every {minutes} minutes}}. Closing TradeIQ or signing out stops it. Nothing is sent in the background.'**
  String locationNoticeBody(int minutes);

  /// Location notice: the agent agrees to share their location while the app is open.
  ///
  /// In en, this message translates to:
  /// **'I understand, share my location'**
  String get locationNoticeAcknowledge;

  /// Location notice: the agent declines. Nothing is sent.
  ///
  /// In en, this message translates to:
  /// **'Don’t share'**
  String get locationNoticeDecline;

  /// Always-visible indicator on agent screens while location pings are being sent.
  ///
  /// In en, this message translates to:
  /// **'Sharing your location with your manager'**
  String get locationSharingActiveTitle;

  /// Under the sharing indicator.
  ///
  /// In en, this message translates to:
  /// **'Only while TradeIQ is open · tap to stop'**
  String get locationSharingActiveSubtitle;

  /// Under the sharing indicator when the phone gave no location (permission or GPS off). Not an error.
  ///
  /// In en, this message translates to:
  /// **'Sharing is on, but this phone isn’t giving TradeIQ a location'**
  String get locationSharingNoFixSubtitle;

  /// Shown after the agent declined the location notice.
  ///
  /// In en, this message translates to:
  /// **'Your location is not shared'**
  String get locationSharingOffTitle;

  /// Under 'Your location is not shared'; tapping shows the notice again.
  ///
  /// In en, this message translates to:
  /// **'Tap to change this'**
  String get locationSharingOffSubtitle;

  /// Confirmation dialog title after tapping the sharing indicator.
  ///
  /// In en, this message translates to:
  /// **'Stop sharing your location?'**
  String get locationStopTitle;

  /// Confirmation dialog body for stopping location sharing.
  ///
  /// In en, this message translates to:
  /// **'Your manager will no longer see where you are. You can turn it back on later.'**
  String get locationStopBody;

  /// Confirmation dialog: stop sharing location.
  ///
  /// In en, this message translates to:
  /// **'Stop sharing'**
  String get locationStopConfirm;

  /// Confirmation dialog: keep sharing location.
  ///
  /// In en, this message translates to:
  /// **'Keep sharing'**
  String get locationStopCancel;

  /// Title of the SEPARATE background-tracking notice (#153 T2, POPIA). Android only. Distinct from the foreground notice: accepting that one does not accept this one.
  ///
  /// In en, this message translates to:
  /// **'Recording your route between stores'**
  String get backgroundLocationNoticeTitle;

  /// Body of the background-tracking notice: what is recorded, how often, when it runs, that it runs with the app closed, that a notification is always shown, and how to stop it.
  ///
  /// In en, this message translates to:
  /// **'Separate from sharing while TradeIQ is open, and you can say no.\n\nTradeIQ records where you are {minutes, plural, =1{every minute} other{every {minutes} minutes}}, even when it is closed, so your manager can see your route between stores. Working days {start}–{end} only — never at night or at a weekend. A notification stays on your phone the whole time. You can turn it off whenever you like; that does not stop the sharing you already agreed to.'**
  String backgroundLocationNoticeBody(int minutes, String start, String end);

  /// Background notice: the agent agrees. Only after this does the app ask Android for background location.
  ///
  /// In en, this message translates to:
  /// **'Turn on route tracking'**
  String get backgroundLocationNoticeAccept;

  /// Background notice: the agent declines. Nothing is recorded, and foreground sharing is unaffected.
  ///
  /// In en, this message translates to:
  /// **'No, don’t record my route'**
  String get backgroundLocationNoticeDecline;

  /// Quiet one-line offer on agent screens when background tracking is not on. Never the full notice unasked.
  ///
  /// In en, this message translates to:
  /// **'Route tracking is off'**
  String get backgroundLocationOfferTitle;

  /// Under 'Route tracking is off'; tapping opens the background notice.
  ///
  /// In en, this message translates to:
  /// **'Tap to see what it does'**
  String get backgroundLocationOfferSubtitle;

  /// Non-dismissable indicator on agent screens while the background service is running.
  ///
  /// In en, this message translates to:
  /// **'Recording your route between stores'**
  String get backgroundLocationActiveTitle;

  /// Under the route-tracking indicator.
  ///
  /// In en, this message translates to:
  /// **'Working hours only · tap to stop'**
  String get backgroundLocationActiveSubtitle;

  /// Shown when background tracking is on but the client's working-hours window is shut — evening, night or a weekend.
  ///
  /// In en, this message translates to:
  /// **'Route tracking is paused'**
  String get backgroundLocationOutsideHoursTitle;

  /// Under 'Route tracking is paused'. The time the client's working day begins.
  ///
  /// In en, this message translates to:
  /// **'It starts again on a working day at {start}'**
  String backgroundLocationOutsideHoursSubtitle(String start);

  /// Shown after the agent accepts the background notice but Android has not granted 'Allow all the time'.
  ///
  /// In en, this message translates to:
  /// **'Android needs one more permission'**
  String get backgroundLocationPermissionTitle;

  /// Explains Android's two-step background-location flow, and that refusing costs nothing else.
  ///
  /// In en, this message translates to:
  /// **'Choose “Allow all the time” for location on TradeIQ’s settings page.\n\nThat lets TradeIQ record your route when it is closed. Everything else keeps working if you would rather not.'**
  String get backgroundLocationPermissionBody;

  /// Opens the Android app settings page, the only place 'Allow all the time' can be chosen from Android 11 on.
  ///
  /// In en, this message translates to:
  /// **'Open TradeIQ’s settings'**
  String get backgroundLocationPermissionOpenSettings;

  /// Declines the permission step. Route tracking stays off; nothing else changes.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get backgroundLocationPermissionNotNow;

  /// Confirmation dialog title after tapping the route-tracking indicator.
  ///
  /// In en, this message translates to:
  /// **'Stop recording your route?'**
  String get backgroundLocationStopTitle;

  /// Confirmation dialog body. Says plainly that stopping background tracking leaves foreground sharing alone.
  ///
  /// In en, this message translates to:
  /// **'Your manager will no longer see your route between stores.\n\nSharing your location while TradeIQ is open is not affected.'**
  String get backgroundLocationStopBody;

  /// Confirmation dialog: stop background tracking.
  ///
  /// In en, this message translates to:
  /// **'Stop route tracking'**
  String get backgroundLocationStopConfirm;

  /// Confirmation dialog: keep background tracking on.
  ///
  /// In en, this message translates to:
  /// **'Keep recording'**
  String get backgroundLocationStopCancel;

  /// Title of the permanent, non-dismissable Android notification shown the whole time the background service runs. Android requires it; it is also the honest thing to show.
  ///
  /// In en, this message translates to:
  /// **'TradeIQ is recording your route'**
  String get backgroundLocationNotificationTitle;

  /// Body of the permanent Android notification.
  ///
  /// In en, this message translates to:
  /// **'Working hours only. Turn it off in TradeIQ.'**
  String get backgroundLocationNotificationBody;

  /// Name of the Android notification channel, as it appears in the phone's system settings.
  ///
  /// In en, this message translates to:
  /// **'Route tracking'**
  String get backgroundLocationNotificationChannel;

  /// Agent Contests screen title (#124). A contest ranks agents by the points they earn between two dates, for a prize.
  ///
  /// In en, this message translates to:
  /// **'Contests'**
  String get contestsTitle;

  /// Under the Contests title.
  ///
  /// In en, this message translates to:
  /// **'Earn points, climb the standings'**
  String get contestsSubtitle;

  /// Section heading above contests that are currently active.
  ///
  /// In en, this message translates to:
  /// **'Running now'**
  String get contestsActiveHeading;

  /// Section heading above contests that ended in the last 30 days.
  ///
  /// In en, this message translates to:
  /// **'Recently ended'**
  String get contestsEndedHeading;

  /// Pill on an active contest: days remaining, counting today (1 on the last day).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day left} other{{count} days left}}'**
  String contestDaysLeft(int count);

  /// Pill on a contest that has ended.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get contestEnded;

  /// A contest's first and last day, both inclusive. The dates are already formatted for the locale (e.g. '1 Oct').
  ///
  /// In en, this message translates to:
  /// **'{start} – {end}'**
  String contestDateRange(String start, String end);

  /// Label above the contest's prize, which the manager wrote as free text.
  ///
  /// In en, this message translates to:
  /// **'Prize'**
  String get contestPrizeLabel;

  /// Label above the kinds of points a contest counts.
  ///
  /// In en, this message translates to:
  /// **'What counts'**
  String get contestCountsLabel;

  /// The contest counts every kind of points.
  ///
  /// In en, this message translates to:
  /// **'All points'**
  String get contestEventAll;

  /// A kind of points a contest counts: visits the agent submitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted visits'**
  String get contestEventVisitSubmitted;

  /// A kind of points a contest counts: tasks the agent closed.
  ///
  /// In en, this message translates to:
  /// **'Closed tasks'**
  String get contestEventTaskClosed;

  /// A kind of points a contest counts: visit scorecards (the average score is added).
  ///
  /// In en, this message translates to:
  /// **'Scorecards'**
  String get contestEventScorecard;

  /// The agent's own position in a contest. Agents on equal points share a rank.
  ///
  /// In en, this message translates to:
  /// **'Your rank: {rank} of {total}'**
  String contestYourRank(int rank, int total);

  /// A points figure in a contest. 'points' is already formatted (e.g. '12' or '78.5').
  ///
  /// In en, this message translates to:
  /// **'{points} pts'**
  String contestPoints(String points);

  /// Shown instead of the agent's rank when they are not part of the contest.
  ///
  /// In en, this message translates to:
  /// **'You’re not on this contest’s standings'**
  String get contestNotRanked;

  /// Heading above the top of a contest's ranking.
  ///
  /// In en, this message translates to:
  /// **'Standings'**
  String get contestStandingsHeading;

  /// Tag on the agent's own row in the standings.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get contestYouTag;

  /// Contests screen when there is nothing active or recently ended.
  ///
  /// In en, this message translates to:
  /// **'No contests right now'**
  String get contestsEmptyTitle;

  /// Under 'No contests right now'.
  ///
  /// In en, this message translates to:
  /// **'When your manager starts a contest, it shows up here.'**
  String get contestsEmptyBody;

  /// Contests screen when the request failed. The reason follows underneath.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load contests'**
  String get contestsLoadError;

  /// Button that reloads the contests after a failure.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get contestsRetry;

  /// Tooltip and screen-reader label on the Today app bar trophy when contests are running; the badge shows the number.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 contest running} other{{count} contests running}}'**
  String contestsRunningHint(int count);

  /// Tooltip on the agent app bar's bell button, which opens the notification settings (#67).
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get agentNotificationsTooltip;

  /// Title of the agent's push notification settings screen (#67).
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// Subtitle under the notification settings title.
  ///
  /// In en, this message translates to:
  /// **'Choose what reaches this phone'**
  String get notificationsSubtitle;

  /// Toggle: push when someone assigns the agent a task.
  ///
  /// In en, this message translates to:
  /// **'Tasks assigned to you'**
  String get notificationsTasksLabel;

  /// Help line under notificationsTasksLabel.
  ///
  /// In en, this message translates to:
  /// **'When your manager gives you a task'**
  String get notificationsTasksHelp;

  /// Toggle: push for new messages, team messages and announcements.
  ///
  /// In en, this message translates to:
  /// **'Messages and announcements'**
  String get notificationsMessagesLabel;

  /// Help line under notificationsMessagesLabel.
  ///
  /// In en, this message translates to:
  /// **'Messages to you or the team, and announcements'**
  String get notificationsMessagesHelp;

  /// Toggle: push when one of the agent's tasks passes its SLA deadline.
  ///
  /// In en, this message translates to:
  /// **'Overdue tasks'**
  String get notificationsSlaLabel;

  /// Help line under notificationsSlaLabel.
  ///
  /// In en, this message translates to:
  /// **'When one of your tasks passes its deadline'**
  String get notificationsSlaHelp;

  /// Banner when push is not configured in this build of the app. Not an error.
  ///
  /// In en, this message translates to:
  /// **'Notifications aren’t switched on yet'**
  String get notificationsNotSetUpTitle;

  /// Under notificationsNotSetUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Your choices are saved and apply as soon as they are.'**
  String get notificationsNotSetUpBody;

  /// Shown when the settings could not be fetched.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load your notification settings'**
  String get notificationsLoadErrorTitle;

  /// Button to fetch the notification settings again.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get notificationsRetry;

  /// Snackbar when a toggle could not be saved; the toggle flips back.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t save that. Check your connection and try again.'**
  String get notificationsSaveFailed;

  /// Footnote under the notification toggles.
  ///
  /// In en, this message translates to:
  /// **'You can also turn these off in your phone’s settings.'**
  String get notificationsFooter;

  /// Nav slot 1 of the agent's floating pill. One or two words — the bar goes icon-only if any label overflows.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get navToday;

  /// Nav slot 2: the agent's outbox.
  ///
  /// In en, this message translates to:
  /// **'My work'**
  String get navMyWork;

  /// Nav slot 3.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get navMap;

  /// Nav slot 4: the agent's own profile and earnings.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get navMe;

  /// Block label inside the day block on Today. Sentence case; the widget uppercases for display.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get todayRouteEyebrow;

  /// State word under a later stop's distance on Today. The counterpart of todayStopDoneTag.
  ///
  /// In en, this message translates to:
  /// **'To do'**
  String get todayStopUpcoming;

  /// Unit word after a distance in metres. Set in the surrounding text face beside a monospaced figure.
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get unitMetres;

  /// Unit word after a distance in kilometres.
  ///
  /// In en, this message translates to:
  /// **'km'**
  String get unitKilometres;

  /// The name of the paper screen, in the skin cycle's spoken label.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get skinDay;

  /// The name of the dark screen, in the skin cycle's spoken label.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get skinNight;

  /// The name of the outdoor screen, in the skin cycle's spoken label. The explanation is part of the name because a blind user has no other way to learn what Veld is.
  ///
  /// In en, this message translates to:
  /// **'Veld, the outdoor high-contrast screen'**
  String get skinVeld;

  /// Sync chip when the outbox is empty.
  ///
  /// In en, this message translates to:
  /// **'All sent'**
  String get syncChipAllSent;

  /// Screen-reader label for the all-sent sync chip. The state word leads.
  ///
  /// In en, this message translates to:
  /// **'All your work is sent. Double-tap to see it.'**
  String get syncChipAllSentSemantics;

  /// Name of the client-questions row when the client's own template could not be loaded, so its real name is unknown.
  ///
  /// In en, this message translates to:
  /// **'The client’s questions'**
  String get visitClientQuestions;

  /// Headline when the visit hub cannot read its own progress.
  ///
  /// In en, this message translates to:
  /// **'This visit could not be read.'**
  String get visitReadFailedTitle;

  /// Why the submit is disabled when the hub's progress read failed. Shown above the button.
  ///
  /// In en, this message translates to:
  /// **'The visit’s own progress could not be read, so it cannot be sent yet.'**
  String get visitReadFailedBlock;

  /// Detail line on a section whose state is can't-confirm because the outlet's SKU list failed to load.
  ///
  /// In en, this message translates to:
  /// **'The product list did not load — this section can’t be confirmed.'**
  String get visitCantConfirmProducts;

  /// Detail line on the client-questions row when its template could not be pinned to the visit.
  ///
  /// In en, this message translates to:
  /// **'The client’s questions did not load — this section can’t be confirmed.'**
  String get visitCantConfirmTemplate;

  /// Block label at the top of the check-in failure screens.
  ///
  /// In en, this message translates to:
  /// **'Check-in'**
  String get visitCheckInEyebrow;

  /// Note on the too-far screen for the first and second attempt. A fact, with no threat attached — the penalty has not started.
  ///
  /// In en, this message translates to:
  /// **'Every attempt is recorded with where you were.'**
  String get visitTooFarAttemptsRecorded;

  /// Body line on the too-far screen when the agent is under 80 m away.
  ///
  /// In en, this message translates to:
  /// **'You’re close. Try walking to the front door.'**
  String get visitTooFarClose;

  /// Body line on the too-far screen when the agent is more than 2 km away.
  ///
  /// In en, this message translates to:
  /// **'This looks like the wrong store, or the store’s pin is wrong.'**
  String get visitTooFarWrongStore;

  /// A third, quieter action on the too-far screen: the agent is at the shop and the stored coordinates are not.
  ///
  /// In en, this message translates to:
  /// **'The pin is wrong'**
  String get visitPinIsWrong;

  /// Shown after the agent reports a wrong pin. Deliberately not 'Thanks, we will look into it': the endpoint does not exist and the copy must not pretend it does.
  ///
  /// In en, this message translates to:
  /// **'Reported on this phone. It has not been sent anywhere yet — there is nowhere to send it.'**
  String get visitPinReportedHeld;

  /// The fix, as its own paragraph, when location permission was denied.
  ///
  /// In en, this message translates to:
  /// **'Allow location for TradeIQ in your phone’s settings. You can allow it just while using the app.'**
  String get visitNoGpsFixPermission;

  /// The fix when location services are switched off on the device.
  ///
  /// In en, this message translates to:
  /// **'Turn location on in your phone’s settings, then try again.'**
  String get visitNoGpsFixServices;

  /// The fix when the position lookup timed out.
  ///
  /// In en, this message translates to:
  /// **'Step outside or near a window and try again. Your GPS still works in airplane mode — give it a few seconds.'**
  String get visitNoGpsFixTimedOut;

  /// The fix when the cause is not one we can name.
  ///
  /// In en, this message translates to:
  /// **'Step outside or near a window and try again.'**
  String get visitNoGpsFixGeneric;

  /// Button that copies the error code on the check-in failure screen.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get visitCopyCode;

  /// Screen-reader label for the Copy button.
  ///
  /// In en, this message translates to:
  /// **'Copy the error code'**
  String get visitCopyCodeSemantics;

  /// Screen-reader label for the whole day block on Today — one node, not five.
  ///
  /// In en, this message translates to:
  /// **'Route: {done} of {total} stores done, {left} left.'**
  String todayRouteSemantics(int done, int total, int left);

  /// Screen-reader label for one stop row on Today. Ends in its verb.
  ///
  /// In en, this message translates to:
  /// **'{name}, {code}, {state}. Double-tap to check in here.'**
  String todayStopSemantics(String name, String code, String state);

  /// Screen-reader label for a distance in metres; the unit is spelled out.
  ///
  /// In en, this message translates to:
  /// **'{meters} metres away'**
  String todayDistanceMetresSemantics(int meters);

  /// Screen-reader label for a distance in kilometres; the unit is spelled out.
  ///
  /// In en, this message translates to:
  /// **'{km} kilometres away'**
  String todayDistanceKmSemantics(num km);

  /// Screen-reader label for the skin cycle. It names the NEXT state, not this one — a toggle that says only where it is makes a blind user press it to find out.
  ///
  /// In en, this message translates to:
  /// **'Screen: {current}. Double-tap for {next}.'**
  String skinCycleLabel(String current, String next);

  /// Screen-reader label for the whole readiness block on the visit hub — one node.
  ///
  /// In en, this message translates to:
  /// **'Captured, {done} of {total}. {blocking} sections still needed.'**
  String visitReadinessSemantics(int done, int total, int blocking);

  /// Screen-reader label for the score row on the visit hub. It is not focusable as a button — the score is a result, not a form.
  ///
  /// In en, this message translates to:
  /// **'{name}, not yet available. Worked out when the visit sends.'**
  String visitScoreSemantics(String name);

  /// Screen-reader label for one section row on the visit hub: the name, then the state word, then the one-line detail.
  ///
  /// In en, this message translates to:
  /// **'{name}. {state}. {detail}'**
  String visitSectionSemantics(String name, String state, String detail);

  /// Body line beneath the measured distance on the too-far screen.
  ///
  /// In en, this message translates to:
  /// **'You need to be within 50 m. Right now you are {meters} m away.'**
  String visitTooFarNeedWithin(int meters);

  /// Screen-reader label for the measured-distance block; the unit is spelled out.
  ///
  /// In en, this message translates to:
  /// **'Too far from the shop. You are {meters} metres away. You need to be within 50 metres.'**
  String visitTooFarSemantics(int meters);

  /// Screen-reader label for the error-code block. The code arrives already spaced out character by character, because a machine code read as a word is a code nobody can repeat down a phone.
  ///
  /// In en, this message translates to:
  /// **'Error code {code}'**
  String visitErrorCodeSemantics(String code);

  /// Sync chip when captures are waiting on the phone. Never an error — this is the normal state of field connectivity.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 held on this phone} other{{count} held on this phone}}'**
  String syncChipHeld(int count);

  /// Screen-reader label for the held sync chip.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 capture held on this phone. Double-tap to see your work.} other{{count} captures held on this phone. Double-tap to see your work.}}'**
  String syncChipHeldSemantics(int count);

  /// Sync chip when items in the outbox will not send on their own.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 needs you} other{{count} need you}}'**
  String syncChipNeedsYou(int count);

  /// Screen-reader label for the needs-you sync chip. The state word leads.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Needs you. 1 capture will not send on its own. Double-tap to see your work.} other{Needs you. {count} captures will not send on their own. Double-tap to see your work.}}'**
  String syncChipNeedsYouSemantics(int count);

  /// Second line in the readiness block. Counted and named separately from the captured figure: a section nobody could measure is not a section somebody skipped.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 section can’t be confirmed} other{{count} sections can’t be confirmed}}'**
  String visitCantConfirmCount(int count);

  /// Ghost action on the outcome screen: open the outbox.
  ///
  /// In en, this message translates to:
  /// **'Open my work'**
  String get outcomeOpenMyWork;

  /// Screen-reader line for the outcome hero.
  ///
  /// In en, this message translates to:
  /// **'Perfect-store score, {score} out of 100. {band}.'**
  String outcomeHeroSemantics(int score, String band);

  /// Screen-reader line for one scored dimension.
  ///
  /// In en, this message translates to:
  /// **'{name}, {value} out of 100.'**
  String outcomeDimensionSemantics(String name, int value);

  /// Screen-reader line for an unmeasured dimension.
  ///
  /// In en, this message translates to:
  /// **'{name}, not measured. {reason}'**
  String outcomeDimensionUnmeasuredSemantics(String name, String reason);

  /// Reason shown on an unmeasured dimension the server gave no reason for.
  ///
  /// In en, this message translates to:
  /// **'Not measured in this visit.'**
  String get outcomeNotMeasuredGeneric;

  /// Shown instead of a delta when there is no previous visit.
  ///
  /// In en, this message translates to:
  /// **'First scored visit here.'**
  String get outcomeFirstScored;

  /// First half of the reconciliation line: 'Now scored 71 — it was 84'.
  ///
  /// In en, this message translates to:
  /// **'Now scored'**
  String get outcomeReconciledLead;

  /// Second half of the reconciliation line.
  ///
  /// In en, this message translates to:
  /// **'— it was'**
  String get outcomeReconciledTail;

  /// Screen-reader line for the reconciliation line.
  ///
  /// In en, this message translates to:
  /// **'Now scored {now}. It was {seen} when you saw it.'**
  String outcomeReconciledSemantics(int now, int seen);

  /// Reason under the reconciliation line.
  ///
  /// In en, this message translates to:
  /// **'It was scored again after you saw it.'**
  String get outcomeReconciledReason;

  /// Screen-reader label for the outcome's primary.
  ///
  /// In en, this message translates to:
  /// **'Go on to the next store'**
  String get outcomeNextStoreSemantics;

  /// Screen-reader line announcing the held-on-phone outcome.
  ///
  /// In en, this message translates to:
  /// **'Submitted. Held on this phone until you have signal.'**
  String get outcomeHeldSemantics;

  /// Screen-reader label for the pre-capture card's primary.
  ///
  /// In en, this message translates to:
  /// **'Open the camera to photograph the shelf'**
  String get captureOpenCameraSemantics;

  /// Shown on the pre-capture card when the last shot was underexposed.
  ///
  /// In en, this message translates to:
  /// **'Aisle dark? Switch your phone torch on before you shoot.'**
  String get captureTorchHint;

  /// Meta line on the pre-capture card.
  ///
  /// In en, this message translates to:
  /// **'Your photo is stamped with the time and where you are.'**
  String get captureStampNote;

  /// Title of the photo review step.
  ///
  /// In en, this message translates to:
  /// **'Check the photo'**
  String get captureReviewTitle;

  /// Caption under an underexposed photo in the review strip.
  ///
  /// In en, this message translates to:
  /// **'Dark — retake?'**
  String get captureDarkCaption;

  /// Screen-reader announcement for an underexposed photo.
  ///
  /// In en, this message translates to:
  /// **'Dark — you may want to retake this.'**
  String get captureDarkSemantics;

  /// Primary on the photo review step: keep this photo.
  ///
  /// In en, this message translates to:
  /// **'Use it'**
  String get captureUseIt;

  /// Shown when the camera cannot be opened at all.
  ///
  /// In en, this message translates to:
  /// **'This phone has no camera we can reach.'**
  String get captureNoCamera;

  /// Word in the photo's meta line when it carries a location.
  ///
  /// In en, this message translates to:
  /// **'geotagged'**
  String get captureGeotagged;

  /// Word in the photo's meta line when it carries no location.
  ///
  /// In en, this message translates to:
  /// **'no location on this photo'**
  String get captureNoGeotag;

  /// The photo's meta line in the review step.
  ///
  /// In en, this message translates to:
  /// **'{time} · {tag}'**
  String capturePhotoMeta(String time, String tag);

  /// Screen-reader label for the reviewed photo.
  ///
  /// In en, this message translates to:
  /// **'Photo taken {time}, held on this phone.'**
  String capturePhotoSemantics(String time);

  /// Title of the agent's map screen. The same word as the nav slot (navMap), deliberately: the tab and the screen are one destination.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get mapTitle;

  /// Header fact: how many of the agent's stores this screen is about.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 store} other{{count} stores}}'**
  String mapStoresFact(int count);

  /// Section rule above the stores that are on today's beat plan.
  ///
  /// In en, this message translates to:
  /// **'Today’s route'**
  String get mapRouteHeading;

  /// Under the route section rule when there is no plan. The section still renders — a section that vanishes reads as a missing feature.
  ///
  /// In en, this message translates to:
  /// **'No route planned for today.'**
  String get mapRouteEmptyLine;

  /// Section rule above the agent's other outlets — in their territories, not on today's plan.
  ///
  /// In en, this message translates to:
  /// **'The rest of your patch'**
  String get mapPatchHeading;

  /// Pin and row state: a stop on today's route that is already done.
  ///
  /// In en, this message translates to:
  /// **'Visited today'**
  String get mapStateDone;

  /// Pin and row state: the next stop on today's route.
  ///
  /// In en, this message translates to:
  /// **'Next up'**
  String get mapStateNext;

  /// Pin and row state: on the plan, further down it.
  ///
  /// In en, this message translates to:
  /// **'On today’s route'**
  String get mapStatePlanned;

  /// Pin and row state: one of the agent's stores, not on today's plan.
  ///
  /// In en, this message translates to:
  /// **'In your patch'**
  String get mapStateTerritory;

  /// Extra state word on a store whose coordinates are disputed (#386). Never replaces the other state word — it is added to it.
  ///
  /// In en, this message translates to:
  /// **'Pin under review'**
  String get mapStateDisputed;

  /// Sentence in the store's sheet when its pin is under review.
  ///
  /// In en, this message translates to:
  /// **'Someone has reported this pin as wrong, so the position on the map may not be the shop.'**
  String get mapDisputedLine;

  /// The marker for the phone's own position. Only ever drawn when there is a fix.
  ///
  /// In en, this message translates to:
  /// **'You are here'**
  String get mapYouAreHere;

  /// Location permission refused. Not an error, and not a broken map.
  ///
  /// In en, this message translates to:
  /// **'Location is off for this app, so there are no distances and no dot for where you are. The stores are still right.'**
  String get mapLocationDenied;

  /// Device location services are off.
  ///
  /// In en, this message translates to:
  /// **'Location is switched off on this phone, so there are no distances and no dot for where you are. The stores are still right.'**
  String get mapLocationServicesOff;

  /// The radio is on and no fix arrived. Also used for a platform failure we have no code for.
  ///
  /// In en, this message translates to:
  /// **'This phone cannot get a fix yet, so there are no distances and no dot for where you are. The stores are still right.'**
  String get mapLocationNoFix;

  /// Headline in the map's own region when the tiles will not load.
  ///
  /// In en, this message translates to:
  /// **'No map here'**
  String get mapTilesOffTitle;

  /// Body under mapTilesOffTitle. Offline on a rural forecourt is the normal case, not an error.
  ///
  /// In en, this message translates to:
  /// **'The map will not load — there is nothing to fetch it with. Your stores are listed below, and the list needs no connection.'**
  String get mapTilesOffBody;

  /// Shown instead of the map in the Veld skin, where maps do not render.
  ///
  /// In en, this message translates to:
  /// **'The map is off in bright sun. Your stores are listed below, nearest first.'**
  String get mapVeldNote;

  /// Whole-screen empty state: no route today and nothing in the agent's territories.
  ///
  /// In en, this message translates to:
  /// **'No stores yet'**
  String get mapEmptyTitle;

  /// Body of the empty state. It names who fixes it.
  ///
  /// In en, this message translates to:
  /// **'There is no route for today and no store in your patch. A manager assigns both.'**
  String get mapEmptyBody;

  /// Whole-screen error headline on the map.
  ///
  /// In en, this message translates to:
  /// **'Your stores did not load'**
  String get mapLoadErrorTitle;

  /// Body of the error state. It offers the action that still works.
  ///
  /// In en, this message translates to:
  /// **'We could not reach the server. Your day still works — pick a store and check in.'**
  String get mapLoadErrorDetail;

  /// Pagination footer when the marker budget cuts the list and there is a fix to sort by.
  ///
  /// In en, this message translates to:
  /// **'Showing the {shown} nearest of {total} stores.'**
  String mapShowingNearest(int shown, int total);

  /// Pagination footer when there is no fix, so the list is by name and nearest means nothing.
  ///
  /// In en, this message translates to:
  /// **'Showing {shown} of {total} stores.'**
  String mapShowingFirst(int shown, int total);

  /// Action in the sheet for a store already visited today. Deliberately not the primary — going back is allowed, not expected.
  ///
  /// In en, this message translates to:
  /// **'Check in again'**
  String get mapCheckInAgain;

  /// Sentence in the sheet for a store already visited today.
  ///
  /// In en, this message translates to:
  /// **'You checked in here today.'**
  String get mapVisitedTodayLine;

  /// The nav circle when the agent is standing inside a store's check-in fence.
  ///
  /// In en, this message translates to:
  /// **'Check in at {name}'**
  String mapCircleAtDoor(String name);

  /// Screen-reader label for a marker on the map.
  ///
  /// In en, this message translates to:
  /// **'{name}, {state}. Double-tap for what you can do here.'**
  String mapPinHint(String name, String state);

  /// Spoken label for the map's legend row.
  ///
  /// In en, this message translates to:
  /// **'What the pins mean'**
  String get mapLegendLabel;

  /// The close action on a bottom sheet, and the 56dp close row of the full-screen route it becomes in Veld.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get sheetClose;

  /// The Ask TradeIQ route's title.
  ///
  /// In en, this message translates to:
  /// **'Ask TradeIQ'**
  String get askTitle;

  /// Opens the conversation history sheet.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get askHistoryAction;

  /// History with the number of questions in this session.
  ///
  /// In en, this message translates to:
  /// **'History · {count}'**
  String askHistoryActionCount(int count);

  /// The standing label above the composer trough. It never moves.
  ///
  /// In en, this message translates to:
  /// **'Ask a question'**
  String get askComposerLabel;

  /// Placeholder inside the empty composer.
  ///
  /// In en, this message translates to:
  /// **'Team, stock, shelf, competitors'**
  String get askComposerHint;

  /// Replaces the composer label after a failed turn.
  ///
  /// In en, this message translates to:
  /// **'Ask again, or rephrase'**
  String get askComposerRephrase;

  /// The composer's commit action.
  ///
  /// In en, this message translates to:
  /// **'Send this question'**
  String get askSend;

  /// Spoken when Send is disabled offline.
  ///
  /// In en, this message translates to:
  /// **'Send, unavailable, needs a connection'**
  String get askSendUnavailable;

  /// Spoken when Send is disabled because the trough is empty.
  ///
  /// In en, this message translates to:
  /// **'Send, unavailable, nothing typed yet'**
  String get askSendNothingTyped;

  /// Replaces Send while a turn streams.
  ///
  /// In en, this message translates to:
  /// **'Stop the answer'**
  String get askStop;

  /// Announced when a question is sent.
  ///
  /// In en, this message translates to:
  /// **'Question sent'**
  String get askQuestionSent;

  /// Semantics label on the question bubble.
  ///
  /// In en, this message translates to:
  /// **'Your question'**
  String get askYourQuestion;

  /// First-run headline.
  ///
  /// In en, this message translates to:
  /// **'Ask about your territory.'**
  String get askEmptyHeadline;

  /// First-run body — says plainly that the assistant is read-only.
  ///
  /// In en, this message translates to:
  /// **'I read your sales, stock, shelf and competitor data and explain what I find. I cannot change anything.'**
  String get askEmptyBody;

  /// Section rule above the example questions.
  ///
  /// In en, this message translates to:
  /// **'Try one of these'**
  String get askTryOneOfThese;

  /// Closing line of the first-run screen.
  ///
  /// In en, this message translates to:
  /// **'Read-only. Nothing you ask here changes your data.'**
  String get askReadOnlyFootnote;

  /// First-run example question.
  ///
  /// In en, this message translates to:
  /// **'How has my team been performing this month?'**
  String get askExampleTeam;

  /// What the team example question will actually read.
  ///
  /// In en, this message translates to:
  /// **'reads visit history and scorecards'**
  String get askExampleTeamReads;

  /// First-run example question.
  ///
  /// In en, this message translates to:
  /// **'Which outlets keep running out of stock?'**
  String get askExampleStock;

  /// What the stock example question will actually read.
  ///
  /// In en, this message translates to:
  /// **'reads stock on shelf, worst first'**
  String get askExampleStockReads;

  /// First-run example question.
  ///
  /// In en, this message translates to:
  /// **'What is our share of shelf year to date?'**
  String get askExampleShelf;

  /// What the shelf example question will actually read.
  ///
  /// In en, this message translates to:
  /// **'reads shelf audits and photos'**
  String get askExampleShelfReads;

  /// First-run example question.
  ///
  /// In en, this message translates to:
  /// **'Show me any visits that look suspicious.'**
  String get askExampleFraud;

  /// What the fraud example question will actually read.
  ///
  /// In en, this message translates to:
  /// **'reads flagged visits and GPS'**
  String get askExampleFraudReads;

  /// Semantics label for the first-run suggestion group.
  ///
  /// In en, this message translates to:
  /// **'Four example questions'**
  String get askSuggestionsGroup;

  /// Spoken label of a first-run suggestion row; the second line is the teaching.
  ///
  /// In en, this message translates to:
  /// **'Ask: {question} This {reads}'**
  String askSuggestionSemantic(String question, String reads);

  /// Shown when the tenant is outside the rollout.
  ///
  /// In en, this message translates to:
  /// **'Not switched on yet.'**
  String get askNotEnabledHeadline;

  /// Names who can actually act, because a client admin cannot switch this on.
  ///
  /// In en, this message translates to:
  /// **'Ask TradeIQ is being rolled out gradually — speak to your TradeIQ contact to be included.'**
  String get askNotEnabledBody;

  /// The working-steps rail header while tools run.
  ///
  /// In en, this message translates to:
  /// **'Looking things up'**
  String get askStepsLookingUp;

  /// The rail header once every tool has finished.
  ///
  /// In en, this message translates to:
  /// **'Writing the answer'**
  String get askStepsWriting;

  /// Shown under a step that has run for more than twelve seconds.
  ///
  /// In en, this message translates to:
  /// **'This one is taking a while'**
  String get askStepsStillWorking;

  /// The rail header before the first lookup starts: the model is deciding what to look up.
  ///
  /// In en, this message translates to:
  /// **'Reading your question'**
  String get askStepsStarting;

  /// Announced once to a screen reader when a step has been silent for twelve seconds.
  ///
  /// In en, this message translates to:
  /// **'Still working on {label}.'**
  String askStepsStillWorkingOn(String label);

  /// The ghost button offered under the rail after thirty silent seconds. Stopping keeps what is already written.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get askStopShort;

  /// Manager nav slot 1: The Floor, the dashboard.
  ///
  /// In en, this message translates to:
  /// **'Floor'**
  String get askNavFloor;

  /// Manager nav slot 2: alerts and tasks.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get askNavWork;

  /// Manager nav slot 3: Ask TradeIQ.
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get askNavAsk;

  /// Manager nav slot 4: everything else.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get askNavMenu;

  /// The word that carries the live pulse when it is not amber, and under reduce-motion.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get askStepsLive;

  /// A step whose source did not answer.
  ///
  /// In en, this message translates to:
  /// **'{label} — unavailable'**
  String askStepsUnavailable(String label);

  /// A step still open when the stream ended.
  ///
  /// In en, this message translates to:
  /// **'{label} — did not finish'**
  String askStepsDidNotFinish(String label);

  /// The collapsed middle of a rail with more than eight steps.
  ///
  /// In en, this message translates to:
  /// **'{count} more'**
  String askStepsMore(int count);

  /// The collapsed provenance row.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Checked 1 source} other{Checked {count} sources}}'**
  String askStepsChecked(int count);

  /// How many sources did not answer.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unavailable} other{{count} unavailable}}'**
  String askStepsUnavailableCount(int count);

  /// Every tool failed — the explanation for a thin answer.
  ///
  /// In en, this message translates to:
  /// **'No sources answered'**
  String get askStepsNoneAnswered;

  /// The collapsed provenance row's action, spoken.
  ///
  /// In en, this message translates to:
  /// **'show the steps'**
  String get askStepsShow;

  /// The expanded provenance row's action, spoken.
  ///
  /// In en, this message translates to:
  /// **'hide the steps'**
  String get askStepsHide;

  /// Spoken label of the provenance row.
  ///
  /// In en, this message translates to:
  /// **'{summary}, {action}'**
  String askStepsSemantic(String summary, String action);

  /// Announced by the rail's live region as a step changes.
  ///
  /// In en, this message translates to:
  /// **'Step {index} of {total}, {label}'**
  String askStepProgress(int index, int total, String label);

  /// The section rule above the answer's one cause.
  ///
  /// In en, this message translates to:
  /// **'What explains it'**
  String get askCallout;

  /// The section rule above the cited pages.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get askSources;

  /// Shown when a search ran and cited nothing.
  ///
  /// In en, this message translates to:
  /// **'The web search returned nothing usable.'**
  String get askSourcesNothingUsable;

  /// Semantics label for the sources group.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Sources, 1 item} other{Sources, {count} items}}'**
  String askSourcesGroup(int count);

  /// Spoken label of one cited page.
  ///
  /// In en, this message translates to:
  /// **'Web source {index}, {domain}, {title}, opens in browser'**
  String askSourceSemantic(int index, String domain, String title);

  /// The source row's third line.
  ///
  /// In en, this message translates to:
  /// **'opens in browser'**
  String get askSourceOpensInBrowser;

  /// Shown on a source row whose launch the platform refused.
  ///
  /// In en, this message translates to:
  /// **'Could not open a browser. Long-press to copy the address.'**
  String get askSourceUnreachable;

  /// Toast after long-pressing a source row.
  ///
  /// In en, this message translates to:
  /// **'Address copied'**
  String get askSourceCopied;

  /// Toast after long-pressing a source row whose search result carried a preview. The preview is the page's own words, in plain text.
  ///
  /// In en, this message translates to:
  /// **'Address copied. The page says: {snippet}'**
  String askSourceCopiedPreview(String snippet);

  /// Expands the cited sources list in place.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Show 1 source} other{Show all {count} sources}}'**
  String askShowAllSources(int count);

  /// Expands a ranked list in place.
  ///
  /// In en, this message translates to:
  /// **'Show all {count}'**
  String askShowAll(int count);

  /// The incomplete notice when the lookup budget ran out.
  ///
  /// In en, this message translates to:
  /// **'I ran out of lookups for this question, so this answer may be incomplete.'**
  String get askNoticeLookupBudget;

  /// The incomplete notice when the time budget ran out.
  ///
  /// In en, this message translates to:
  /// **'I ran out of time on this question, so this answer may be incomplete.'**
  String get askNoticeTimeBudget;

  /// The incomplete notice when the provider's extra tool calls were refused.
  ///
  /// In en, this message translates to:
  /// **'I stopped short of the lookups I planned, so this answer may be incomplete.'**
  String get askNoticeToolCallRefused;

  /// The incomplete notice for a reason this build does not know.
  ///
  /// In en, this message translates to:
  /// **'This answer may be incomplete.'**
  String get askNoticeGeneral;

  /// The incomplete notice's second line.
  ///
  /// In en, this message translates to:
  /// **'Ask a narrower follow-up to go further.'**
  String get askNoticeNarrower;

  /// Spoken label of the incomplete notice.
  ///
  /// In en, this message translates to:
  /// **'Notice: this answer may be incomplete. {reason} {advice}'**
  String askNoticeSemantic(String reason, String advice);

  /// Semantics label of the instrument panel.
  ///
  /// In en, this message translates to:
  /// **'Figures for this answer'**
  String get askFigures;

  /// Block label above the ranked bars.
  ///
  /// In en, this message translates to:
  /// **'Worst first'**
  String get askWorstFirst;

  /// Block label above the trend chart.
  ///
  /// In en, this message translates to:
  /// **'Over time'**
  String get askOverTime;

  /// Shown in place of a view spec this build cannot render.
  ///
  /// In en, this message translates to:
  /// **'This answer includes a view your app version cannot draw yet. The summary above still applies.'**
  String get askUnsupportedView;

  /// Why a web-touched turn's panel was dropped.
  ///
  /// In en, this message translates to:
  /// **'Figures are not shown for answers that used the web, because this app version cannot tell which came from outside.'**
  String get askUnprovenancedFigures;

  /// Semantics label of the artifact skeleton.
  ///
  /// In en, this message translates to:
  /// **'Loading figures'**
  String get askLoadingFigures;

  /// Veld has no skeleton — one word instead.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get askLoading;

  /// Replaces a plot with fewer than two readable points.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Not enough data to plot — nothing returned.} =1{Not enough data to plot — 1 period returned.} other{Not enough data to plot — {count} periods returned.}}'**
  String askNotEnoughToPlot(int count);

  /// A comparison was asked for and the earlier window had none.
  ///
  /// In en, this message translates to:
  /// **'no data for {label}'**
  String askNoComparisonData(String label);

  /// The legend names the channel, not the colour.
  ///
  /// In en, this message translates to:
  /// **'solid line'**
  String get askChartSolidLine;

  /// The legend names the channel, not the colour.
  ///
  /// In en, this message translates to:
  /// **'dashed line'**
  String get askChartDashedLine;

  /// Spoken before the plot's summary.
  ///
  /// In en, this message translates to:
  /// **'Legend: {entries}'**
  String askLegend(String entries);

  /// One legend entry, spoken as a name and a stroke pattern.
  ///
  /// In en, this message translates to:
  /// **'{name}, {channel}'**
  String askLegendEntry(String name, String channel);

  /// Spoken label of one ranked bar.
  ///
  /// In en, this message translates to:
  /// **'{name}, {value}, position {index} of {total}'**
  String askBarSemantic(String name, String value, int index, int total);

  /// Appended to the top ranked bar's spoken label.
  ///
  /// In en, this message translates to:
  /// **'worst'**
  String get askBarWorst;

  /// The outside-data band's label.
  ///
  /// In en, this message translates to:
  /// **'Outside data'**
  String get askOutsideData;

  /// When outside data was retrieved.
  ///
  /// In en, this message translates to:
  /// **'read {date}'**
  String askOutsideRead(String date);

  /// The outside-data band's permanent sentence.
  ///
  /// In en, this message translates to:
  /// **'{publisher}, read {date}. Not TradeIQ data, and not added to any total above.'**
  String askOutsidePublisher(String publisher, String date);

  /// The outside-data band when the source names no publisher.
  ///
  /// In en, this message translates to:
  /// **'Read from outside TradeIQ on {date}. Not TradeIQ data, and not added to any total above.'**
  String askOutsideUnnamed(String date);

  /// Appended to the outside-data band when the read date is over a week old.
  ///
  /// In en, this message translates to:
  /// **'{days} days old'**
  String askOutsideStale(int days);

  /// Spoken after the value of an outside figure.
  ///
  /// In en, this message translates to:
  /// **'outside figure'**
  String get askOutsideFigure;

  /// Re-sends the identical question as a new turn.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get askTryAgain;

  /// Appended to a turn the manager stopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped.'**
  String get askStopped;

  /// Spoken when a turn is stopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped. The answer is incomplete.'**
  String get askStoppedSemantic;

  /// Re-sends the question that produced this turn.
  ///
  /// In en, this message translates to:
  /// **'Ask again'**
  String get askAskAgain;

  /// The copy action beneath a settled answer. A phrase, because an icon button's label is read on its own.
  ///
  /// In en, this message translates to:
  /// **'Copy this answer'**
  String get askCopyAnswer;

  /// Toast after copying an answer.
  ///
  /// In en, this message translates to:
  /// **'Answer copied'**
  String get askAnswerCopied;

  /// The re-ask action beneath a settled answer.
  ///
  /// In en, this message translates to:
  /// **'Ask this question again'**
  String get askAskAgainAnswer;

  /// Shown on the second failure of the same question.
  ///
  /// In en, this message translates to:
  /// **'This has failed twice. It may be the connection rather than the question.'**
  String get askFailedTwice;

  /// Spoken severity first, then the message.
  ///
  /// In en, this message translates to:
  /// **'Error. {message}'**
  String askErrorSemantic(String message);

  /// The composer's offline band.
  ///
  /// In en, this message translates to:
  /// **'No connection — Ask TradeIQ needs one.'**
  String get askOffline;

  /// The composer's session-ended band.
  ///
  /// In en, this message translates to:
  /// **'Your session ended. Sign in to ask again.'**
  String get askSessionEnded;

  /// The last clause is spoken because a screen reader cannot see the held work behind the band.
  ///
  /// In en, this message translates to:
  /// **'Your session ended. Sign in to ask again. Your answers are still on screen.'**
  String get askSessionEndedSemantic;

  /// Takes the manager to the auth route and back.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get askSignIn;

  /// The square glyph's label on the offline and session-ended bands — deliberately not a severity.
  ///
  /// In en, this message translates to:
  /// **'Held'**
  String get askHeld;

  /// The history sheet's title.
  ///
  /// In en, this message translates to:
  /// **'This conversation'**
  String get askHistoryTitle;

  /// The history sheet says exactly what it is: a session, not an archive.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Held on this device until you leave the screen. 1 question.} other{Held on this device until you leave the screen. {count} questions.}}'**
  String askHistorySubtitle(int count);

  /// The real history limit, and why a very old follow-up may not land.
  ///
  /// In en, this message translates to:
  /// **'only the last {count} are sent with a new question'**
  String askHistoryLimit(int count);

  /// The history sheet with no turns.
  ///
  /// In en, this message translates to:
  /// **'Nothing yet.'**
  String get askHistoryEmpty;

  /// The history sheet's empty explanation.
  ///
  /// In en, this message translates to:
  /// **'Your questions will be listed here while you are on this screen.'**
  String get askHistoryEmptyBody;

  /// Spoken label of a history row.
  ///
  /// In en, this message translates to:
  /// **'Asked at {time}: {question} Go to this answer.'**
  String askHistoryRowSemantic(String time, String question);

  /// Replaces the time on a turn that is still streaming.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get askNow;

  /// The foot of the history sheet.
  ///
  /// In en, this message translates to:
  /// **'Start a new conversation'**
  String get askStartOver;

  /// The start-over decision sheet's title.
  ///
  /// In en, this message translates to:
  /// **'Start a new conversation?'**
  String get askStartOverTitle;

  /// Names the consequence, specifically.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{This one is not saved. The 1 question and its answer go.} other{This one is not saved. The {count} questions and their answers go.}}'**
  String askStartOverBody(int count);

  /// The safe action, and the primary: carrying on is the expected next move.
  ///
  /// In en, this message translates to:
  /// **'Carry on'**
  String get askCarryOn;

  /// The destructive action, never the lit one.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get askStartOverConfirm;

  /// The start-over sheet while a turn streams.
  ///
  /// In en, this message translates to:
  /// **'A question is still being answered.'**
  String get askStartOverMidTurnTitle;

  /// The consequence of starting over mid-turn.
  ///
  /// In en, this message translates to:
  /// **'Starting over will stop it.'**
  String get askStartOverMidTurnBody;

  /// The safe action while a turn streams.
  ///
  /// In en, this message translates to:
  /// **'Keep waiting'**
  String get askKeepWaiting;

  /// The destructive action while a turn streams.
  ///
  /// In en, this message translates to:
  /// **'Stop and start over'**
  String get askStopAndStartOver;

  /// Expands a question bubble clamped at six lines.
  ///
  /// In en, this message translates to:
  /// **'Show the full question'**
  String get askShowFullQuestion;

  /// Spoken label of a follow-up chip.
  ///
  /// In en, this message translates to:
  /// **'Ask: {question}'**
  String askFollowUpSemantic(String question);

  /// Spoken when a follow-up chip is disabled.
  ///
  /// In en, this message translates to:
  /// **'unavailable while the answer is being written'**
  String get askFollowUpDisabled;

  /// A measured step duration, in the rail.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String askSeconds(String seconds);

  /// The points unit, as a word beside a figure.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{pt} other{pts}}'**
  String askPoints(num count);

  /// Announced before an assistant turn.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get askAnswer;

  /// The row at the foot of a panel block that leads to the full, table-backed view.
  ///
  /// In en, this message translates to:
  /// **'Open full view'**
  String get askOpenFullView;

  /// Names the block the expand row belongs to, rather than saying Open full view three times in one panel.
  ///
  /// In en, this message translates to:
  /// **'Open the full view of {name}'**
  String askOpenFullViewOf(String name);

  /// Toast after long-pressing a question bubble.
  ///
  /// In en, this message translates to:
  /// **'Question copied'**
  String get askQuestionCopied;

  /// The sentence under a stat tile whose figure is unknown. Never a zero, never a hidden tile.
  ///
  /// In en, this message translates to:
  /// **'Nothing measured in this window'**
  String get askTileNoData;

  /// Leads the reconciliation line on a figure the server recomputed while it was on screen.
  ///
  /// In en, this message translates to:
  /// **'Updated to'**
  String get askTileUpdatedTo;

  /// Joins the reconciliation line to the figure the reader saw first.
  ///
  /// In en, this message translates to:
  /// **'from'**
  String get askTileUpdatedFrom;

  /// When the figure was recomputed. A fact, never a fault.
  ///
  /// In en, this message translates to:
  /// **'Updated at {time}.'**
  String askTileUpdatedAt(String time);

  /// A figure that was measured and is now unknown: what it was, and when it stopped being true.
  ///
  /// In en, this message translates to:
  /// **'Was {value} at {time}.'**
  String askTileWasValue(String value, String time);

  /// Ask TradeIQ answer card.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get askPillarSales;

  /// Ask TradeIQ answer card.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get askPillarStock;

  /// Ask TradeIQ answer card.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get askPillarVisibility;

  /// Ask TradeIQ answer card.
  ///
  /// In en, this message translates to:
  /// **'Competition'**
  String get askPillarCompetition;

  /// Ask TradeIQ answer card.
  ///
  /// In en, this message translates to:
  /// **'Pillar figures'**
  String get askPillarFigures;

  /// Ask TradeIQ answer card.
  ///
  /// In en, this message translates to:
  /// **'No figures were returned for this period.'**
  String get askPillarNoFigures;

  /// Ask TradeIQ answer card.
  ///
  /// In en, this message translates to:
  /// **'Change is measured against {label}.'**
  String askPillarComparedWith(String label);

  /// Ask TradeIQ answer card.
  ///
  /// In en, this message translates to:
  /// **'On-shelf availability'**
  String get askMetricOsa;

  /// Ask TradeIQ answer card.
  ///
  /// In en, this message translates to:
  /// **'Share of shelf'**
  String get askMetricShareOfShelf;

  /// Ask TradeIQ answer card.
  ///
  /// In en, this message translates to:
  /// **'Visibility compliance'**
  String get askMetricVisibility;

  /// Ask TradeIQ answer card.
  ///
  /// In en, this message translates to:
  /// **'Price compliance'**
  String get askMetricPrice;

  /// Ask TradeIQ answer card.
  ///
  /// In en, this message translates to:
  /// **'Attainment'**
  String get askMetricAttainment;

  /// Ask TradeIQ answer card.
  ///
  /// In en, this message translates to:
  /// **'Rate of sale'**
  String get askMetricRateOfSale;

  /// Ask TradeIQ answer card.
  ///
  /// In en, this message translates to:
  /// **'Outlets with a stockout'**
  String get askMetricOutletsWithStockout;

  /// Ask TradeIQ answer card.
  ///
  /// In en, this message translates to:
  /// **'Out-of-stock lines'**
  String get askMetricOutOfStockLines;

  /// Ask TradeIQ answer card.
  ///
  /// In en, this message translates to:
  /// **'Lines observed'**
  String get askMetricLinesObserved;

  /// Ask TradeIQ answer card.
  ///
  /// In en, this message translates to:
  /// **'Competitor facings'**
  String get askMetricCompetitorFacings;

  /// A trend chart's title for the execution score metric.
  ///
  /// In en, this message translates to:
  /// **'Execution score'**
  String get askMetricExecutionScore;

  /// A trend chart's title for the perfect-store rate metric.
  ///
  /// In en, this message translates to:
  /// **'Perfect-store rate'**
  String get askMetricPerfectStore;

  /// Ask TradeIQ answer card.
  ///
  /// In en, this message translates to:
  /// **'Agent scorecard'**
  String get askScorecardTitle;

  /// Ask TradeIQ answer card.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 scored visit} other{{count} scored visits}}'**
  String askScorecardScored(int count);

  /// Ask TradeIQ answer card.
  ///
  /// In en, this message translates to:
  /// **'Average score'**
  String get askScorecardAverage;

  /// Ask TradeIQ answer card.
  ///
  /// In en, this message translates to:
  /// **'Team average'**
  String get askScorecardTeam;

  /// Ask TradeIQ answer card.
  ///
  /// In en, this message translates to:
  /// **'No other agent has a scored visit in this period.'**
  String get askScorecardNoTeam;

  /// Ask TradeIQ answer card.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get askScorecardVisits;

  /// Ask TradeIQ answer card.
  ///
  /// In en, this message translates to:
  /// **'Outlets'**
  String get askScorecardOutlets;

  /// Ask TradeIQ answer card.
  ///
  /// In en, this message translates to:
  /// **'vs team'**
  String get askScorecardVsTeam;

  /// Ask TradeIQ answer card.
  ///
  /// In en, this message translates to:
  /// **'Outlets with stockouts'**
  String get askMapTitle;

  /// Ask TradeIQ answer card.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 outlet} other{{count} outlets}}'**
  String askMapCount(int count);

  /// Ask TradeIQ answer card.
  ///
  /// In en, this message translates to:
  /// **'The outlet locations for this answer could not be read. The summary above still applies.'**
  String get askMapUnreadable;

  /// Ask TradeIQ answer card.
  ///
  /// In en, this message translates to:
  /// **'{name}, {count, plural, =1{1 line} other{{count} lines}} out of stock'**
  String askMapPin(String name, int count);

  /// Ask TradeIQ answer card.
  ///
  /// In en, this message translates to:
  /// **'Maps are not drawn in Veld. The outlets are listed instead.'**
  String get askMapNotInVeld;

  /// Too-far screen, beyond the distance where a wrong-pin report is accepted. Replaces the pin action.
  ///
  /// In en, this message translates to:
  /// **'This is too far to report the pin from here. Ask your manager to correct this store.'**
  String get visitPinTooFarToReport;

  /// Block label on the wrong-pin report screen.
  ///
  /// In en, this message translates to:
  /// **'The pin is wrong'**
  String get pinDisputeEyebrow;

  /// Headline of the wrong-pin report screen.
  ///
  /// In en, this message translates to:
  /// **'Report the pin and start the visit'**
  String get pinDisputeTitle;

  /// Block label over the evidence the report carries.
  ///
  /// In en, this message translates to:
  /// **'Sent with your report'**
  String get pinDisputeEvidenceEyebrow;

  /// Beside the measured distance figure on the wrong-pin report.
  ///
  /// In en, this message translates to:
  /// **'from where the app has this shop, measured just now'**
  String get pinDisputeDistanceLine;

  /// Screen-reader label for the distance on the wrong-pin report; unit spelled out.
  ///
  /// In en, this message translates to:
  /// **'You are {meters} metres from where the app has this shop.'**
  String pinDisputeDistanceSemantics(int meters);

  /// Evidence line: the agent position travels with the report.
  ///
  /// In en, this message translates to:
  /// **'Where you are standing, as your phone recorded it'**
  String get pinDisputePositionLine;

  /// Evidence line shown once a storefront photo is attached.
  ///
  /// In en, this message translates to:
  /// **'Your photo of the storefront'**
  String get pinDisputePhotoLine;

  /// Plain statement of what the override does. Must never read as a bypass.
  ///
  /// In en, this message translates to:
  /// **'The visit starts outside the fence and stays flagged. Your manager sees where you were and can move the pin. You cannot clear the flag yourself.'**
  String get pinDisputeExplain;

  /// Label for the optional note on a wrong-pin report.
  ///
  /// In en, this message translates to:
  /// **'What is wrong with the pin? (optional)'**
  String get pinDisputeNoteLabel;

  /// Example text in the wrong-pin note field.
  ///
  /// In en, this message translates to:
  /// **'e.g. the pin is on the depot, the shop is on Main Road'**
  String get pinDisputeNoteHint;

  /// Optional action: attach a storefront photo as evidence.
  ///
  /// In en, this message translates to:
  /// **'Add a photo of the storefront'**
  String get pinDisputeAddPhoto;

  /// Replace the attached storefront photo.
  ///
  /// In en, this message translates to:
  /// **'Retake the photo'**
  String get pinDisputeRetakePhoto;

  /// Confirmation once a storefront photo is attached.
  ///
  /// In en, this message translates to:
  /// **'Storefront photo added. It is sent with the visit.'**
  String get pinDisputePhotoAdded;

  /// Title of the capture screen for the storefront photo.
  ///
  /// In en, this message translates to:
  /// **'Storefront'**
  String get pinDisputePhotoLabel;

  /// Framing hint on the storefront capture screen.
  ///
  /// In en, this message translates to:
  /// **'Stand back far enough to get the shop name and the door in one shot.'**
  String get pinDisputePhotoHint;

  /// Primary on the wrong-pin report: starts the visit outside the fence, flagged for review.
  ///
  /// In en, this message translates to:
  /// **'Start the visit, flagged'**
  String get pinDisputeSubmit;

  /// Leaves the report and returns to the too-far screen.
  ///
  /// In en, this message translates to:
  /// **'Back to the distance'**
  String get pinDisputeBack;

  /// Shown when starting the flagged visit failed on the phone.
  ///
  /// In en, this message translates to:
  /// **'The visit could not start: {reason}'**
  String pinDisputeFailed(String reason);

  /// Flag chip word: this visit was checked in outside the geofence.
  ///
  /// In en, this message translates to:
  /// **'Out of fence'**
  String get visitFlagOutOfFence;

  /// The distance detail in the out-of-fence flag chip.
  ///
  /// In en, this message translates to:
  /// **'{meters} m'**
  String visitFlagMetres(int meters);

  /// Screen-reader label for the out-of-fence flag chip.
  ///
  /// In en, this message translates to:
  /// **'Out of fence, {meters} metres. Double-tap for detail.'**
  String visitFlagOutOfFenceSemantics(int meters);

  /// Flag chip word: the agent reported this store's pin as wrong; it is for review.
  ///
  /// In en, this message translates to:
  /// **'Pin reported'**
  String get visitFlagPinReported;

  /// Screen-reader label for the pin-reported flag chip.
  ///
  /// In en, this message translates to:
  /// **'Pin reported, for your manager to review. Double-tap for detail.'**
  String get visitFlagPinReportedSemantics;

  /// Title of the sheet explaining the override flags.
  ///
  /// In en, this message translates to:
  /// **'Checked in outside the fence'**
  String get visitFlagSheetTitle;

  /// Body of the sheet explaining the override flags.
  ///
  /// In en, this message translates to:
  /// **'You were {meters} m from this store’s pin and reported the pin as wrong. Your position and distance went with the visit. Your manager reviews it and can move the pin; the flag stays until they do.'**
  String visitFlagSheetBody(int meters);

  /// The affirmative state word beside a toggle. Never the only signal.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get wordYes;

  /// The negative state word beside a toggle.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get wordNo;

  /// The inline save on every capture section — the only control that persists the section.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get sectionSave;

  /// The thumb zone's action on a capture section: save, then return to the visit hub.
  ///
  /// In en, this message translates to:
  /// **'Save and go back'**
  String get sectionSaveAndBack;

  /// Headline when a section save failed. The values are untouched.
  ///
  /// In en, this message translates to:
  /// **'Not saved'**
  String get sectionSaveFailedTitle;

  /// Body of the failed-save line. Names the work’s safety first.
  ///
  /// In en, this message translates to:
  /// **'Your answers are still here — try Save again.'**
  String get sectionSaveFailedBody;

  /// Ghost action beneath the save, opening the skip-reason picker.
  ///
  /// In en, this message translates to:
  /// **'Can\'t confirm this section'**
  String get sectionCantConfirm;

  /// Headline of the skip-reason sheet.
  ///
  /// In en, this message translates to:
  /// **'Why not?'**
  String get sectionCantConfirmWhy;

  /// The locked section’s line, naming the reason the agent gave.
  ///
  /// In en, this message translates to:
  /// **'Can\'t confirm: {reason}'**
  String sectionCantConfirmLocked(String reason);

  /// Honest note under a can’t-confirm reason: the wire has no field for it yet.
  ///
  /// In en, this message translates to:
  /// **'Held on this phone. Nothing is sent for this yet.'**
  String get sectionCantConfirmHeld;

  /// Ghost action that unlocks a section the agent marked can’t-confirm.
  ///
  /// In en, this message translates to:
  /// **'I can confirm it after all'**
  String get sectionCanConfirmAfterAll;

  /// Why the thumb zone’s save is unavailable on a locked section.
  ///
  /// In en, this message translates to:
  /// **'This section is marked can\'t confirm'**
  String get sectionLockedBlock;

  /// Title of the sheet shown when leaving a dirty section.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved answers'**
  String get sectionLeaveTitle;

  /// The ghost that leaves a dirty section without saving.
  ///
  /// In en, this message translates to:
  /// **'Go back without saving'**
  String get sectionLeaveWithoutSaving;

  /// The tertiary that dismisses the leaving-dirty sheet.
  ///
  /// In en, this message translates to:
  /// **'Stay here'**
  String get sectionStayHere;

  /// The ghost beneath a repeating card set.
  ///
  /// In en, this message translates to:
  /// **'Add another'**
  String get sectionAddAnother;

  /// An entry’s place in a repeating card set, in mono.
  ///
  /// In en, this message translates to:
  /// **'{index} of {total}'**
  String sectionEntryPosition(int index, int total);

  /// Semantic label of a repeating entry’s remove control.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} {position}'**
  String sectionRemoveEntry(String name, String position);

  /// What a choice row with nothing selected says. Nothing-selected is a state.
  ///
  /// In en, this message translates to:
  /// **'Not answered yet'**
  String get sectionNotAnsweredYet;

  /// The pre-capture card’s action, handing off to the OS camera.
  ///
  /// In en, this message translates to:
  /// **'Open camera'**
  String get sectionPhotoOpenCamera;

  /// Semantic label of the pre-capture card’s action.
  ///
  /// In en, this message translates to:
  /// **'Open the camera to photograph the shelf'**
  String get sectionPhotoOpenCameraSemantics;

  /// The framing instruction on the pre-capture card.
  ///
  /// In en, this message translates to:
  /// **'Stand back far enough to get the whole bay, including the price rail.'**
  String get sectionPhotoFraming;

  /// What the app records with a capture. Stated, never hidden.
  ///
  /// In en, this message translates to:
  /// **'Your photo is stamped with the time and where you are.'**
  String get sectionPhotoStamped;

  /// Shown when the aisle is likely dark. TORCH is never an amber block.
  ///
  /// In en, this message translates to:
  /// **'Aisle dark? Switch your phone torch on before you shoot.'**
  String get sectionPhotoTorchHint;

  /// What a captured photo is doing before the visit sends.
  ///
  /// In en, this message translates to:
  /// **'Held on this phone · sends with the visit'**
  String get sectionPhotoHeld;

  /// Camera-unavailable state. The section stays completable without a photo.
  ///
  /// In en, this message translates to:
  /// **'This phone has no camera we can reach.'**
  String get sectionPhotoNoCamera;

  /// The device-side size cap, in a sentence an agent can act on.
  ///
  /// In en, this message translates to:
  /// **'That photo is too big to send. Take it again.'**
  String get sectionPhotoTooLarge;

  /// Handoff failure, stated here rather than on a lost route.
  ///
  /// In en, this message translates to:
  /// **'The camera did not hand the photo back. Try again.'**
  String get sectionPhotoFailed;

  /// Semantic label of the photo’s remove control.
  ///
  /// In en, this message translates to:
  /// **'Remove the photo'**
  String get sectionPhotoRemoveSemantics;

  /// Semantic label of the captured photo tile.
  ///
  /// In en, this message translates to:
  /// **'Photo taken {time}, held on this phone'**
  String sectionPhotoSemantics(String time);

  /// Skip reason: the store refused.
  ///
  /// In en, this message translates to:
  /// **'The store would not let me'**
  String get skipReasonStoreRefused;

  /// What the store-refused reason does downstream.
  ///
  /// In en, this message translates to:
  /// **'The manager is told the store refused'**
  String get skipReasonStoreRefusedConsequence;

  /// Skip reason: the outlet does not stock these lines.
  ///
  /// In en, this message translates to:
  /// **'They do not stock this'**
  String get skipReasonNotStocked;

  /// What the not-stocked reason does downstream.
  ///
  /// In en, this message translates to:
  /// **'These lines are marked not-stocked for this outlet'**
  String get skipReasonNotStockedConsequence;

  /// Skip reason: the equipment needed is unavailable.
  ///
  /// In en, this message translates to:
  /// **'The equipment is broken'**
  String get skipReasonEquipment;

  /// What the broken-equipment reason does downstream.
  ///
  /// In en, this message translates to:
  /// **'A repair task is raised'**
  String get skipReasonEquipmentConsequence;

  /// Skip reason: none of the three fits, and the agent writes what happened.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get skipReasonSomethingElse;

  /// What the something-else reason requires.
  ///
  /// In en, this message translates to:
  /// **'You write what happened'**
  String get skipReasonSomethingElseConsequence;

  /// The skip sheet’s commit action.
  ///
  /// In en, this message translates to:
  /// **'Save reason'**
  String get skipReasonSave;

  /// The skip sheet’s commit action when a reason is already set.
  ///
  /// In en, this message translates to:
  /// **'Change reason'**
  String get skipReasonChange;

  /// The skip sheet’s ghost. Dismissal is always safe.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get skipReasonCancel;

  /// Label of the required note under “Something else”.
  ///
  /// In en, this message translates to:
  /// **'What happened?'**
  String get skipReasonNoteLabel;

  /// Why the skip sheet’s commit is unavailable.
  ///
  /// In en, this message translates to:
  /// **'Choose a reason first'**
  String get skipReasonChooseFirst;

  /// Why the skip sheet’s commit is unavailable with “Something else” chosen.
  ///
  /// In en, this message translates to:
  /// **'Say what happened'**
  String get skipReasonSayWhatHappened;

  /// The sticky summary rule under the stock header. A live region.
  ///
  /// In en, this message translates to:
  /// **'{counted} counted · {outOfStock} out of stock · {toGo} to go'**
  String s2Summary(int counted, int outOfStock, int toGo);

  /// A SKU nobody has reached yet. Never spoken as “zero”.
  ///
  /// In en, this message translates to:
  /// **'Not counted'**
  String get s2NotCounted;

  /// The finding word beside a zero count.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get s2OutOfStockWord;

  /// Opens the number sheet, so a stray tap can never replace a count.
  ///
  /// In en, this message translates to:
  /// **'Type a count'**
  String get s2TypeCount;

  /// The stepper’s decrease action, named by what it does.
  ///
  /// In en, this message translates to:
  /// **'One fewer'**
  String get s2OneFewer;

  /// The stepper’s increase action, named by what it does.
  ///
  /// In en, this message translates to:
  /// **'One more'**
  String get s2OneMore;

  /// What a part-finished stock save does. #410 made null a first-class count.
  ///
  /// In en, this message translates to:
  /// **'Saving now records {toGo} products as not counted — never as empty.'**
  String s2PartCounted(int toGo);

  /// How far the stock count has got, on the sticky rule’s semantics.
  ///
  /// In en, this message translates to:
  /// **'{counted} of {total} counted'**
  String s2CountedOf(int counted, int total);

  /// The saved line after a part-finished stock count. Names how many were saved and that the others travel as not counted (null), never as zero.
  ///
  /// In en, this message translates to:
  /// **'Saved {counted} of {total} — the rest are not counted, never empty'**
  String s2StockSavedPartial(int counted, int total);

  /// Ghost in the sticky stock summary, shown past 12 products while any is uncounted. Scrolls to the first product with no count.
  ///
  /// In en, this message translates to:
  /// **'Jump to the first uncounted'**
  String get s2JumpToUncounted;

  /// The agent app never shows a provisional score as though it were final.
  ///
  /// In en, this message translates to:
  /// **'Worked out on this phone. The final score comes back when the visit sends.'**
  String get s10NotFinal;

  /// A dimension with nothing behind it. An em dash, a hatch and this reason.
  ///
  /// In en, this message translates to:
  /// **'Not measured on this visit'**
  String get s10NotMeasured;

  /// The hero when no dimension was measured. An em dash and this sentence, never a zero in the Gap band.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been captured on this visit yet, so there is no score to work out.'**
  String get s10NothingCaptured;

  /// The scorecard hero read aloud when nothing was measured.
  ///
  /// In en, this message translates to:
  /// **'No weighted total yet. Nothing has been captured on this visit.'**
  String get s10NoScoreSemantics;

  /// The scorecard hero read aloud.
  ///
  /// In en, this message translates to:
  /// **'Weighted total {score} out of 100, {band}'**
  String s10ScoreSemantics(String score, String band);

  /// A SKU the agent has not priced. Untouched SKUs are not sent.
  ///
  /// In en, this message translates to:
  /// **'No price entered'**
  String get s5NoPriceYet;

  /// The competitive section’s empty line. An empty shelf is a real outcome.
  ///
  /// In en, this message translates to:
  /// **'No competitor on this shelf yet. Add one if you see it.'**
  String get s6NoCompetitors;

  /// The risks section’s empty line.
  ///
  /// In en, this message translates to:
  /// **'Nothing flagged yet.'**
  String get s8NoRisks;

  /// The action plan’s empty line.
  ///
  /// In en, this message translates to:
  /// **'No extra tasks yet.'**
  String get s9NoTasks;

  /// How many manual tasks this visit has raised.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 task queued for sync} other{{count} tasks queued for sync}}'**
  String s9AddedTasks(int count);

  /// Why the number sheet's Set is disabled: nothing valid has been typed.
  ///
  /// In en, this message translates to:
  /// **'Type a count first'**
  String get s2TypeCountFirst;

  /// The name of one entry in a repeating list, at the start of its header row ('Competitor 2 of 3').
  ///
  /// In en, this message translates to:
  /// **'{kind, select, competitor{Competitor} risk{Risk} other{Task}}'**
  String sectionEntryName(String kind);

  /// The same entry name mid-sentence, for the remove control ('Remove competitor 2 of 3').
  ///
  /// In en, this message translates to:
  /// **'{kind, select, competitor{competitor} risk{risk} other{task}}'**
  String sectionEntryNameLower(String kind);

  /// An entry's header line before the agent has typed what it is.
  ///
  /// In en, this message translates to:
  /// **'Not named yet'**
  String get sectionEntryUnnamed;

  /// The action inside the My work summary block. A ghost by default — the queue sends itself — and the screen’s one amber block only when something is stuck.
  ///
  /// In en, this message translates to:
  /// **'Send now'**
  String get myWorkSendNow;

  /// Why "Send now" is off. A disabled primary always names what is missing.
  ///
  /// In en, this message translates to:
  /// **'Nothing is waiting to send.'**
  String get myWorkSendNowBlocked;

  /// The signed-out block above the My work summary. The only state where the amber moves off "Send now".
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{You’re signed out. Sign in and your 1 held capture will send.} other{You’re signed out. Sign in and your {count} held captures will send.}}'**
  String myWorkSignedOutTitle(int count);

  /// The signed-out block’s action.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get myWorkSignIn;

  /// Ghost action under the capped Sent list.
  ///
  /// In en, this message translates to:
  /// **'Show older'**
  String get myWorkShowOlder;

  /// The Sent group is capped so a long outbox does not become a scroll. Says what it is showing and out of how many.
  ///
  /// In en, this message translates to:
  /// **'Showing the {shown} most recently sent of {total}'**
  String myWorkSentCapped(int shown, int total);

  /// The empty My work screen. Says what the screen is for rather than apologising.
  ///
  /// In en, this message translates to:
  /// **'Everything you capture in a store shows up here until the server has it.'**
  String get myWorkEmptyBody;

  /// Body of the My work load-error state. The outbox failing to READ is not the outbox failing to hold.
  ///
  /// In en, this message translates to:
  /// **'Your work is still on this phone. Nothing is lost.'**
  String get myWorkLoadErrorBody;

  /// Reads the outbox again after a failed read. The captures themselves were never in doubt — only the reading of them.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get myWorkRetry;

  /// Outbox row state word: queued, waiting for signal. Never an error.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get outboxWaiting;

  /// Outbox row state word: bytes are moving.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get outboxSending;

  /// Outbox row state word: a failed attempt that will clear itself.
  ///
  /// In en, this message translates to:
  /// **'Retrying'**
  String get outboxRetrying;

  /// Outbox row state word: the server has it.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get outboxSent;

  /// Outbox row state word for the one severity-bearing state, and the severity in words beside the crimson bar.
  ///
  /// In en, this message translates to:
  /// **'Needs you'**
  String get outboxNeedsYou;

  /// Outbox row state word: blocked on the visit above it. An ordering dependency, explicitly not a fault.
  ///
  /// In en, this message translates to:
  /// **'Waiting its turn'**
  String get outboxWaitingTurn;

  /// The queued state as a sentence.
  ///
  /// In en, this message translates to:
  /// **'Waiting for signal'**
  String get outboxWaitingSentence;

  /// The sending state as a sentence.
  ///
  /// In en, this message translates to:
  /// **'Going up now'**
  String get outboxSendingSentence;

  /// The sent state as a sentence.
  ///
  /// In en, this message translates to:
  /// **'The server has it'**
  String get outboxSentSentence;

  /// The age line on a queued outbox row. {time} is a clock time.
  ///
  /// In en, this message translates to:
  /// **'queued {time}'**
  String outboxQueuedAt(String time);

  /// The age line on a sent outbox row.
  ///
  /// In en, this message translates to:
  /// **'sent {time}'**
  String outboxSentAt(String time);

  /// The age line on a retrying or stuck outbox row. The real last attempt, never an invented next-try time.
  ///
  /// In en, this message translates to:
  /// **'last tried {time}'**
  String outboxLastTriedAt(String time);

  /// How many send attempts this capture has had, in the sheet’s identifier block.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Not tried yet} =1{Tried once} other{Tried {count} times}}'**
  String outboxAttempts(int count);

  /// The sheet action that flushes exactly this capture and nothing else.
  ///
  /// In en, this message translates to:
  /// **'Send this one now'**
  String get outboxSendThisNow;

  /// The sheet action that throws a stuck capture away. Always behind a second step.
  ///
  /// In en, this message translates to:
  /// **'Discard this capture'**
  String get outboxDiscard;

  /// The confirming press on the discard sheet.
  ///
  /// In en, this message translates to:
  /// **'Yes, discard it'**
  String get outboxDiscardConfirm;

  /// The way out of the discard confirm.
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get outboxDiscardKeep;

  /// Said plainly before anything is thrown away (#376). {item} is the capture’s own name, e.g. "Stock count".
  ///
  /// In en, this message translates to:
  /// **'This {item} has not reached the server. Discard it and it is gone from this phone — there is no copy anywhere else.'**
  String outboxDiscardWhatIsLost(String item);

  /// Added to the discard statement when the capture is a visit: its sections, photos and submit cannot send without it, so they are removed too. Said before the agent confirms (#376).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 capture from this visit goes with it, because it cannot send without the visit.} other{{count} captures from this visit go with it, because they cannot send without the visit.}}'**
  String outboxDiscardTakesDependents(int count);

  /// The sent state’s sheet. A sent row is still tappable, and it says so.
  ///
  /// In en, this message translates to:
  /// **'Nothing to do — the server has it.'**
  String get outboxNothingToDo;

  /// Shown on a rejected or too-large capture. The app never repairs a rejected payload behind the agent’s back (#376).
  ///
  /// In en, this message translates to:
  /// **'The server refused this exactly as it is, so sending it again unchanged will fail the same way. Nothing has been altered for you.'**
  String get outboxRejectedNote;

  /// The ordering dependency, said in the sheet so it is never read as a fault.
  ///
  /// In en, this message translates to:
  /// **'This sends itself as soon as the visit above it does. Nothing is wrong.'**
  String get outboxWaitingTurnNote;

  /// The sheet's note for a capture held because the session ended. Its fix has nothing to do with the capture, and it is held, never stuck.
  ///
  /// In en, this message translates to:
  /// **'Your session ended. Sign in and this sends itself.'**
  String get outboxSignedOutNote;

  /// Outbox row state word for a capture held because the session ended. Held is the normal state (unify §1.13): an Oatmeal square and this word, never crimson and never 'Needs you'.
  ///
  /// In en, this message translates to:
  /// **'Held'**
  String get outboxHeld;

  /// The row sentence for a capture held because the session ended, and My work's summary sentence when that is why the queue is held. Signing in sends it; nothing is wrong with the capture.
  ///
  /// In en, this message translates to:
  /// **'Held until you sign in'**
  String get outboxHeldUntilSignIn;

  /// The identifier block in the outbox sheet, in mono. For a support call.
  ///
  /// In en, this message translates to:
  /// **'Capture {id} · {type}'**
  String outboxItemId(int id, String type);

  /// The picker with an empty list.
  ///
  /// In en, this message translates to:
  /// **'No stores here'**
  String get pickerEmptyTitle;

  /// The picker’s empty state while it is narrowed. Names both ways out.
  ///
  /// In en, this message translates to:
  /// **'Nothing is filed under your territories yet. Switch to all stores, or add the one you are standing in.'**
  String get pickerEmptyBodyMine;

  /// The picker’s empty state with the widest scope. The list is genuinely empty, not filtered.
  ///
  /// In en, this message translates to:
  /// **'This client has no stores on the server yet. Add the one you are standing in.'**
  String get pickerEmptyBodyAll;

  /// Body of the picker’s load-error state. A list that will not load is not work that is lost.
  ///
  /// In en, this message translates to:
  /// **'Your stores are fetched from the server. Nothing you have captured is affected.'**
  String get pickerLoadErrorBody;

  /// Section rule above the picker’s scope control.
  ///
  /// In en, this message translates to:
  /// **'Which stores'**
  String get pickerScopeHeading;

  /// Section rule above the picker’s list.
  ///
  /// In en, this message translates to:
  /// **'Stores'**
  String get pickerStoresHeading;

  /// The trailing half of the held banner’s screen-reader label.
  ///
  /// In en, this message translates to:
  /// **'tap to open your work'**
  String get syncBannerOpen;

  /// The Veld Close row on a bottom sheet — in Veld a sheet is a full-screen route and needs a way out that is not a scrim tap.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// One picker row as a screen reader hears it — the store, its code, and what tapping does.
  ///
  /// In en, this message translates to:
  /// **'{name}, {code}. Double-tap to start a visit here.'**
  String pickerStartVisitSemantics(String name, String code);

  /// The needs-you banner’s state WORD, without the count. The band renders the figure itself in mono and keeps the count out of the live region — a count inside a live label interrupts an agent once per capture.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{needs you} other{need you}}'**
  String syncBannerNeedsYou(int count);

  /// Shared error copy for a 429: the server's rate limit. Retrying at once only spends another attempt.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a few minutes, then try again.'**
  String get errorTooManyAttempts;

  /// Shared error copy for a 426 from the server's minimum-version gate.
  ///
  /// In en, this message translates to:
  /// **'This version of the app is too old. Update TradeIQ to carry on.'**
  String get errorUpdateRequired;

  /// Help under every new-password field. Mirrors backend/src/lib/passwordPolicy.ts.
  ///
  /// In en, this message translates to:
  /// **'At least 12 characters. Three ordinary words are easy to type and hard to guess.'**
  String get passwordRuleHelp;

  /// Field error: the new password is under 12 characters (spaces at either end do not count).
  ///
  /// In en, this message translates to:
  /// **'Too short: use at least 12 characters.'**
  String get passwordTooShort;

  /// Field error: over 72 bytes, bcrypt's ceiling.
  ///
  /// In en, this message translates to:
  /// **'Too long for a password here. Use fewer characters.'**
  String get passwordTooLong;

  /// Field error.
  ///
  /// In en, this message translates to:
  /// **'Your password cannot be your email address.'**
  String get passwordIsEmail;

  /// Field error on the confirm field.
  ///
  /// In en, this message translates to:
  /// **'The two new passwords do not match.'**
  String get passwordMismatch;

  /// Field error when the server refuses the new password (e.g. a common one).
  ///
  /// In en, this message translates to:
  /// **'That password was not accepted. Use at least 12 characters, not your email address and not an obvious phrase.'**
  String get passwordRejected;

  /// Checkbox that reveals every password field on the screen.
  ///
  /// In en, this message translates to:
  /// **'Show passwords'**
  String get passwordShow;

  /// Why the primary is disabled: no new password yet.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password'**
  String get passwordNeedsNew;

  /// Why the primary is disabled: the confirm field is empty.
  ///
  /// In en, this message translates to:
  /// **'Type the new password again'**
  String get passwordNeedsConfirm;

  /// Headline of an inline failure on the password screens.
  ///
  /// In en, this message translates to:
  /// **'Your password was not changed'**
  String get passwordFailedTitle;

  /// Said after every password change: the server cannot end other sessions.
  ///
  /// In en, this message translates to:
  /// **'Other phones signed in to your account stay signed in until their session ends, up to 12 hours. If a phone is lost, ask your manager to switch the account off.'**
  String get passwordOtherSessions;

  /// Title of the forgot-password screen.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get forgotTitle;

  /// Semantic label of the back button on the forgot-password screen.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get forgotBack;

  /// How the field reset works. There is no email reset.
  ///
  /// In en, this message translates to:
  /// **'Ask your manager for a reset code. They make it in TradeIQ and read it out to you. It works once, for 15 minutes.'**
  String get forgotIntro;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get forgotEmailLabel;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Reset code'**
  String get forgotCodeLabel;

  /// Hint in the reset-code field: its format.
  ///
  /// In en, this message translates to:
  /// **'8 digits'**
  String get forgotCodeHint;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get forgotNewPasswordLabel;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'New password again'**
  String get forgotConfirmLabel;

  /// Primary on the forgot-password screen.
  ///
  /// In en, this message translates to:
  /// **'Set new password'**
  String get forgotSubmit;

  /// Why the primary is disabled.
  ///
  /// In en, this message translates to:
  /// **'Enter your email first'**
  String get forgotNeedsEmail;

  /// Why the primary is disabled.
  ///
  /// In en, this message translates to:
  /// **'Enter the 8-digit code from your manager'**
  String get forgotNeedsCode;

  /// Headline when the server refuses the code. Deliberately says nothing about whether the account exists.
  ///
  /// In en, this message translates to:
  /// **'That code did not work'**
  String get forgotCodeRejectedTitle;

  /// Body when the server refuses the code.
  ///
  /// In en, this message translates to:
  /// **'It may be mistyped, used already or older than 15 minutes. Check the email too. Your manager can make a new code.'**
  String get forgotCodeRejectedBody;

  /// Headline after a successful reset.
  ///
  /// In en, this message translates to:
  /// **'Your password is changed'**
  String get forgotDoneTitle;

  /// Body after a successful reset.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your new password.'**
  String get forgotDoneBody;

  /// Primary after a successful reset.
  ///
  /// In en, this message translates to:
  /// **'Go to sign in'**
  String get forgotGoToSignIn;

  /// Title of the change-password screen, and the settings entry that opens it.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePasswordTitle;

  /// Semantic label of the back button on the change-password screen.
  ///
  /// In en, this message translates to:
  /// **'Back to settings'**
  String get changePasswordBack;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get changeCurrentLabel;

  /// Why the primary is disabled.
  ///
  /// In en, this message translates to:
  /// **'Enter your current password'**
  String get changeNeedsCurrent;

  /// Field error when the server says the current password is wrong.
  ///
  /// In en, this message translates to:
  /// **'That is not your current password.'**
  String get changeWrongCurrent;

  /// Headline after a successful change.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get changeDoneTitle;

  /// Body after a successful change.
  ///
  /// In en, this message translates to:
  /// **'You stay signed in on this phone. Use the new password next time you sign in.'**
  String get changeDoneBody;

  /// Primary after a successful change.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get changeDone;

  /// Section heading on the settings screen, above Change password.
  ///
  /// In en, this message translates to:
  /// **'Your account'**
  String get settingsAccountHeading;

  /// Title of the too-old-version screen.
  ///
  /// In en, this message translates to:
  /// **'Update TradeIQ'**
  String get updateTitle;

  /// Body of the too-old-version screen.
  ///
  /// In en, this message translates to:
  /// **'This version of the app is too old for the server. Install the newest version from where you got TradeIQ, then open it again.'**
  String get updateBody;

  /// Reassurance on the too-old-version screen. It is true: the screen deletes nothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing saved on this phone is deleted by this.'**
  String get updateNothingLost;

  /// Primary on the too-old-version screen: clears the state and asks the server again.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get updateTryAgain;

  /// Which build this is and what the server needs.
  ///
  /// In en, this message translates to:
  /// **'This phone has version {current}. Version {minimum} or newer is needed.'**
  String updateVersions(String current, String minimum);

  /// When the server did not say which version it needs.
  ///
  /// In en, this message translates to:
  /// **'This phone has version {current}. A newer version is needed.'**
  String updateVersionNoMinimum(String current);

  /// Submit gate captured block, in place of the section count, when the visit's sections could not be read. Never a zero.
  ///
  /// In en, this message translates to:
  /// **'Could not read which sections are done'**
  String get submitSectionsUnread;

  /// Row on the submit gate's list when the visit's sections could not be read.
  ///
  /// In en, this message translates to:
  /// **'Your sections could not be read'**
  String get submitSectionsUnreadTask;

  /// Second line of the sections-could-not-be-read row on the submit gate.
  ///
  /// In en, this message translates to:
  /// **'Something may be missing from this list'**
  String get submitSectionsUnreadRowLine;

  /// Sentence under the submit gate's list when the visit's sections could not be read.
  ///
  /// In en, this message translates to:
  /// **'A section that could not be confirmed may be missing from this list. Go back and open your sections to check before you submit.'**
  String get submitSectionsUnreadNote;

  /// Screen-reader line for the submit gate's captured block when the sections could not be read.
  ///
  /// In en, this message translates to:
  /// **'Could not read which sections are done. {line}'**
  String submitCapturedUnreadSemantics(String line);

  /// Shown instead of a delta on the visit outcome when the score loaded but the history request failed. Whether there was an earlier visit is unknown, so this never claims a first visit.
  ///
  /// In en, this message translates to:
  /// **'Your last visit here could not be loaded, so there is nothing to compare this score with.'**
  String get outcomePreviousUnknown;

  /// Ghost action on the outbox sheet for a submitted visit the server has: opens that visit's outcome again.
  ///
  /// In en, this message translates to:
  /// **'See how it scored'**
  String get outboxSeeScore;

  /// Title of the agent's own record — their visits and what they have earned. Nav slot 4.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get meTitle;

  /// Section rule above the reward bar, the points cluster and the ledger.
  ///
  /// In en, this message translates to:
  /// **'What I\'ve earned'**
  String get meEarnedHeading;

  /// Section rule above the agent's own visit list.
  ///
  /// In en, this message translates to:
  /// **'My visits'**
  String get meVisitsHeading;

  /// Section rule above the points ledger rows.
  ///
  /// In en, this message translates to:
  /// **'How you earned it'**
  String get meLedgerHeading;

  /// Stat tile label. Uppercase; the component does not upper-case it for you. `/gamification/me` is read with no from/to, so the figure is the agent's whole record and the label says so — see DioMyRecordRepository.myEarnings.
  ///
  /// In en, this message translates to:
  /// **'POINTS ALL TIME'**
  String get mePointsEyebrow;

  /// The header fact under 'Me': the period every figure on this screen covers. It is the agent's whole record, because the incentive payout engine has no period either.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get meAllTime;

  /// Stat tile label for the agent's place in the standings.
  ///
  /// In en, this message translates to:
  /// **'RANK'**
  String get meRankEyebrow;

  /// Body of an inline load error on the agent's own record. Names the work's safety first.
  ///
  /// In en, this message translates to:
  /// **'Your work is safe on this phone. This part comes from the server and fills in when it answers.'**
  String get meLoadErrorDetail;

  /// Sentence in place of a rank figure, shown when the server returns rank: null. An em dash alone is a puzzle. The only caller with no rank is one who is not a field agent — /me is open to managers — so the sentence names that rather than guessing at a thin board.
  ///
  /// In en, this message translates to:
  /// **'Only field agents are ranked, so you do not have a place on this board.'**
  String get meNotRanked;

  /// Sentence under a null points figure.
  ///
  /// In en, this message translates to:
  /// **'No points yet. Points arrive when a visit is submitted or a task is closed.'**
  String get meNoPointsYet;

  /// Body line in place of the progress bar. An empty bar would read as zero progress, which is a different and false statement.
  ///
  /// In en, this message translates to:
  /// **'No reward is running.'**
  String get meNoScheme;

  /// The fraction beside the reward bar.
  ///
  /// In en, this message translates to:
  /// **'{value} of {total}'**
  String meRewardProgress(String value, String total);

  /// The line always beneath the reward bar. Never the bar alone.
  ///
  /// In en, this message translates to:
  /// **'{remaining} to go · {reward}'**
  String meRewardToGo(String remaining, String reward);

  /// Line beneath a completed reward bar. Nothing flashes and nothing celebrates.
  ///
  /// In en, this message translates to:
  /// **'Reward reached — {reward}.'**
  String meRewardReached(String reward);

  /// What a scheme pays out, when it has no reward detail in words.
  ///
  /// In en, this message translates to:
  /// **'{points, plural, =1{1 point} other{{points} points}}'**
  String meRewardPoints(int points);

  /// The honesty line under the ledger. Read aloud, never skipped.
  ///
  /// In en, this message translates to:
  /// **'Points are worked out on the server. They can change if a visit is reviewed.'**
  String get mePointsHonesty;

  /// Empty line on the ledger section rule.
  ///
  /// In en, this message translates to:
  /// **'Nothing has earned points yet.'**
  String get meLedgerEmpty;

  /// Whole-screen empty headline when the agent has no visits at all.
  ///
  /// In en, this message translates to:
  /// **'No visits yet'**
  String get meVisitsEmpty;

  /// Body of the empty state.
  ///
  /// In en, this message translates to:
  /// **'Every store you check into shows up here — when you went, how long you stayed, and what it scored.'**
  String get meVisitsEmptyDetail;

  /// Headline when GET /visits/me fails.
  ///
  /// In en, this message translates to:
  /// **'Your visits did not load'**
  String get meVisitsLoadError;

  /// In place of a score on a visit the server has not scored. Never a bare em dash.
  ///
  /// In en, this message translates to:
  /// **'Waiting to be scored'**
  String get meNotScoredYet;

  /// Meta line for a visit that was never submitted.
  ///
  /// In en, this message translates to:
  /// **'Still open on this phone'**
  String get meVisitOpen;

  /// The meta line on a visit row: day, dwell, tasks raised.
  ///
  /// In en, this message translates to:
  /// **'{day} · {dwell} · {tasks}'**
  String meVisitMeta(String day, String dwell, String tasks);

  /// Dwell time in the shop, in minutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String meDwellMinutes(int minutes);

  /// In place of a dwell figure when the device never stamped a submit time. Not zero.
  ///
  /// In en, this message translates to:
  /// **'time not recorded'**
  String get meDwellUnknown;

  /// How many tasks a visit raised. A measured zero is said in words, never hidden.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{no tasks raised} =1{1 task raised} other{{count} tasks raised}}'**
  String meTasksRaised(int count);

  /// What the agent captured on a visit — the evidence half of the proof.
  ///
  /// In en, this message translates to:
  /// **'{captured} of {total} sections · {photos, plural, =0{no photos} =1{1 photo} other{{photos} photos}}'**
  String meCapturedCount(int captured, int total, int photos);

  /// How far the check-in landed from the outlet's pin.
  ///
  /// In en, this message translates to:
  /// **'{metres} m from the door'**
  String meDistanceMeters(int metres);

  /// When the phone had no usable fix. Not zero metres.
  ///
  /// In en, this message translates to:
  /// **'distance not measured'**
  String get meDistanceUnknown;

  /// Flag chip word on a check-in outside the geofence. A fact, not a verdict, and never crimson.
  ///
  /// In en, this message translates to:
  /// **'Out of fence'**
  String get meOutOfFence;

  /// Flag chip word when a manager has ruled on this visit.
  ///
  /// In en, this message translates to:
  /// **'Reviewed'**
  String get meReviewed;

  /// Said on one of the agent's own visits that they started by reporting the outlet's pin as wrong (#386). Their own act, in their words; not a flag and not a verdict.
  ///
  /// In en, this message translates to:
  /// **'You reported the pin as wrong'**
  String get mePinReported;

  /// Standalone row above the visit list when work is still held on the device.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 capture has not sent} other{{count} captures have not sent}}'**
  String meOnThisPhone(int count);

  /// Second line of the on-this-phone row.
  ///
  /// In en, this message translates to:
  /// **'Showing what has reached the server. Today\'s work appears here once it sends.'**
  String get meOnThisPhoneDetail;

  /// The whole visit row as one screen-reader sentence.
  ///
  /// In en, this message translates to:
  /// **'{outlet}, {day}, {dwell}, {tasks}, {score}'**
  String meVisitSemantics(
    String outlet,
    String day,
    String tasks,
    String dwell,
    String score,
  );

  /// The score half of a visit row's sentence.
  ///
  /// In en, this message translates to:
  /// **'scored {score}'**
  String meScoredSemantics(String score);

  /// The reward bar as one node.
  ///
  /// In en, this message translates to:
  /// **'Progress to reward: {value} of {total}. {line}'**
  String meRewardSemantics(String value, String total, String line);

  /// One ledger row as a sentence. Direction is the word, never the triangle alone.
  ///
  /// In en, this message translates to:
  /// **'{reason}, {day}, {points}'**
  String meLedgerRowSemantics(String reason, String day, String points);

  /// A positive ledger entry, in words.
  ///
  /// In en, this message translates to:
  /// **'{points, plural, =1{plus 1 point} other{plus {points} points}}'**
  String mePointsPlus(int points);

  /// A reversal, in words.
  ///
  /// In en, this message translates to:
  /// **'{points, plural, =1{minus 1 point} other{minus {points} points}}'**
  String mePointsMinus(int points);

  /// Headline when the earnings read fails. The visit list is a separate region with its own retry.
  ///
  /// In en, this message translates to:
  /// **'Your points did not load'**
  String get meEarningsLoadError;

  /// Ledger row reason. The wire sends the machine value `visit_submitted`; this is the agent's word for it.
  ///
  /// In en, this message translates to:
  /// **'Visit submitted'**
  String get meReasonVisitSubmitted;

  /// Ledger row reason for the wire value `task_closed`.
  ///
  /// In en, this message translates to:
  /// **'Task closed'**
  String get meReasonTaskClosed;

  /// Ledger row reason for the wire value `scorecard`. A scorecard earns no points of its own; it contributes a score to the average.
  ///
  /// In en, this message translates to:
  /// **'Scorecard'**
  String get meReasonScorecard;

  /// Ledger row reason when the wire sends no reason at all.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get meReasonPoints;

  /// The whole spoken sentence for a scorecard ledger row. It contributed a score to the average rather than points, so it never says 'plus 0 points'.
  ///
  /// In en, this message translates to:
  /// **'{reason}, {day}, scored {score}'**
  String meLedgerScoreRowSemantics(String reason, String day, String score);

  /// Second line of the Contests row on Me when no contest is running. The row replaced the Contests nav slot; with contests running it shows the running count instead.
  ///
  /// In en, this message translates to:
  /// **'See where you stand'**
  String get meContestsDetail;

  /// The one retry verb, wherever a region offers one.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get torchTryAgain;

  /// The line a skeleton shows after ten seconds, so an 8s stall does not read as frozen.
  ///
  /// In en, this message translates to:
  /// **'Still fetching · this is slower than usual'**
  String get torchStillFetching;

  /// A person's role, on a person row.
  ///
  /// In en, this message translates to:
  /// **'Field agent'**
  String get roleFieldAgent;

  /// Screen title: the manager's list of territories.
  ///
  /// In en, this message translates to:
  /// **'Territories'**
  String get territoriesTitle;

  /// The header fact under the Territories title.
  ///
  /// In en, this message translates to:
  /// **'A territory groups outlets and the agents who work them.'**
  String get territoriesFact;

  /// Semantic label of the header's refresh button. Names what it does, never just 'Refresh'.
  ///
  /// In en, this message translates to:
  /// **'Refresh the territories list'**
  String get territoriesRefresh;

  /// Section rule above the list of territories.
  ///
  /// In en, this message translates to:
  /// **'All territories'**
  String get territoriesSectionAll;

  /// The verb that opens the create form, in the section rule's action slot.
  ///
  /// In en, this message translates to:
  /// **'New territory'**
  String get territoriesNew;

  /// Whole-screen empty state: the client has no territories at all.
  ///
  /// In en, this message translates to:
  /// **'No territories yet'**
  String get territoriesEmptyHeadline;

  /// Body under territoriesEmptyHeadline.
  ///
  /// In en, this message translates to:
  /// **'A territory groups outlets and the agents who work them. Create one and outlets can be assigned to it.'**
  String get territoriesEmptyBody;

  /// How many outlets are in a territory.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No outlets} =1{1 outlet} other{{count} outlets}}'**
  String territoryOutlets(int count);

  /// How many agents are assigned to a territory.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No agents} =1{1 agent} other{{count} agents}}'**
  String territoryAgents(int count);

  /// The word under a coverage percentage.
  ///
  /// In en, this message translates to:
  /// **'Covered'**
  String get territoryCoveredWord;

  /// The coverage figure as a sentence, for a screen reader.
  ///
  /// In en, this message translates to:
  /// **'{percent}% covered'**
  String territoryCoveredPercent(int percent);

  /// A row's coverage request is still in flight. Never a zero.
  ///
  /// In en, this message translates to:
  /// **'Loading coverage'**
  String get territoryCoverageLoading;

  /// A row's coverage request failed. An em dash and this sentence, never a zero.
  ///
  /// In en, this message translates to:
  /// **'Coverage did not load'**
  String get territoryCoverageFailed;

  /// There is nothing to take a percentage of. The wire sends 0 here and a nought over an empty denominator is a verdict nobody reached.
  ///
  /// In en, this message translates to:
  /// **'No outlets to cover yet'**
  String get territoryCoverageNoOutlets;

  /// A territory with no agents on it.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get territoryUnassigned;

  /// The sentence under an agent count of zero.
  ///
  /// In en, this message translates to:
  /// **'Nobody works this territory yet.'**
  String get territoryUnassignedLine;

  /// Semantic label of the coverage figures in the territory sheet.
  ///
  /// In en, this message translates to:
  /// **'Coverage for this territory'**
  String get territoryCoverageCluster;

  /// Eyebrow over the outlet count, and the section rule over the outlet list.
  ///
  /// In en, this message translates to:
  /// **'Outlets'**
  String get territoryOutletsWord;

  /// Eyebrow over the agent count.
  ///
  /// In en, this message translates to:
  /// **'Agents'**
  String get territoryAgentsWord;

  /// The state line under a coverage percentage.
  ///
  /// In en, this message translates to:
  /// **'{visited} of {total} visited in this window'**
  String territoryVisitedOf(int total, int visited);

  /// A header fact on the territory map: how many of its outlets were visited.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{None visited} =1{1 visited} other{{count} visited}}'**
  String territoryVisitedCount(int count);

  /// Opens one territory's map from its sheet.
  ///
  /// In en, this message translates to:
  /// **'Open the map'**
  String get territoryOpenMap;

  /// Opens the roster, and commits the assignment once one is picked.
  ///
  /// In en, this message translates to:
  /// **'Assign an agent'**
  String get territoryAssign;

  /// Title of the roster pane in the territory sheet.
  ///
  /// In en, this message translates to:
  /// **'Assign to {territory}'**
  String territoryAssignTitle(String territory);

  /// Subtitle of the roster pane.
  ///
  /// In en, this message translates to:
  /// **'Pick a field agent to work this territory.'**
  String get territoryAssignSubtitle;

  /// Section rule over the roster.
  ///
  /// In en, this message translates to:
  /// **'Field agents'**
  String get territoryFieldAgents;

  /// The word on the agent row the manager has selected.
  ///
  /// In en, this message translates to:
  /// **'Picked'**
  String get territoryAgentPicked;

  /// The word on a deactivated agent's row, which cannot be picked.
  ///
  /// In en, this message translates to:
  /// **'No longer active'**
  String get territoryAgentInactive;

  /// Why the Assign button is disabled.
  ///
  /// In en, this message translates to:
  /// **'Pick a field agent first.'**
  String get territoryAssignBlocked;

  /// Returns the sheet to its evidence pane.
  ///
  /// In en, this message translates to:
  /// **'Back to coverage'**
  String get territoryAssignBack;

  /// Toast after a successful assignment.
  ///
  /// In en, this message translates to:
  /// **'Assigned to {territory}.'**
  String territoryAssignDone(String territory);

  /// Toast after a failed assignment. The honest half is that nothing changed.
  ///
  /// In en, this message translates to:
  /// **'That agent was not assigned. Nothing changed.'**
  String get territoryAssignFailed;

  /// The roster is empty.
  ///
  /// In en, this message translates to:
  /// **'No field agents yet'**
  String get territoryNoAgentsHeadline;

  /// Body under territoryNoAgentsHeadline.
  ///
  /// In en, this message translates to:
  /// **'Add a field agent under Users, then assign them here.'**
  String get territoryNoAgentsBody;

  /// Title of the create-territory screen.
  ///
  /// In en, this message translates to:
  /// **'New territory'**
  String get territoryNewTitle;

  /// Header fact on the create form.
  ///
  /// In en, this message translates to:
  /// **'A code is what the back office quotes. It must be unique for this client.'**
  String get territoryNewFact;

  /// The back button's spoken label. Names the destination, never just 'Back'.
  ///
  /// In en, this message translates to:
  /// **'Back to territories'**
  String get territoryBackToList;

  /// Field label: the territory's name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get territoryNameLabel;

  /// Help under the name field.
  ///
  /// In en, this message translates to:
  /// **'What people call this patch — Gauteng North.'**
  String get territoryNameHelp;

  /// Field label: the territory's code.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get territoryCodeLabel;

  /// Help under the code field.
  ///
  /// In en, this message translates to:
  /// **'The short code outlets are filed under — GP-N.'**
  String get territoryCodeHelp;

  /// Field label: the optional region.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get territoryRegionLabel;

  /// Help under the region field.
  ///
  /// In en, this message translates to:
  /// **'Optional. The wider area this sits in.'**
  String get territoryRegionHelp;

  /// Validation message on an empty required field.
  ///
  /// In en, this message translates to:
  /// **'This is required.'**
  String get territoryFieldRequired;

  /// The commit button on the create form.
  ///
  /// In en, this message translates to:
  /// **'Create territory'**
  String get territoryCreate;

  /// Why the create button is disabled.
  ///
  /// In en, this message translates to:
  /// **'A name and a code are both required.'**
  String get territoryCreateBlocked;

  /// Toast after a territory is created.
  ///
  /// In en, this message translates to:
  /// **'{territory} created.'**
  String territoryCreated(String territory);

  /// Title of the territory map route while the territory itself is still being resolved.
  ///
  /// In en, this message translates to:
  /// **'Territory map'**
  String get territoryMapTitle;

  /// Designed state: the territory exists and nothing is filed under it.
  ///
  /// In en, this message translates to:
  /// **'No outlets in this territory'**
  String get territoryMapEmptyHeadline;

  /// Body under territoryMapEmptyHeadline.
  ///
  /// In en, this message translates to:
  /// **'Outlets are filed under a territory by its code. Give an outlet this territory\'s code and it appears here.'**
  String get territoryMapEmptyBody;

  /// Body when the basemap tiles never arrived. Not an error: the list carries everything.
  ///
  /// In en, this message translates to:
  /// **'The map did not load, so {territory} is listed below instead. Every store and its state is there.'**
  String territoryTilesOffBody(String territory);

  /// A store somebody has been to in this window.
  ///
  /// In en, this message translates to:
  /// **'Visited'**
  String get territoryOutletVisited;

  /// A store nobody has been to in this window.
  ///
  /// In en, this message translates to:
  /// **'Not visited yet'**
  String get territoryOutletNotVisited;

  /// The sentence under the visited state in the outlet sheet.
  ///
  /// In en, this message translates to:
  /// **'A visit landed here inside the coverage window.'**
  String get territoryOutletVisitedLine;

  /// The sentence under the not-visited state in the outlet sheet.
  ///
  /// In en, this message translates to:
  /// **'No visit has landed here inside the coverage window.'**
  String get territoryOutletNotVisitedLine;

  /// Label before an outlet's coordinates.
  ///
  /// In en, this message translates to:
  /// **'Pinned at'**
  String get territoryOutletPosition;

  /// The id in the URL matches nothing this client can see.
  ///
  /// In en, this message translates to:
  /// **'We could not find that territory'**
  String get territoryNotFoundHeadline;

  /// Body under territoryNotFoundHeadline.
  ///
  /// In en, this message translates to:
  /// **'It may have been deleted, or the link may belong to another client.'**
  String get territoryNotFoundBody;

  /// Screen title: ranking agents for one outlet.
  ///
  /// In en, this message translates to:
  /// **'Dispatch'**
  String get dispatchTitle;

  /// Header fact on Dispatch.
  ///
  /// In en, this message translates to:
  /// **'Agents are ranked in-territory first, then by distance from their last known location.'**
  String get dispatchFact;

  /// Section rule over the outlet picker.
  ///
  /// In en, this message translates to:
  /// **'The outlet'**
  String get dispatchOutletSection;

  /// The picker's title when nothing is chosen.
  ///
  /// In en, this message translates to:
  /// **'Choose an outlet'**
  String get dispatchChooseOutlet;

  /// Why an outlet has to be chosen first.
  ///
  /// In en, this message translates to:
  /// **'Ranking needs a destination to measure distance from.'**
  String get dispatchChooseOutletHint;

  /// Spoken label of the picker once an outlet is chosen.
  ///
  /// In en, this message translates to:
  /// **'Outlet: {outlet}. Choose a different one.'**
  String dispatchChangeOutlet(String outlet);

  /// In-panel empty state before an outlet is chosen.
  ///
  /// In en, this message translates to:
  /// **'Pick an outlet to rank agents'**
  String get dispatchNoOutletHeadline;

  /// Body under dispatchNoOutletHeadline.
  ///
  /// In en, this message translates to:
  /// **'Nobody can be ranked until there is somewhere to rank them against.'**
  String get dispatchNoOutletBody;

  /// The outlet list came back empty.
  ///
  /// In en, this message translates to:
  /// **'No outlets yet'**
  String get dispatchNoOutletsHeadline;

  /// Body under dispatchNoOutletsHeadline.
  ///
  /// In en, this message translates to:
  /// **'Add an outlet and it can be dispatched.'**
  String get dispatchNoOutletsBody;

  /// Section rule over the ranked agents.
  ///
  /// In en, this message translates to:
  /// **'Candidates'**
  String get dispatchCandidatesSection;

  /// The server returned no candidates.
  ///
  /// In en, this message translates to:
  /// **'No agent can be ranked'**
  String get dispatchNoCandidatesHeadline;

  /// Body under dispatchNoCandidatesHeadline.
  ///
  /// In en, this message translates to:
  /// **'Ranking needs agents assigned to a territory, or a last known location — neither is recorded yet.'**
  String get dispatchNoCandidatesBody;

  /// This agent's territory contains the outlet.
  ///
  /// In en, this message translates to:
  /// **'In territory'**
  String get dispatchInTerritory;

  /// This agent's territory does not contain the outlet.
  ///
  /// In en, this message translates to:
  /// **'Outside territory'**
  String get dispatchOutsideTerritory;

  /// The server's own pick. Never a rank this screen computed.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get dispatchRecommended;

  /// The unit under a distance figure.
  ///
  /// In en, this message translates to:
  /// **'metres away'**
  String get dispatchMetresUnit;

  /// The server cannot place this agent. Never a zero — an agent with no fix must not look like one on the doorstep.
  ///
  /// In en, this message translates to:
  /// **'No last-known location'**
  String get dispatchNoLocation;

  /// The short form under the em dash where a distance would be.
  ///
  /// In en, this message translates to:
  /// **'not placed'**
  String get dispatchNoLocationShort;

  /// Screen title: the manager's trend charts.
  ///
  /// In en, this message translates to:
  /// **'Trends'**
  String get trendsTitle;

  /// Header fact on Trends.
  ///
  /// In en, this message translates to:
  /// **'Server-side buckets — weeks start Monday, UTC.'**
  String get trendsFact;

  /// Spoken label of the filter rail scoping every chart.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get trendsFilters;

  /// The view showing three series over the window.
  ///
  /// In en, this message translates to:
  /// **'Over time'**
  String get trendsOverTime;

  /// The view comparing every territory against the client average.
  ///
  /// In en, this message translates to:
  /// **'Compare territories'**
  String get trendsCompare;

  /// The day bucket.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get trendsDaily;

  /// The week bucket.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get trendsWeekly;

  /// No range was asked for. Null is not 'all time' — it is the server's own lookback.
  ///
  /// In en, this message translates to:
  /// **'Server default'**
  String get trendsServerDefault;

  /// A range the manager chose.
  ///
  /// In en, this message translates to:
  /// **'Custom range'**
  String get trendsCustomRange;

  /// Drops back to the server's default lookback.
  ///
  /// In en, this message translates to:
  /// **'Clear the range'**
  String get trendsClearRange;

  /// Spoken label of the chart-or-table toggle.
  ///
  /// In en, this message translates to:
  /// **'Show as'**
  String get trendsViewAs;

  /// Show the series as a chart.
  ///
  /// In en, this message translates to:
  /// **'Chart'**
  String get trendsAsChart;

  /// Show the series as its table twin.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get trendsAsTable;

  /// First column of the table twin.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get trendsPeriod;

  /// A bucket with no reading. Never a zero.
  ///
  /// In en, this message translates to:
  /// **'Not measured'**
  String get trendsNotMeasured;

  /// How to reach the scrub readout. Everything it shows is also in the table.
  ///
  /// In en, this message translates to:
  /// **'Drag across the chart to read one bucket.'**
  String get trendsScrubHint;

  /// Spoken label of a chart. The values live in the table, not in a paragraph read at 200 words a minute.
  ///
  /// In en, this message translates to:
  /// **'{name}, {count} buckets. The exact figures are in the table view.'**
  String trendsChartHint(String name, int count);

  /// How many buckets broke the line.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 bucket not measured} other{{count} buckets not measured}}'**
  String trendsGapNote(int count);

  /// Designed state: the window measured nothing.
  ///
  /// In en, this message translates to:
  /// **'No data in range'**
  String get trendsEmptyHeadline;

  /// Body under trendsEmptyHeadline.
  ///
  /// In en, this message translates to:
  /// **'Trends fill in as visits are submitted and scored.'**
  String get trendsEmptyBody;

  /// Section rule over the scorecard series.
  ///
  /// In en, this message translates to:
  /// **'Scorecard trend'**
  String get trendScorecards;

  /// The scorecard series' name in its legend.
  ///
  /// In en, this message translates to:
  /// **'Weighted execution score'**
  String get trendScorecardsSeries;

  /// Section rule over the availability series.
  ///
  /// In en, this message translates to:
  /// **'Availability trend'**
  String get trendAvailability;

  /// The availability series' name in its legend.
  ///
  /// In en, this message translates to:
  /// **'On-shelf availability'**
  String get trendAvailabilitySeries;

  /// Section rule over the perfect-store series.
  ///
  /// In en, this message translates to:
  /// **'Perfect store trend'**
  String get trendPerfectStore;

  /// The perfect-store series' name in its legend.
  ///
  /// In en, this message translates to:
  /// **'Outlets passing every gate'**
  String get trendPerfectStoreSeries;

  /// Spoken label of the metric rail.
  ///
  /// In en, this message translates to:
  /// **'Metric'**
  String get trendsMetric;

  /// The scorecard metric.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get trendsMetricScore;

  /// The perfect-store metric.
  ///
  /// In en, this message translates to:
  /// **'Perfect store'**
  String get trendsMetricPerfectStore;

  /// The availability metric.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get trendsMetricAvailability;

  /// The share-of-shelf metric.
  ///
  /// In en, this message translates to:
  /// **'Share of shelf'**
  String get trendsMetricShareOfShelf;

  /// The client's own line, which every territory is read against.
  ///
  /// In en, this message translates to:
  /// **'Client average'**
  String get trendsClientAverage;

  /// The client's configured standard, when the wire names none.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get trendsTarget;

  /// Why the client average can differ from the territories' own.
  ///
  /// In en, this message translates to:
  /// **'Also includes {samples} from outlets outside every territory.'**
  String trendsUnassignedNote(String samples);

  /// There is nothing to compare.
  ///
  /// In en, this message translates to:
  /// **'No territories set up'**
  String get trendsNoTerritoriesHeadline;

  /// Body under trendsNoTerritoriesHeadline.
  ///
  /// In en, this message translates to:
  /// **'Add territories and each one can be read against the client average.'**
  String get trendsNoTerritoriesBody;

  /// Body when the client average itself was never measured.
  ///
  /// In en, this message translates to:
  /// **'The comparison fills in as visits are submitted and scored.'**
  String get trendsCompareEmptyBody;

  /// This territory sits above the client average.
  ///
  /// In en, this message translates to:
  /// **'Above average'**
  String get trendsAboveAverage;

  /// This territory sits below the client average. A watch, not a breach — sitting under your own average is not failing a threshold.
  ///
  /// In en, this message translates to:
  /// **'Below average'**
  String get trendsBelowAverage;

  /// This territory is level with the client average.
  ///
  /// In en, this message translates to:
  /// **'At average'**
  String get trendsAtAverage;

  /// The note under a territory above the line.
  ///
  /// In en, this message translates to:
  /// **'{points} points above the client average · {samples}'**
  String trendsAboveBy(String points, String samples);

  /// The note under a territory below the line.
  ///
  /// In en, this message translates to:
  /// **'{points} points below the client average · {samples}'**
  String trendsBelowBy(String points, String samples);

  /// The note under a territory on the line.
  ///
  /// In en, this message translates to:
  /// **'Level with the client average · {samples}'**
  String trendsLevelWith(String samples);

  /// The note under a territory with no reading.
  ///
  /// In en, this message translates to:
  /// **'Nothing measured in this window'**
  String get trendsNothingMeasuredHere;

  /// A territory's rank, spoken.
  ///
  /// In en, this message translates to:
  /// **'Ranked {rank}'**
  String trendsRank(int rank);

  /// The server could not rank this territory. A rank is never invented.
  ///
  /// In en, this message translates to:
  /// **'Not ranked'**
  String get trendsUnranked;

  /// The word on the territory row whose series the chart is drawing.
  ///
  /// In en, this message translates to:
  /// **'Showing'**
  String get trendsShowing;

  /// Section rule over the comparison chart.
  ///
  /// In en, this message translates to:
  /// **'{territory} against the client average'**
  String trendsAgainstClient(String territory);

  /// Spoken value of a territory's meter.
  ///
  /// In en, this message translates to:
  /// **'{territory}: {value}, client average {average}'**
  String trendsMeterHint(String territory, int value, int average);

  /// How many scorecards are behind a figure.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 scorecard} other{{count} scorecards}}'**
  String trendsSamplesScorecards(int count);

  /// How many stock lines are behind a figure.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 stock line} other{{count} stock lines}}'**
  String trendsSamplesStockLines(int count);

  /// How many visits with facings are behind a figure.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 visit with facings} other{{count} visits with facings}}'**
  String trendsSamplesFacings(int count);
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
      <String>['af', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'af':
      return AppLocalizationsAf();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
