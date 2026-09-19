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
  /// **'Capture'**
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

  /// Snackbar after tapping 'Forgot password?'.
  ///
  /// In en, this message translates to:
  /// **'Password reset is not available yet.'**
  String get loginPasswordResetUnavailable;

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

  /// The one stuck state whose fix has nothing to do with the capture.
  ///
  /// In en, this message translates to:
  /// **'Your session ended. Sign in and this sends itself.'**
  String get outboxSignedOutNote;

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
