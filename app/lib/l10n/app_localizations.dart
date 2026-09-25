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

  /// Whole-screen empty state: nobody planned a route for this agent today. The agent surface names this headline word for word, and it is a whole-screen DISPLAY headline under the line-count fitting rule — at 40/600 the longer wording ran to two lines and took the fold with it.
  ///
  /// In en, this message translates to:
  /// **'No route today'**
  String get todayNoRouteTitle;

  /// Whole-screen empty state: a plan EXISTS for today but has no stops on it. A distinct fact from having no plan at all, so it gets its own headline rather than sharing the no-plan one.
  ///
  /// In en, this message translates to:
  /// **'Your plan is empty'**
  String get todayEmptyPlanTitle;

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

  /// The collapsed form of the location notice. It is the last sentence of locationNoticeBody, word for word: the one line that makes the notice honest stays on screen when the rest of it is folded away. Never reworded independently of the body.
  ///
  /// In en, this message translates to:
  /// **'Nothing is sent in the background.'**
  String get locationNoticeSummary;

  /// Location notice, collapsed: opens the full notice and the two answers in place.
  ///
  /// In en, this message translates to:
  /// **'Read what is shared'**
  String get locationNoticeExpand;

  /// Location notice, expanded: folds it back to the one-line banner. The notice stays unanswered either way.
  ///
  /// In en, this message translates to:
  /// **'Close this'**
  String get locationNoticeCollapse;

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

  /// Screen-reader label for the back control on the agent’s Contests view when there is a screen to return to.
  ///
  /// In en, this message translates to:
  /// **'Back to Me'**
  String get contestsBackToMe;

  /// Screen-reader label for the back control on the agent’s Contests view reached by a deep link.
  ///
  /// In en, this message translates to:
  /// **'Back to Today'**
  String get contestsBackToToday;

  /// Stat tile label above the agent’s place in a contest. Sentence case; the tile uppercases it for display.
  ///
  /// In en, this message translates to:
  /// **'Your rank'**
  String get contestRankEyebrow;

  /// Stat tile label above the agent’s points in a contest. Sentence case; the tile uppercases it for display.
  ///
  /// In en, this message translates to:
  /// **'Your points'**
  String get contestPointsEyebrow;

  /// How many agents the contest ranks, beneath the agent’s own rank.
  ///
  /// In en, this message translates to:
  /// **'{total, plural, =1{of 1 agent} other{of {total} agents}}'**
  String contestRankOutOf(int total);

  /// Shown under the Standings rule when a contest has no ranked agents.
  ///
  /// In en, this message translates to:
  /// **'Nobody has earned points yet.'**
  String get contestNobodyRanked;

  /// The state word beside a toggle that is switched on.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get wordOn;

  /// The state word beside a toggle that is switched off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get wordOff;

  /// Screen-reader label for the back control on the agent’s notification settings when there is a screen to return to.
  ///
  /// In en, this message translates to:
  /// **'Back to Me'**
  String get notificationsBackToMe;

  /// Screen-reader label for the back control on the agent’s notification settings reached by a deep link.
  ///
  /// In en, this message translates to:
  /// **'Back to Today'**
  String get notificationsBackToToday;

  /// Section marker above the notification toggles.
  ///
  /// In en, this message translates to:
  /// **'What reaches this phone'**
  String get notificationsHeading;

  /// Headline above the sign-in failure. Deliberately says nothing about WHY — a message that distinguished a wrong password from an unknown address would turn this form into a way to ask the server who works here.
  ///
  /// In en, this message translates to:
  /// **'We could not sign you in'**
  String get loginFailedTitle;

  /// Title of the console's overflow sheet, opened from the nav's Menu slot.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menuTitle;

  /// Subtitle of the menu sheet.
  ///
  /// In en, this message translates to:
  /// **'Everything the four tabs do not hold.'**
  String get menuSubtitle;

  /// Section rule above the menu sheet's housekeeping rows: brightness, password, sign out.
  ///
  /// In en, this message translates to:
  /// **'This app'**
  String get menuThisApp;

  /// Menu row that switches the app to its light theme. Names the state it switches TO, never the one it is in.
  ///
  /// In en, this message translates to:
  /// **'Light theme'**
  String get menuThemeLight;

  /// Menu row that switches the app to its dark theme. Names the state it switches TO.
  ///
  /// In en, this message translates to:
  /// **'Dark theme'**
  String get menuThemeDark;

  /// Menu row to the change-password screen.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get menuChangePassword;

  /// The menu sheet's way out of the app. Held work stays on the phone.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get menuSignOut;

  /// Name of the nav group holding the day's work: the floor, tasks, alerts, orders, outlets.
  ///
  /// In en, this message translates to:
  /// **'Operate'**
  String get navGroupOperate;

  /// Name of the nav group holding the reading surfaces: Ask, reports, trends, contests.
  ///
  /// In en, this message translates to:
  /// **'Insight'**
  String get navGroupInsight;

  /// Name of the nav group holding setup: rules, territories, users, templates.
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get navGroupConfigure;

  /// Nav destination: the manager's home screen.
  ///
  /// In en, this message translates to:
  /// **'The Floor'**
  String get navTheFloor;

  /// Nav destination: the KPI overview.
  ///
  /// In en, this message translates to:
  /// **'Execution overview'**
  String get navExecutionOverview;

  /// The floating bottom bar's first slot — the manager's home (/dashboard). Short on purpose: the rail and the menu sheet call the same route 'The Floor', but five slots share a phone's width on one line.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Nav destination: the task worklist.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get navTasks;

  /// Nav destination: the alert worklist.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get navAlerts;

  /// Nav destination: orders captured in store.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get navOrders;

  /// Nav destination: the agents' planned routes.
  ///
  /// In en, this message translates to:
  /// **'Beat plans'**
  String get navBeatPlans;

  /// Nav destination: live dispatch.
  ///
  /// In en, this message translates to:
  /// **'Dispatch'**
  String get navDispatch;

  /// Nav destination: messages between managers and agents.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get navMessages;

  /// Nav destination: the outlet list.
  ///
  /// In en, this message translates to:
  /// **'Outlets'**
  String get navOutlets;

  /// Nav destination: the assistant. A product name; usually left untranslated except for the verb.
  ///
  /// In en, this message translates to:
  /// **'Ask TradeIQ'**
  String get navAskTradeIq;

  /// Nav destination: reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get navReports;

  /// Nav destination: trend charts.
  ///
  /// In en, this message translates to:
  /// **'Trends'**
  String get navTrends;

  /// Nav destination: sales targets.
  ///
  /// In en, this message translates to:
  /// **'Sales targets'**
  String get navSalesTargets;

  /// Nav destination: the agent leaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get navLeaderboard;

  /// Nav destination: contests.
  ///
  /// In en, this message translates to:
  /// **'Contests'**
  String get navContests;

  /// Nav destination: the fraud review queue.
  ///
  /// In en, this message translates to:
  /// **'Fraud review'**
  String get navFraudReview;

  /// Nav destination: campaigns.
  ///
  /// In en, this message translates to:
  /// **'Campaigns'**
  String get navCampaigns;

  /// Nav destination: the rules that raise alerts.
  ///
  /// In en, this message translates to:
  /// **'Alert rules'**
  String get navAlertRules;

  /// Nav destination: territories.
  ///
  /// In en, this message translates to:
  /// **'Territories'**
  String get navTerritories;

  /// Nav destination: user administration.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get navUsers;

  /// Nav destination: audit templates.
  ///
  /// In en, this message translates to:
  /// **'Audit templates'**
  String get navAuditTemplates;

  /// Nav destination: incentives.
  ///
  /// In en, this message translates to:
  /// **'Incentives'**
  String get navIncentives;

  /// Nav destination: outgoing webhooks. A technical term, left as is.
  ///
  /// In en, this message translates to:
  /// **'Webhooks'**
  String get navWebhooks;

  /// Nav destination: the client's scoring configuration.
  ///
  /// In en, this message translates to:
  /// **'Scoring config'**
  String get navScoringConfig;

  /// Title of the session-ended sheet. A state, not an error: no triangle, no crimson, no word 'error'.
  ///
  /// In en, this message translates to:
  /// **'You have been signed out'**
  String get sessionEndedTitle;

  /// Body of the session-ended sheet. Names the work's safety before it names the session.
  ///
  /// In en, this message translates to:
  /// **'Everything you captured is still on this phone. It sends itself when you sign in.'**
  String get sessionEndedBody;

  /// Primary action on the session-ended sheet.
  ///
  /// In en, this message translates to:
  /// **'Sign in to send them'**
  String get sessionEndedSignIn;

  /// Secondary action on the session-ended sheet. Leaves the held line under the header.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get sessionEndedNotNow;

  /// Opens the proof block again from the held line under the sign-in header.
  ///
  /// In en, this message translates to:
  /// **'What is held'**
  String get sessionHeldWhatIsHeld;

  /// One line of the session-ended proof block: how many of one kind of capture are held. 'kind' comes from the outbox's own vocabulary (Photo, Stock count, Submitted visit).
  ///
  /// In en, this message translates to:
  /// **'{count} × {kind}'**
  String sessionHeldEntry(int count, String kind);

  /// The line under the sign-in header after 'Not now'. Oatmeal and a square, never crimson — being signed out with held work is a state with one action attached, not a fault.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 capture is waiting to send.} other{{count} captures are waiting to send.}}'**
  String sessionHeldWaiting(int count);

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
  String territoryVisitedOf(int visited, int total);

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

  /// How far the server last saw this agent from the outlet.
  ///
  /// In en, this message translates to:
  /// **'{metres} m away'**
  String dispatchMetresAway(int metres);

  /// The server cannot place this agent. Never a zero — an agent with no fix must not look like one on the doorstep.
  ///
  /// In en, this message translates to:
  /// **'No last-known location'**
  String get dispatchNoLocation;

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

  /// The word a screen reader hears for a dashed legend swatch. The dash is the second channel the legend carries, so it is spoken as well as drawn.
  ///
  /// In en, this message translates to:
  /// **'dashed'**
  String get trendsDashed;

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

  /// Stands in for the above/below verdict on a territory whose figure came from too few rows. A delta never stands beside a sample this thin.
  ///
  /// In en, this message translates to:
  /// **'Small sample'**
  String get trendsSmallSample;

  /// Replaces the delta sentence on a territory row whose sample is below the metric's threshold.
  ///
  /// In en, this message translates to:
  /// **'Too few to compare · {samples}'**
  String trendsTooFewToCompare(String samples);

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

  /// Title of the manager's outlet list route.
  ///
  /// In en, this message translates to:
  /// **'Stores'**
  String get outletsTitle;

  /// Header fact on the outlet list: why the coordinate state is the row's status.
  ///
  /// In en, this message translates to:
  /// **'A store without coordinates cannot be geofenced.'**
  String get outletsSubtitle;

  /// Semantic label of the refresh icon button in the outlet list header.
  ///
  /// In en, this message translates to:
  /// **'Reload the store list'**
  String get outletsRefresh;

  /// Label of the nav circle that opens the create-store form from the outlet list.
  ///
  /// In en, this message translates to:
  /// **'Add a store'**
  String get outletsCreateStore;

  /// Section rule above the list of outlets.
  ///
  /// In en, this message translates to:
  /// **'Stores'**
  String get outletsSectionHeading;

  /// Severity word on an outlet row whose coordinates are unset. Reads in greyscale beside the crimson bar.
  ///
  /// In en, this message translates to:
  /// **'No location'**
  String get outletsNoLocation;

  /// Subtitle of an outlet row that has no usable coordinates.
  ///
  /// In en, this message translates to:
  /// **'No coordinates on file'**
  String get outletsNoCoordinates;

  /// Word for an outlet that does have usable coordinates.
  ///
  /// In en, this message translates to:
  /// **'Placed'**
  String get outletsPlaced;

  /// Whole-screen empty state on the outlet list.
  ///
  /// In en, this message translates to:
  /// **'No stores yet.'**
  String get outletsEmptyHeadline;

  /// Body of the outlet list's empty state.
  ///
  /// In en, this message translates to:
  /// **'Add a store to put it on a beat plan.'**
  String get outletsEmptyBody;

  /// Headline of the outlet list's error state.
  ///
  /// In en, this message translates to:
  /// **'The store list did not load.'**
  String get outletsLoadErrorHeadline;

  /// Retry action on the outlet list's error state.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get outletsRetry;

  /// Section rule above the outlets whose pin an agent has reported as wrong.
  ///
  /// In en, this message translates to:
  /// **'Open pin reports'**
  String get outletsPinReportsHeading;

  /// Sentence under the open pin reports section rule.
  ///
  /// In en, this message translates to:
  /// **'Agents who could not check in where the pin says the store is.'**
  String get outletsPinReportsNote;

  /// Severity word on a row standing for an open pin report.
  ///
  /// In en, this message translates to:
  /// **'Pin reported'**
  String get outletsPinReported;

  /// Subtitle of an open pin report row: who reported it and how far they were from the pin.
  ///
  /// In en, this message translates to:
  /// **'{agent} stood {distance} away'**
  String outletsPinReportStood(String agent, String distance);

  /// Title of the outlet detail route, where a wrong pin is corrected.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get outletDetailTitle;

  /// Semantic label of the outlet detail back button. Names the destination, never 'Back'.
  ///
  /// In en, this message translates to:
  /// **'Back to stores'**
  String get outletDetailBack;

  /// Headline of the outlet detail error state.
  ///
  /// In en, this message translates to:
  /// **'This store did not load.'**
  String get outletDetailLoadErrorHeadline;

  /// Headline of the open-reports banner at the top of the outlet detail screen.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One agent reported this pin as wrong} other{{count} agents reported this pin as wrong}}'**
  String outletDetailDisputesHeadline(int count);

  /// Body of the open-reports banner on outlet detail.
  ///
  /// In en, this message translates to:
  /// **'Each of these checked in anyway, flagged, and the visit is on the review queue. Correcting the pin closes the report; saving without moving it records that you looked and the pin stands.'**
  String get outletDetailDisputesBody;

  /// Section rule above the outlet's editable fields.
  ///
  /// In en, this message translates to:
  /// **'This store'**
  String get outletDetailFormHeading;

  /// Label of the outlet name field.
  ///
  /// In en, this message translates to:
  /// **'Store name'**
  String get outletFieldName;

  /// Label of the outlet code field.
  ///
  /// In en, this message translates to:
  /// **'Store code'**
  String get outletFieldCode;

  /// Label of the outlet channel-type field.
  ///
  /// In en, this message translates to:
  /// **'Channel type'**
  String get outletFieldChannel;

  /// Help line under the channel-type field.
  ///
  /// In en, this message translates to:
  /// **'For example: supermarket, spaza, forecourt.'**
  String get outletFieldChannelHelp;

  /// Label of the territory picker.
  ///
  /// In en, this message translates to:
  /// **'Territory'**
  String get outletFieldTerritory;

  /// Label of the latitude field.
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get outletFieldLatitude;

  /// Label of the longitude field.
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get outletFieldLongitude;

  /// Help line under the latitude field.
  ///
  /// In en, this message translates to:
  /// **'Between -90 and 90. Johannesburg is about -26.2.'**
  String get outletFieldLatitudeHelp;

  /// Help line under the longitude field.
  ///
  /// In en, this message translates to:
  /// **'Between -180 and 180. Johannesburg is about 28.0.'**
  String get outletFieldLongitudeHelp;

  /// Label of the outlet status choice row.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get outletFieldStatus;

  /// Outlet status option: the store is trading and gets planned.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get outletStatusActive;

  /// Outlet status option: the store is kept out of planning.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get outletStatusClosed;

  /// Consequence line under the Closed status option.
  ///
  /// In en, this message translates to:
  /// **'Kept out of planning. Check-in still works — an agent at the door must be able to work.'**
  String get outletStatusClosedConsequence;

  /// Consequence line under the Active status option.
  ///
  /// In en, this message translates to:
  /// **'Planned as usual.'**
  String get outletStatusActiveConsequence;

  /// Validation message for an empty required field on the outlet forms.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get outletRequired;

  /// Validation message when a coordinate field holds something that is not a number.
  ///
  /// In en, this message translates to:
  /// **'Enter a number, for example -26.2041'**
  String get outletCoordinateNotANumber;

  /// Validation message when a latitude is off the globe.
  ///
  /// In en, this message translates to:
  /// **'A latitude is between -90 and 90'**
  String get outletLatitudeOutOfRange;

  /// Validation message when a longitude is off the globe.
  ///
  /// In en, this message translates to:
  /// **'A longitude is between -180 and 180'**
  String get outletLongitudeOutOfRange;

  /// Commit button on the outlet detail screen.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get outletSave;

  /// Blocked reason under the outlet detail save button while the form is incomplete.
  ///
  /// In en, this message translates to:
  /// **'Fill in the store\'s name and both coordinates first.'**
  String get outletSaveBlocked;

  /// Toast after the outlet detail save succeeds.
  ///
  /// In en, this message translates to:
  /// **'Store updated.'**
  String get outletSaved;

  /// Toast after the outlet detail save fails. Says what is still true rather than printing the error.
  ///
  /// In en, this message translates to:
  /// **'That store was not saved. It is unchanged.'**
  String get outletSaveFailed;

  /// Line under the coordinate fields while an agent's recorded position has been adopted.
  ///
  /// In en, this message translates to:
  /// **'Using an agent\'s recorded position. The server reads the coordinates from that check-in itself.'**
  String get outletUsingAttempt;

  /// Section rule above the failed check-in evidence on outlet detail.
  ///
  /// In en, this message translates to:
  /// **'Rejected check-ins'**
  String get outletAttemptsHeading;

  /// Sentence under the rejected check-ins section rule.
  ///
  /// In en, this message translates to:
  /// **'Where agents actually were when this store turned them away.'**
  String get outletAttemptsNote;

  /// Inline empty state for the rejected check-in evidence.
  ///
  /// In en, this message translates to:
  /// **'No rejected check-ins.'**
  String get outletAttemptsEmptyHeadline;

  /// Body of the rejected check-ins empty state.
  ///
  /// In en, this message translates to:
  /// **'Nobody has been turned away by this pin.'**
  String get outletAttemptsEmptyBody;

  /// Subtitle of a rejected check-in row.
  ///
  /// In en, this message translates to:
  /// **'{distance} away · {agent}'**
  String outletAttemptSubtitle(String distance, String agent);

  /// Action on a rejected check-in row that adopts its coordinates as the store's pin.
  ///
  /// In en, this message translates to:
  /// **'Use this position'**
  String get outletUseThisPosition;

  /// Action on a pin report that adopts the reporting agent's own position.
  ///
  /// In en, this message translates to:
  /// **'Use their position'**
  String get outletUseTheirPosition;

  /// Fix-quality sentence for a position the platform flagged as mocked.
  ///
  /// In en, this message translates to:
  /// **'The device reported this position as a mock location. It cannot become this store\'s pin.'**
  String get outletFixMocked;

  /// Fix-quality sentence when accuracy was not recorded.
  ///
  /// In en, this message translates to:
  /// **'The device did not report how accurate this position was.'**
  String get outletFixUnknown;

  /// Fix-quality sentence for a position too imprecise to adopt.
  ///
  /// In en, this message translates to:
  /// **'Accurate to about {metres} m — too coarse to set a pin with.'**
  String outletFixCoarse(String metres);

  /// Fix-quality sentence for a usable position.
  ///
  /// In en, this message translates to:
  /// **'Accurate to about {metres} m.'**
  String outletFixGood(String metres);

  /// Section rule above the pin reports on outlet detail.
  ///
  /// In en, this message translates to:
  /// **'Pin reports'**
  String get outletDisputesHeading;

  /// The geometry of one pin report, in one sentence.
  ///
  /// In en, this message translates to:
  /// **'Stood at {position} — {distance} from the pin, which then read {pin}.'**
  String outletDisputeStood(String position, String distance, String pin);

  /// Caution shown when the reporting agent is the outlet's only visitor. Not a refusal.
  ///
  /// In en, this message translates to:
  /// **'No other agent has ever visited this store, so nobody else\'s check-ins can disagree with a pin moved here.'**
  String get outletDisputeSoleVisitor;

  /// State word on a pin report nobody has answered yet.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get outletDisputeOpen;

  /// State line on the pin report the next save will answer.
  ///
  /// In en, this message translates to:
  /// **'Answering this report on save.'**
  String get outletDisputeAnswering;

  /// Action that marks a pin report as the one the next save answers.
  ///
  /// In en, this message translates to:
  /// **'Answer this report'**
  String get outletDisputeAnswer;

  /// Resolution line on a pin report that was accepted.
  ///
  /// In en, this message translates to:
  /// **'Applied by {who}'**
  String outletDisputeApplied(String who);

  /// Resolution line on a pin report that was turned down.
  ///
  /// In en, this message translates to:
  /// **'Rejected by {who}'**
  String outletDisputeRejected(String who);

  /// Stand-in for the resolving person's name when the wire did not send one.
  ///
  /// In en, this message translates to:
  /// **'a manager'**
  String get outletDisputeResolvedByManager;

  /// Provenance of a pin-report photograph captured in the app.
  ///
  /// In en, this message translates to:
  /// **'Taken with the camera'**
  String get outletPhotoCamera;

  /// Provenance of a pin-report photograph picked from the device's library.
  ///
  /// In en, this message translates to:
  /// **'Chosen from the gallery'**
  String get outletPhotoGallery;

  /// Provenance of an older pin-report photograph that carries no source.
  ///
  /// In en, this message translates to:
  /// **'Source not recorded'**
  String get outletPhotoUnknownSource;

  /// The device's own timestamp on a pin-report photograph.
  ///
  /// In en, this message translates to:
  /// **'Phone said {when}'**
  String outletPhotoPhoneSaid(String when);

  /// When the server took delivery of a pin-report photograph.
  ///
  /// In en, this message translates to:
  /// **'Received {when}'**
  String outletPhotoReceived(String when);

  /// Semantic label of a pin-report photograph.
  ///
  /// In en, this message translates to:
  /// **'Storefront photograph from this pin report'**
  String get outletPhotoAlt;

  /// Shown in place of a pin-report photograph whose bytes could not be fetched.
  ///
  /// In en, this message translates to:
  /// **'That photograph did not load.'**
  String get outletPhotoMissing;

  /// Section rule above the outlet's change ledger.
  ///
  /// In en, this message translates to:
  /// **'Change history'**
  String get outletChangesHeading;

  /// Change ledger line for a coordinate move.
  ///
  /// In en, this message translates to:
  /// **'Pin moved from {before} to {after}'**
  String outletChangePinMoved(String before, String after);

  /// Appended to a pin-move ledger line when the new coordinates came from a check-in.
  ///
  /// In en, this message translates to:
  /// **'from an agent\'s recorded position'**
  String get outletChangePinFromAgent;

  /// Change ledger line for a rename.
  ///
  /// In en, this message translates to:
  /// **'Renamed from \"{before}\" to \"{after}\"'**
  String outletChangeRenamed(String before, String after);

  /// Change ledger line for a status change.
  ///
  /// In en, this message translates to:
  /// **'Status {before} to {after}'**
  String outletChangeStatus(String before, String after);

  /// Change ledger line when the recorded change is none of the known kinds.
  ///
  /// In en, this message translates to:
  /// **'Changed'**
  String get outletChangeOther;

  /// Stand-in inside a pin-move ledger line when a before or after coordinate is missing.
  ///
  /// In en, this message translates to:
  /// **'not recorded'**
  String get outletChangeUnknownCoordinate;

  /// Title of the create-store route.
  ///
  /// In en, this message translates to:
  /// **'Add a store'**
  String get createOutletTitle;

  /// Semantic label of the create-store back button.
  ///
  /// In en, this message translates to:
  /// **'Back to stores'**
  String get createOutletBack;

  /// Commit button on the create-store form.
  ///
  /// In en, this message translates to:
  /// **'Add the store'**
  String get createOutletSubmit;

  /// Blocked reason under the create-store commit button.
  ///
  /// In en, this message translates to:
  /// **'Fill in the name, code, channel, territory and both coordinates first.'**
  String get createOutletBlocked;

  /// Toast after the create-store request fails.
  ///
  /// In en, this message translates to:
  /// **'That store was not created. Nothing was saved.'**
  String get createOutletFailed;

  /// Section rule above the location block on the create-store form.
  ///
  /// In en, this message translates to:
  /// **'Where this store is'**
  String get createOutletLocationHeading;

  /// Line shown while the device position is being fetched, to seed the coordinate fields.
  ///
  /// In en, this message translates to:
  /// **'Finding where this phone is…'**
  String get createOutletLocating;

  /// Shown when location permission was refused on the create-store form.
  ///
  /// In en, this message translates to:
  /// **'This phone will not say where it is. Type the store\'s coordinates instead.'**
  String get createOutletLocationDenied;

  /// Shown when the device position lookup failed on the create-store form.
  ///
  /// In en, this message translates to:
  /// **'This phone could not find where it is. Type the store\'s coordinates instead.'**
  String get createOutletLocationFailed;

  /// Shown when the device position seeded the coordinate fields.
  ///
  /// In en, this message translates to:
  /// **'Seeded from this phone. Type over it if you are not standing in the store.'**
  String get createOutletLocationFound;

  /// Action that re-seeds the coordinate fields from the device.
  ///
  /// In en, this message translates to:
  /// **'Use this phone\'s position'**
  String get createOutletUseThisPhone;

  /// Placeholder while the territory list is being fetched.
  ///
  /// In en, this message translates to:
  /// **'Loading territories…'**
  String get createOutletTerritoriesLoading;

  /// Shown when the territory list could not be fetched on the create-store form.
  ///
  /// In en, this message translates to:
  /// **'The territory list did not load.'**
  String get createOutletTerritoriesFailed;

  /// Retry action beside the failed territory list.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get createOutletTerritoriesRetry;

  /// Shown when the account has no territories, so no store can be filed.
  ///
  /// In en, this message translates to:
  /// **'No territories yet — create one under Territories first.'**
  String get createOutletNoTerritories;

  /// Validation message when the territory picker has no selection.
  ///
  /// In en, this message translates to:
  /// **'Choose a territory'**
  String get createOutletTerritoryNotChosen;

  /// Title of the orders worklist route.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get ordersTitle;

  /// Header fact on the orders worklist.
  ///
  /// In en, this message translates to:
  /// **'Captured in the field. A submitted order is waiting on a decision.'**
  String get ordersSubtitle;

  /// Semantic label of the refresh icon button in the orders header.
  ///
  /// In en, this message translates to:
  /// **'Reload the order list'**
  String get ordersRefresh;

  /// Section rule above the order rows.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get ordersSectionHeading;

  /// Action that opens the order capture form.
  ///
  /// In en, this message translates to:
  /// **'New order'**
  String get ordersNewOrder;

  /// Eyebrow of the lead figure counting submitted orders.
  ///
  /// In en, this message translates to:
  /// **'Awaiting a decision'**
  String get ordersAwaitingEyebrow;

  /// The two counts that are not the lead figure, beneath it.
  ///
  /// In en, this message translates to:
  /// **'{confirmed} confirmed · {cancelled} cancelled'**
  String ordersAwaitingSubordinates(String confirmed, String cancelled);

  /// Eyebrow of the summed order value. It names the scope — these orders, not every order — because the list is one page.
  ///
  /// In en, this message translates to:
  /// **'Value of these orders'**
  String get ordersValueEyebrow;

  /// State line under the order value when the list was cut. A partial sum that calls itself a total is an invented figure.
  ///
  /// In en, this message translates to:
  /// **'Summed over the {shown} orders loaded, not the whole history.'**
  String ordersValuePartial(String shown);

  /// State line under a count taken over a cut page.
  ///
  /// In en, this message translates to:
  /// **'At least this many: counted over the {shown} orders loaded.'**
  String ordersCountPartial(String shown);

  /// Order status word: captured and waiting on a decision.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get ordersStatusSubmitted;

  /// Order status word: accepted.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get ordersStatusConfirmed;

  /// Order status word: turned down.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get ordersStatusCancelled;

  /// Fallback for an order status the app does not know. The wire's own word is shown rather than guessed at.
  ///
  /// In en, this message translates to:
  /// **'Status {status}'**
  String ordersStatusOther(String status);

  /// How many line items an order carries.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 line} other{{count} lines}}'**
  String ordersLineCount(int count);

  /// An order row's second line: its status and how many lines it has.
  ///
  /// In en, this message translates to:
  /// **'{status} · {lines}'**
  String ordersRowSubtitle(String status, String lines);

  /// Title of an order row whose outlet is not in the loaded store list. The id goes in the meta line, never in the title.
  ///
  /// In en, this message translates to:
  /// **'Store not on this list'**
  String get ordersUnknownStore;

  /// Whole-screen empty state on the orders worklist.
  ///
  /// In en, this message translates to:
  /// **'No orders yet.'**
  String get ordersEmptyHeadline;

  /// Body of the orders empty state.
  ///
  /// In en, this message translates to:
  /// **'Orders appear here as agents capture them on a visit.'**
  String get ordersEmptyBody;

  /// Headline of the orders error state.
  ///
  /// In en, this message translates to:
  /// **'The order list did not load.'**
  String get ordersLoadErrorHeadline;

  /// Retry action on the orders error state.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get ordersRetry;

  /// Pagination footer when the server did not count the whole list.
  ///
  /// In en, this message translates to:
  /// **'Showing the first {shown}. There are more.'**
  String ordersFooterMore(String shown);

  /// Pagination footer when the server counted the whole list.
  ///
  /// In en, this message translates to:
  /// **'Showing the {shown} newest of {total} orders.'**
  String ordersFooterOf(String shown, String total);

  /// Second footer line: the honest scope of every figure above the list.
  ///
  /// In en, this message translates to:
  /// **'The figures above are of these {shown}.'**
  String ordersFooterScope(String shown);

  /// Title of the order capture form.
  ///
  /// In en, this message translates to:
  /// **'New order'**
  String get orderFormTitle;

  /// Semantic label of the order form's back button.
  ///
  /// In en, this message translates to:
  /// **'Back to orders'**
  String get orderFormBack;

  /// Section rule above the store picker on the order form.
  ///
  /// In en, this message translates to:
  /// **'Which store'**
  String get orderFormStoreHeading;

  /// Label of the store picker on the order form.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get orderFormStore;

  /// Line under the store picker while nothing is chosen.
  ///
  /// In en, this message translates to:
  /// **'Not chosen yet. A store decides what can be ordered.'**
  String get orderFormStoreNotChosen;

  /// Shown when the outlet list could not be fetched on the order form.
  ///
  /// In en, this message translates to:
  /// **'The store list did not load.'**
  String get orderFormStoresFailed;

  /// Section rule above the SKU list on the order form.
  ///
  /// In en, this message translates to:
  /// **'Line items'**
  String get orderFormLinesHeading;

  /// Inline empty state in place of the SKU list before a store is chosen.
  ///
  /// In en, this message translates to:
  /// **'Choose a store to see what it stocks.'**
  String get orderFormPickStoreFirst;

  /// Shown when the SKU list could not be fetched.
  ///
  /// In en, this message translates to:
  /// **'That store\'s products did not load.'**
  String get orderFormSkusFailed;

  /// Inline empty state when a store has no SKUs.
  ///
  /// In en, this message translates to:
  /// **'Nothing is stocked here.'**
  String get orderFormNoSkusHeadline;

  /// Body of the no-SKUs empty state.
  ///
  /// In en, this message translates to:
  /// **'This store has no products on its list, so there is nothing to order.'**
  String get orderFormNoSkusBody;

  /// Label of the running order total.
  ///
  /// In en, this message translates to:
  /// **'Order total'**
  String get orderFormTotal;

  /// Commit button on the order form.
  ///
  /// In en, this message translates to:
  /// **'Create the order'**
  String get orderFormSubmit;

  /// Blocked reason under the order form's commit button.
  ///
  /// In en, this message translates to:
  /// **'Choose a store and set a quantity on at least one line first.'**
  String get orderFormBlocked;

  /// Toast after the order create request fails.
  ///
  /// In en, this message translates to:
  /// **'That order was not created. Nothing was sent.'**
  String get orderFormFailed;

  /// Label of a SKU's quantity stepper on the order form.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get orderFormQuantity;

  /// Semantic label of the quantity stepper's minus key.
  ///
  /// In en, this message translates to:
  /// **'One fewer'**
  String get orderFormOneFewer;

  /// Semantic label of the quantity stepper's plus key.
  ///
  /// In en, this message translates to:
  /// **'One more'**
  String get orderFormOneMore;

  /// Semantic label of the quantity trough, which opens a number sheet.
  ///
  /// In en, this message translates to:
  /// **'Type a quantity'**
  String get orderFormTypeQuantity;

  /// Blocked reason on the number sheet's Set button while nothing has been typed.
  ///
  /// In en, this message translates to:
  /// **'Type a quantity first.'**
  String get orderFormTypeQuantityFirst;

  /// What a SKU with no quantity says. Nothing ordered is a state, not a zero.
  ///
  /// In en, this message translates to:
  /// **'Not on this order'**
  String get orderFormNotOrdered;

  /// Word for a line explicitly set to nought.
  ///
  /// In en, this message translates to:
  /// **'None of this one'**
  String get orderFormNoneOrdered;

  /// Consequence line under a quantity of nought.
  ///
  /// In en, this message translates to:
  /// **'A line at nought is not sent.'**
  String get orderFormNoneOrderedLine;

  /// Cancel action on the quantity number sheet.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get orderFormCancel;

  /// Commit action on the quantity number sheet.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get orderFormSet;

  /// Title of the beat plans route.
  ///
  /// In en, this message translates to:
  /// **'Beat plans'**
  String get beatPlansTitle;

  /// Header fact on the beat plans route.
  ///
  /// In en, this message translates to:
  /// **'A plan is a day of store stops, in visit order.'**
  String get beatPlansSubtitle;

  /// Semantic label of the refresh icon button on the beat plans route.
  ///
  /// In en, this message translates to:
  /// **'Reload the beat plans'**
  String get beatPlansRefresh;

  /// Section rule above the beat plan rows.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get beatPlansSectionHeading;

  /// Action that opens the beat plan builder.
  ///
  /// In en, this message translates to:
  /// **'New plan'**
  String get beatPlansNewPlan;

  /// Whole-screen empty state on the beat plans route.
  ///
  /// In en, this message translates to:
  /// **'No beat plans.'**
  String get beatPlansEmptyHeadline;

  /// Body of the beat plans empty state.
  ///
  /// In en, this message translates to:
  /// **'A plan is a day of store stops in visit order. Build one to give an agent a route.'**
  String get beatPlansEmptyBody;

  /// Headline of the beat plans error state.
  ///
  /// In en, this message translates to:
  /// **'The beat plans did not load.'**
  String get beatPlansLoadErrorHeadline;

  /// Retry action on the beat plans error state.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get beatPlansRetry;

  /// Pagination footer on the beat plans route when the server did not count.
  ///
  /// In en, this message translates to:
  /// **'Showing the first {shown}. There are more.'**
  String beatPlansFooterMore(String shown);

  /// Pagination footer on the beat plans route when the server counted.
  ///
  /// In en, this message translates to:
  /// **'Showing {shown} of {total} plans.'**
  String beatPlansFooterOf(String shown, String total);

  /// Beat plan status word: planned, not started.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get beatPlanStatusScheduled;

  /// Beat plan status word: being worked now.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get beatPlanStatusInProgress;

  /// Beat plan status word: every stop worked.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get beatPlanStatusCompleted;

  /// Beat plan status word: the day passed unworked.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get beatPlanStatusMissed;

  /// Beat plan status word: called off.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get beatPlanStatusCancelled;

  /// Fallback for a beat plan status the app does not know.
  ///
  /// In en, this message translates to:
  /// **'Status {status}'**
  String beatPlanStatusOther(String status);

  /// Title of the beat plan detail route.
  ///
  /// In en, this message translates to:
  /// **'Beat plan'**
  String get beatPlanDetailTitle;

  /// Semantic label of the beat plan detail back button.
  ///
  /// In en, this message translates to:
  /// **'Back to beat plans'**
  String get beatPlanDetailBack;

  /// Headline of the beat plan detail error state.
  ///
  /// In en, this message translates to:
  /// **'This beat plan did not load.'**
  String get beatPlanDetailLoadErrorHeadline;

  /// Eyebrow of the adherence figure on a beat plan.
  ///
  /// In en, this message translates to:
  /// **'Stops worked'**
  String get beatPlanAdherenceEyebrow;

  /// The adherence figure in words, beneath the percentage.
  ///
  /// In en, this message translates to:
  /// **'{visited} of {total} stops'**
  String beatPlanAdherenceOf(String visited, String total);

  /// Reason shown in place of an adherence percentage for a plan with no stops. A plan with no stops is not nought per cent adherent.
  ///
  /// In en, this message translates to:
  /// **'This plan has no stops, so there is nothing to work.'**
  String get beatPlanAdherenceNoStops;

  /// Section rule above a beat plan's stops.
  ///
  /// In en, this message translates to:
  /// **'Stops'**
  String get beatPlanStopsHeading;

  /// Inline empty state for a beat plan with no stops.
  ///
  /// In en, this message translates to:
  /// **'No stops on this plan.'**
  String get beatPlanStopsEmptyHeadline;

  /// Body of the no-stops empty state.
  ///
  /// In en, this message translates to:
  /// **'Add stores to the plan to give the agent a route.'**
  String get beatPlanStopsEmptyBody;

  /// Title of a beat plan stop row when the store's name is not known.
  ///
  /// In en, this message translates to:
  /// **'Stop {sequence}'**
  String beatPlanStopLabel(String sequence);

  /// State word on a stop that has been visited.
  ///
  /// In en, this message translates to:
  /// **'Worked'**
  String get beatPlanStopVisited;

  /// State word on a stop that has not been visited.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get beatPlanStopNotVisited;

  /// Semantic label of a stop's visited checkbox.
  ///
  /// In en, this message translates to:
  /// **'Mark {stop} as worked'**
  String beatPlanStopToggle(String stop);

  /// Toast after marking a stop visited fails.
  ///
  /// In en, this message translates to:
  /// **'That stop was not changed. It is as it was.'**
  String get beatPlanStopFailed;

  /// Title of the beat plan builder.
  ///
  /// In en, this message translates to:
  /// **'New beat plan'**
  String get beatPlanFormTitle;

  /// Semantic label of the beat plan builder's back button.
  ///
  /// In en, this message translates to:
  /// **'Back to beat plans'**
  String get beatPlanFormBack;

  /// Section rule above the beat plan's own fields.
  ///
  /// In en, this message translates to:
  /// **'The day'**
  String get beatPlanFormPlanHeading;

  /// Label of the beat plan name field.
  ///
  /// In en, this message translates to:
  /// **'Plan name'**
  String get beatPlanFormName;

  /// Help line under the beat plan name field.
  ///
  /// In en, this message translates to:
  /// **'What the agent will see at the top of their day.'**
  String get beatPlanFormNameHelp;

  /// Label of the beat plan date picker.
  ///
  /// In en, this message translates to:
  /// **'Scheduled date'**
  String get beatPlanFormDate;

  /// Line under the date picker while no date is chosen.
  ///
  /// In en, this message translates to:
  /// **'Not chosen yet.'**
  String get beatPlanFormDateNotChosen;

  /// Action that opens the date picker.
  ///
  /// In en, this message translates to:
  /// **'Pick a date'**
  String get beatPlanFormPickDate;

  /// Action that reopens the date picker once a date is chosen.
  ///
  /// In en, this message translates to:
  /// **'Change the date'**
  String get beatPlanFormChangeDate;

  /// Label of the agent picker on the beat plan builder.
  ///
  /// In en, this message translates to:
  /// **'Field agent'**
  String get beatPlanFormAgent;

  /// Line under the agent picker while nothing is chosen.
  ///
  /// In en, this message translates to:
  /// **'Not chosen yet. A plan belongs to one agent.'**
  String get beatPlanFormAgentNotChosen;

  /// Shown when the user list could not be fetched on the beat plan builder.
  ///
  /// In en, this message translates to:
  /// **'The agent list did not load.'**
  String get beatPlanFormAgentsFailed;

  /// Shown when the account has no field agents to assign a plan to.
  ///
  /// In en, this message translates to:
  /// **'No field agents on this account yet.'**
  String get beatPlanFormNoAgents;

  /// Label of the optional territory picker on the beat plan builder.
  ///
  /// In en, this message translates to:
  /// **'Territory'**
  String get beatPlanFormTerritory;

  /// Help line under the optional territory picker.
  ///
  /// In en, this message translates to:
  /// **'Optional. It narrows reporting, not the stops.'**
  String get beatPlanFormTerritoryOptional;

  /// The option that clears the optional territory.
  ///
  /// In en, this message translates to:
  /// **'No territory'**
  String get beatPlanFormTerritoryNone;

  /// Section rule above the chosen stops on the beat plan builder.
  ///
  /// In en, this message translates to:
  /// **'Stops, in order'**
  String get beatPlanFormStopsHeading;

  /// Inline empty state for the chosen stops.
  ///
  /// In en, this message translates to:
  /// **'No stops yet. Add stores from the list below.'**
  String get beatPlanFormStopsEmpty;

  /// Section rule above the pool of stores not yet on the plan.
  ///
  /// In en, this message translates to:
  /// **'Stores to add'**
  String get beatPlanFormAvailableHeading;

  /// Inline empty state for the pool of available stores.
  ///
  /// In en, this message translates to:
  /// **'Every store is already on this plan.'**
  String get beatPlanFormAvailableEmpty;

  /// Shown when the outlet list could not be fetched on the beat plan builder.
  ///
  /// In en, this message translates to:
  /// **'The store list did not load.'**
  String get beatPlanFormStoresFailed;

  /// Semantic label of the button that adds a store to the plan.
  ///
  /// In en, this message translates to:
  /// **'Add {store} to the plan'**
  String beatPlanFormAddStop(String store);

  /// Semantic label of the button that removes a stop.
  ///
  /// In en, this message translates to:
  /// **'Take {store} off the plan'**
  String beatPlanFormRemoveStop(String store);

  /// Semantic label of the button that moves a stop up the order.
  ///
  /// In en, this message translates to:
  /// **'Move {store} earlier'**
  String beatPlanFormMoveUp(String store);

  /// Semantic label of the button that moves a stop down the order.
  ///
  /// In en, this message translates to:
  /// **'Move {store} later'**
  String beatPlanFormMoveDown(String store);

  /// How many stops are on the plan being built.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No stops} =1{1 stop} other{{count} stops}}'**
  String beatPlanFormStopCount(int count);

  /// Commit button on the beat plan builder.
  ///
  /// In en, this message translates to:
  /// **'Create the plan'**
  String get beatPlanFormSubmit;

  /// Blocked reason under the beat plan builder's commit button.
  ///
  /// In en, this message translates to:
  /// **'Name the plan, pick a date and an agent, and add at least one stop first.'**
  String get beatPlanFormBlocked;

  /// Toast after the beat plan create request fails.
  ///
  /// In en, this message translates to:
  /// **'That plan was not created. Nothing was saved.'**
  String get beatPlanFormFailed;

  /// Title of the sales targets route.
  ///
  /// In en, this message translates to:
  /// **'Sales targets'**
  String get salesTargetsTitle;

  /// Header fact on the sales targets route. It says what the metric is before any figure is read.
  ///
  /// In en, this message translates to:
  /// **'Units ordered through TradeIQ, not what shoppers bought.'**
  String get salesTargetsSubtitle;

  /// The metric's name: units ordered through TradeIQ. Used wherever the server did not send its own label.
  ///
  /// In en, this message translates to:
  /// **'Sell-in (orders)'**
  String get salesSellIn;

  /// Second header fact on the sales targets route.
  ///
  /// In en, this message translates to:
  /// **'Set one target per SKU for the whole account, a territory, or a single store.'**
  String get salesTargetsHelp;

  /// Semantic label of the CSV import icon button.
  ///
  /// In en, this message translates to:
  /// **'Upload a CSV of targets'**
  String get salesTargetsUpload;

  /// Semantic label of the previous-month button.
  ///
  /// In en, this message translates to:
  /// **'The month before {month}'**
  String salesMonthPrevious(String month);

  /// Semantic label of the next-month button.
  ///
  /// In en, this message translates to:
  /// **'The month after {month}'**
  String salesMonthNext(String month);

  /// Says which time zone the month's days were counted in.
  ///
  /// In en, this message translates to:
  /// **'Local days in {zone}'**
  String salesTimeZone(String zone);

  /// Section rule above the three attainment levels.
  ///
  /// In en, this message translates to:
  /// **'Against target'**
  String get salesLevelsHeading;

  /// The attainment level covering every store on the account.
  ///
  /// In en, this message translates to:
  /// **'Account-wide'**
  String get salesLevelAccount;

  /// The attainment level covering territory-scoped targets.
  ///
  /// In en, this message translates to:
  /// **'Territories'**
  String get salesLevelTerritories;

  /// The attainment level covering store-scoped targets.
  ///
  /// In en, this message translates to:
  /// **'Stores'**
  String get salesLevelOutlets;

  /// Reason shown in place of an attainment percentage for a level with no targets. A level with no target is not nought per cent attained.
  ///
  /// In en, this message translates to:
  /// **'No target is set at this level, so there is nothing to attain.'**
  String get salesLevelNoTargets;

  /// The units and the target count beneath an attainment figure.
  ///
  /// In en, this message translates to:
  /// **'{actual} of {target} units · {targets, plural, =1{1 target} other{{targets} targets}}'**
  String salesLevelSubordinates(String actual, String target, int targets);

  /// Attainment band word at or above 100 per cent.
  ///
  /// In en, this message translates to:
  /// **'On target'**
  String get salesBandOnTarget;

  /// Attainment band word from 80 to 99 per cent.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get salesBandClose;

  /// Attainment band word below 80 per cent.
  ///
  /// In en, this message translates to:
  /// **'Behind'**
  String get salesBandBehind;

  /// Word for a SKU or scope with no target set. Never a nought: a target that does not exist is not a target of zero.
  ///
  /// In en, this message translates to:
  /// **'No target'**
  String get salesNoTarget;

  /// Inline empty state when the month has no targets at all.
  ///
  /// In en, this message translates to:
  /// **'No targets for {month}.'**
  String salesNoTargetsHeadline(String month);

  /// Body of the no-targets empty state.
  ///
  /// In en, this message translates to:
  /// **'Set a target on a SKU below, or upload a CSV of targets.'**
  String get salesNoTargetsBody;

  /// Section rule above the per-SKU rows.
  ///
  /// In en, this message translates to:
  /// **'SKUs'**
  String get salesSkusHeading;

  /// Pagination footer when the server cut the SKU list.
  ///
  /// In en, this message translates to:
  /// **'Showing the first {shown}.'**
  String salesSkusTruncated(String shown);

  /// Inline empty state when the account has no products.
  ///
  /// In en, this message translates to:
  /// **'No SKUs on this account.'**
  String get salesSkusEmptyHeadline;

  /// Body of the no-SKUs empty state.
  ///
  /// In en, this message translates to:
  /// **'Targets are set per SKU, so there is nothing to set one on yet.'**
  String get salesSkusEmptyBody;

  /// A SKU row's figures: what was ordered, against the target.
  ///
  /// In en, this message translates to:
  /// **'{metric} {actual} · target {target} units'**
  String salesRowFigures(String metric, String actual, String target);

  /// A SKU row's figures when no target exists. It says so in words rather than printing a nought.
  ///
  /// In en, this message translates to:
  /// **'{metric} {actual} · no target set'**
  String salesRowNoTargetFigures(String metric, String actual);

  /// Scope word for a territory-scoped target.
  ///
  /// In en, this message translates to:
  /// **'Territory'**
  String get salesScopeTerritory;

  /// Scope word for a store-scoped target.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get salesScopeOutlet;

  /// Scope word for an account-wide target.
  ///
  /// In en, this message translates to:
  /// **'Whole account'**
  String get salesScopeAccount;

  /// Shown when a scoped target names a territory or store the report did not resolve.
  ///
  /// In en, this message translates to:
  /// **'Scope not on this list'**
  String get salesScopeUnknown;

  /// Title of a scoped target's row.
  ///
  /// In en, this message translates to:
  /// **'{sku} · {scope}'**
  String salesScopedRowTitle(String sku, String scope);

  /// Action that opens the target sheet for a SKU with no target.
  ///
  /// In en, this message translates to:
  /// **'Set a target'**
  String get salesSetTarget;

  /// Action that opens the target sheet for an existing target.
  ///
  /// In en, this message translates to:
  /// **'Edit the target'**
  String get salesEditTarget;

  /// Action that deletes a target.
  ///
  /// In en, this message translates to:
  /// **'Remove the target'**
  String get salesRemoveTarget;

  /// Toast after a target delete fails.
  ///
  /// In en, this message translates to:
  /// **'That target was not removed. It is still set.'**
  String get salesRemoveFailed;

  /// Title of the sheet that creates a target.
  ///
  /// In en, this message translates to:
  /// **'Set a sales target'**
  String get salesTargetSheetSet;

  /// Title of the sheet that edits a target.
  ///
  /// In en, this message translates to:
  /// **'Edit a sales target'**
  String get salesTargetSheetEdit;

  /// Subtitle of the target sheet: the metric and the month it applies to.
  ///
  /// In en, this message translates to:
  /// **'Units of {metric} for {month}.'**
  String salesTargetSheetSubtitle(String metric, String month);

  /// Label of the SKU picker in the target sheet.
  ///
  /// In en, this message translates to:
  /// **'SKU'**
  String get salesTargetSku;

  /// Line under the SKU picker while nothing is chosen.
  ///
  /// In en, this message translates to:
  /// **'Not chosen yet. A target belongs to one SKU.'**
  String get salesTargetSkuNotChosen;

  /// Reason shown under the locked SKU picker when editing.
  ///
  /// In en, this message translates to:
  /// **'A target is identified by its SKU, so an edit cannot move it.'**
  String get salesTargetSkuLocked;

  /// Label of the scope choice in the target sheet.
  ///
  /// In en, this message translates to:
  /// **'Applies to'**
  String get salesTargetScope;

  /// Reason shown under the locked scope choice when editing.
  ///
  /// In en, this message translates to:
  /// **'A target is identified by its scope, so an edit cannot move it.'**
  String get salesTargetScopeLocked;

  /// Consequence line under the account-wide scope option.
  ///
  /// In en, this message translates to:
  /// **'Every store on the account counts towards it.'**
  String get salesTargetScopeAccountConsequence;

  /// Consequence line under the territory scope option.
  ///
  /// In en, this message translates to:
  /// **'Only stores in the chosen territory count.'**
  String get salesTargetScopeTerritoryConsequence;

  /// Consequence line under the store scope option.
  ///
  /// In en, this message translates to:
  /// **'Only the chosen store counts.'**
  String get salesTargetScopeOutletConsequence;

  /// Line under the territory picker in the target sheet while nothing is chosen.
  ///
  /// In en, this message translates to:
  /// **'Not chosen yet. A territory target needs one.'**
  String get salesTargetTerritoryNotChosen;

  /// Line under the store picker in the target sheet while nothing is chosen.
  ///
  /// In en, this message translates to:
  /// **'Not chosen yet. A store target needs one.'**
  String get salesTargetOutletNotChosen;

  /// Label of the target units field in the target sheet.
  ///
  /// In en, this message translates to:
  /// **'Target units'**
  String get salesTargetUnits;

  /// Help line under the target units field.
  ///
  /// In en, this message translates to:
  /// **'A whole number of units, for the month.'**
  String get salesTargetUnitsHelp;

  /// Validation message when the target units field is empty or not a whole number.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number of units.'**
  String get salesTargetUnitsMissing;

  /// Commit button in the target sheet.
  ///
  /// In en, this message translates to:
  /// **'Save the target'**
  String get salesTargetSave;

  /// Blocked reason under the target sheet's commit button.
  ///
  /// In en, this message translates to:
  /// **'Choose a SKU and a scope, and enter a whole number of units.'**
  String get salesTargetBlocked;

  /// Cancel action in the target sheet.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get salesTargetCancel;

  /// Headline of the sales targets error state.
  ///
  /// In en, this message translates to:
  /// **'The targets did not load.'**
  String get salesTargetsLoadErrorHeadline;

  /// Retry action on the sales targets error state.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get salesTargetsRetry;

  /// Title of the CSV import sheet.
  ///
  /// In en, this message translates to:
  /// **'Upload sales targets'**
  String get salesImportTitle;

  /// Subtitle of the CSV import sheet.
  ///
  /// In en, this message translates to:
  /// **'Preview what a file would do, then apply the rows that are good.'**
  String get salesImportSubtitle;

  /// What the CSV file must contain.
  ///
  /// In en, this message translates to:
  /// **'It needs a header row: month (YYYY-MM), sku (id or name), targetUnits, and optionally territory or outlet (id or code). Existing targets for the same SKU, month and scope are replaced.'**
  String get salesImportFormat;

  /// Action that opens the platform file chooser.
  ///
  /// In en, this message translates to:
  /// **'Choose a CSV file'**
  String get salesImportChooseFile;

  /// Action that replaces the chosen file.
  ///
  /// In en, this message translates to:
  /// **'Choose another file'**
  String get salesImportChooseAnother;

  /// Action that clears the chosen file and brings the paste box back.
  ///
  /// In en, this message translates to:
  /// **'Remove the file'**
  String get salesImportRemoveFile;

  /// Label of the CSV paste box.
  ///
  /// In en, this message translates to:
  /// **'Or paste a CSV'**
  String get salesImportPasteLabel;

  /// Placeholder inside the CSV paste box: the header row it wants.
  ///
  /// In en, this message translates to:
  /// **'month,sku,targetUnits,territory,outlet'**
  String get salesImportPasteHint;

  /// Shown in place of the paste box while a file is held.
  ///
  /// In en, this message translates to:
  /// **'Preview to see what this file would do. Remove it to paste a CSV instead.'**
  String get salesImportFileHeld;

  /// Shown when the chooser returned a file the console cannot take and gave no reason of its own.
  ///
  /// In en, this message translates to:
  /// **'That file could not be read.'**
  String get salesImportFileUnreadable;

  /// Action that runs the dry-run import.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get salesImportPreview;

  /// Commit action before a preview has been run.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get salesImportApply;

  /// Commit action once a preview says how many rows are good.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Apply 1 row} other{Apply {count} rows}}'**
  String salesImportApplyRows(int count);

  /// Blocked reason on Apply before a preview has been run, or after the CSV changed.
  ///
  /// In en, this message translates to:
  /// **'Preview the file first. What gets written is always what was shown.'**
  String get salesImportBlockedPreview;

  /// Blocked reason on Apply when the preview found nothing valid.
  ///
  /// In en, this message translates to:
  /// **'No row in this file can be written.'**
  String get salesImportBlockedNoRows;

  /// Eyebrow of the dry run's valid-row count.
  ///
  /// In en, this message translates to:
  /// **'Rows ready to write'**
  String get salesImportReadyEyebrow;

  /// Eyebrow of the dry run's invalid-row count.
  ///
  /// In en, this message translates to:
  /// **'Rows with errors'**
  String get salesImportErrorsEyebrow;

  /// What the dry run says the file would do.
  ///
  /// In en, this message translates to:
  /// **'Would create {created} and update {updated}.'**
  String salesImportWouldDo(String created, String updated);

  /// Section rule above the dry run's row errors.
  ///
  /// In en, this message translates to:
  /// **'What is wrong'**
  String get salesImportErrorsHeading;

  /// One row error from the dry run.
  ///
  /// In en, this message translates to:
  /// **'Row {row}: {message}'**
  String salesImportRowError(String row, String message);

  /// One row error from the dry run, naming the column.
  ///
  /// In en, this message translates to:
  /// **'Row {row} · {column}: {message}'**
  String salesImportRowErrorColumn(String row, String column, String message);

  /// Shown when the dry run found more errors than the sheet lists.
  ///
  /// In en, this message translates to:
  /// **'…and {count} more.'**
  String salesImportMoreErrors(String count);

  /// Shown when a dry run found no errors at all.
  ///
  /// In en, this message translates to:
  /// **'Every row in this file can be written.'**
  String get salesImportNothingWrong;

  /// Toast after an import is applied.
  ///
  /// In en, this message translates to:
  /// **'{created} created, {updated} updated.'**
  String salesImportApplied(String created, String updated);

  /// Toast after an import is applied with some rows refused.
  ///
  /// In en, this message translates to:
  /// **'{created} created, {updated} updated, {skipped} rows skipped.'**
  String salesImportAppliedSkipped(
    String created,
    String updated,
    String skipped,
  );

  /// Title of the dashboard's sales attainment panel.
  ///
  /// In en, this message translates to:
  /// **'Sell-in vs target'**
  String get salesPanelTitle;

  /// Subtitle of the dashboard's sales attainment panel.
  ///
  /// In en, this message translates to:
  /// **'{metric} · {month} — not consumer sales'**
  String salesPanelSubtitle(String metric, String month);

  /// Stand-in for the month in the dashboard panel's subtitle before the server has said which month it answered for.
  ///
  /// In en, this message translates to:
  /// **'this month'**
  String get salesPanelThisMonth;

  /// Action on the dashboard panel that opens the sales targets route.
  ///
  /// In en, this message translates to:
  /// **'Targets'**
  String get salesPanelLink;

  /// Body of the dashboard panel's empty state.
  ///
  /// In en, this message translates to:
  /// **'Set monthly SKU targets under Sales targets to track sell-in against them.'**
  String get salesPanelEmptyBody;

  /// Screen title: the client's own audit templates.
  ///
  /// In en, this message translates to:
  /// **'Audit templates'**
  String get templatesTitle;

  /// Header fact under the Audit templates title.
  ///
  /// In en, this message translates to:
  /// **'A template is the form an agent fills in on a visit.'**
  String get templatesFact;

  /// Semantic label of the header's refresh button. Names what it does, never just 'Refresh'.
  ///
  /// In en, this message translates to:
  /// **'Refresh the templates'**
  String get templatesRefresh;

  /// What the skeleton says it is loading, inside 'Still fetching the …'.
  ///
  /// In en, this message translates to:
  /// **'templates'**
  String get templatesSkeleton;

  /// Section rule above the list of templates.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get templatesSection;

  /// In-panel empty state: this client has no templates at all.
  ///
  /// In en, this message translates to:
  /// **'No templates yet.'**
  String get templatesEmptyHeadline;

  /// Body of the templates empty state.
  ///
  /// In en, this message translates to:
  /// **'Templates published to this client appear here.'**
  String get templatesEmptyBody;

  /// Section rule above the block naming which template agents answer.
  ///
  /// In en, this message translates to:
  /// **'Used in field audits'**
  String get templatesInAuditsSection;

  /// Headline while the selected-template request is still in flight.
  ///
  /// In en, this message translates to:
  /// **'Checking which template is in use…'**
  String get templatesInAuditsChecking;

  /// Headline when the selected-template request failed. No row then claims to be in use.
  ///
  /// In en, this message translates to:
  /// **'Could not load the template used in audits.'**
  String get templatesInAuditsFailed;

  /// Headline when the client has chosen no template for audits.
  ///
  /// In en, this message translates to:
  /// **'No template is used in audits.'**
  String get templatesInAuditsNone;

  /// Headline naming the template in use and its version.
  ///
  /// In en, this message translates to:
  /// **'“{name}” (v{version})'**
  String templatesInAuditsNamed(String name, int version);

  /// Subtitle of the in-audits block: where these questions sit in a visit.
  ///
  /// In en, this message translates to:
  /// **'Client questions, after the standard audit sections'**
  String get templatesInAuditsSubtitle;

  /// The standing explanation under the in-audits block.
  ///
  /// In en, this message translates to:
  /// **'Agents answer its questions on every visit, as an extra section after the standard audit. Required questions must be answered before a visit can be submitted. It does not change the perfect store score.'**
  String get templatesInAuditsMeta;

  /// Verb that clears the template used in audits.
  ///
  /// In en, this message translates to:
  /// **'Stop using'**
  String get templatesStopUsing;

  /// The Stop using verb while the change is in flight.
  ///
  /// In en, this message translates to:
  /// **'Stopping…'**
  String get templatesStopping;

  /// Spoken sentence of the in-audits block.
  ///
  /// In en, this message translates to:
  /// **'Used in field audits. {headline}'**
  String templatesInAuditsSemantics(String headline);

  /// Toast after clearing the template used in audits.
  ///
  /// In en, this message translates to:
  /// **'No template is used in audits now.'**
  String get templatesCleared;

  /// Toast after choosing a template for audits.
  ///
  /// In en, this message translates to:
  /// **'“{name}” is now used in audits.'**
  String templatesNowInAudits(String name);

  /// Failure toast. The reason is the sanitised server message.
  ///
  /// In en, this message translates to:
  /// **'The audit template was not changed. {reason}'**
  String templatesChangeFailed(String reason);

  /// Row word: this template is the one agents answer.
  ///
  /// In en, this message translates to:
  /// **'In audits'**
  String get templateWordInAudits;

  /// Row word: the template is published and can be put in front of agents.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get templateWordActive;

  /// Row word: the template is done, not broken — it simply cannot be selected.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get templateWordPaused;

  /// A template's version, as a row subtitle.
  ///
  /// In en, this message translates to:
  /// **'v{version}'**
  String templateVersionShort(int version);

  /// A template's version and the industry it was written for.
  ///
  /// In en, this message translates to:
  /// **'v{version} · {industry}'**
  String templateVersionAndIndustry(int version, String industry);

  /// A template's version, spoken rather than abbreviated.
  ///
  /// In en, this message translates to:
  /// **'version {version}'**
  String templateVersionSpoken(int version);

  /// Row verb that puts this template in front of agents.
  ///
  /// In en, this message translates to:
  /// **'Use in audits'**
  String get templateUseInAudits;

  /// The Use in audits verb while the change is in flight.
  ///
  /// In en, this message translates to:
  /// **'Switching…'**
  String get templateSwitching;

  /// What tapping a template row does, spoken at the end of the row's sentence.
  ///
  /// In en, this message translates to:
  /// **'Opens a preview of its form'**
  String get templateOpensPreview;

  /// Title of the manager's walk through a template's form, while it loads or fails.
  ///
  /// In en, this message translates to:
  /// **'Template preview'**
  String get templatePreviewTitle;

  /// The way out of the template preview, naming where it lands.
  ///
  /// In en, this message translates to:
  /// **'Back to Audit templates'**
  String get templatePreviewBack;

  /// What the skeleton and the error region say they are for, inside 'Still fetching the …'.
  ///
  /// In en, this message translates to:
  /// **'the template'**
  String get templatePreviewSkeleton;

  /// Header fact: a preview writes no answers.
  ///
  /// In en, this message translates to:
  /// **'Preview — nothing is saved'**
  String get templatePreviewFact;

  /// Where the manager is in the walk.
  ///
  /// In en, this message translates to:
  /// **'Section {index} of {count}'**
  String templatePreviewSection(int index, int count);

  /// The commit that moves the walk on.
  ///
  /// In en, this message translates to:
  /// **'Next section'**
  String get templatePreviewNext;

  /// The commit on the last section.
  ///
  /// In en, this message translates to:
  /// **'Finish preview'**
  String get templatePreviewFinish;

  /// The secondary that moves the walk back.
  ///
  /// In en, this message translates to:
  /// **'Back a section'**
  String get templatePreviewBackSection;

  /// Why the commit is blocked: one required question is unanswered.
  ///
  /// In en, this message translates to:
  /// **'“{label}” still needs an answer.'**
  String templatePreviewBlockedOne(String label);

  /// Why the commit is blocked: several required questions are unanswered.
  ///
  /// In en, this message translates to:
  /// **'{count} required questions in this section still need answers.'**
  String templatePreviewBlockedMany(int count);

  /// Title of the sheet that ends the preview.
  ///
  /// In en, this message translates to:
  /// **'Preview complete'**
  String get templatePreviewDoneTitle;

  /// The honest end of the preview: what was answered, and that none of it was kept.
  ///
  /// In en, this message translates to:
  /// **'You answered {answered} of {total} visible questions. Nothing was saved — a preview writes no answers, and saving them against a visit arrives with the audit-flow integration.'**
  String templatePreviewDoneBody(int answered, int total);

  /// In-panel empty state: the template parsed, and holds nothing to walk.
  ///
  /// In en, this message translates to:
  /// **'This template has no form sections yet.'**
  String get templateFormNoSectionsHeadline;

  /// Body of the no-sections empty state.
  ///
  /// In en, this message translates to:
  /// **'Publish a section to it and the preview will walk through it.'**
  String get templateFormNoSectionsBody;

  /// Section rule's empty line: this section has no visible questions.
  ///
  /// In en, this message translates to:
  /// **'Nothing to answer in this section yet.'**
  String get templateFormSectionEmpty;

  /// Eyebrow of the running score tile.
  ///
  /// In en, this message translates to:
  /// **'Score preview'**
  String get templateFormScoreEyebrow;

  /// State line under the score: the maximum the preview can actually reach.
  ///
  /// In en, this message translates to:
  /// **'Out of {maximum} for the whole template.'**
  String templateFormScoreOutOf(String maximum);

  /// Help line under a question that blocks the submit gate.
  ///
  /// In en, this message translates to:
  /// **'Required before a visit can be submitted.'**
  String get templateFieldRequired;

  /// A choice row's own state line when nothing is selected.
  ///
  /// In en, this message translates to:
  /// **'Not answered yet.'**
  String get templateFieldNotAnsweredLine;

  /// Subtitle of a choice question nobody has answered. Without the full stop: it is a row's subtitle, not a sentence.
  ///
  /// In en, this message translates to:
  /// **'Not answered yet'**
  String get templateFieldNotAnswered;

  /// The true option of a yes/no question.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get templateFieldYes;

  /// The false option of a yes/no question.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get templateFieldNo;

  /// Verb that returns an answered yes/no question to unanswered — a different fact from 'no'.
  ///
  /// In en, this message translates to:
  /// **'Clear this answer'**
  String get templateFieldClear;

  /// Spoken sentence of a choice question that opens a picker sheet.
  ///
  /// In en, this message translates to:
  /// **'{label}. {answer}. Opens the list of answers.'**
  String templateFieldChoiceSemantics(String label, String answer);

  /// Subtitle of a photo question: capture inside a template is not wired yet.
  ///
  /// In en, this message translates to:
  /// **'Cannot be answered yet'**
  String get templateFieldPhotoSubtitle;

  /// Why a photo question cannot be answered, and that it is not a gate.
  ///
  /// In en, this message translates to:
  /// **'Photo capture arrives with the audit-flow integration. This question does not block a submit.'**
  String get templateFieldPhotoMeta;

  /// Spoken sentence of a photo question.
  ///
  /// In en, this message translates to:
  /// **'{label}. Cannot be answered yet. Photo capture arrives with the audit-flow integration.'**
  String templateFieldPhotoSemantics(String label);

  /// Screen title: the manager's saved report definitions.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reportsTitle;

  /// Header fact under the Reports title.
  ///
  /// In en, this message translates to:
  /// **'Definitions run on demand against live data.'**
  String get reportsFact;

  /// Semantic label of the header's refresh button. Names what it does, never just 'Refresh'.
  ///
  /// In en, this message translates to:
  /// **'Refresh the saved reports'**
  String get reportsRefresh;

  /// What the skeleton and the error region say they are for, inside 'Still fetching the …'.
  ///
  /// In en, this message translates to:
  /// **'reports'**
  String get reportsSkeleton;

  /// Section rule above the list of report definitions.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reportsSection;

  /// Verb that opens the report schedules route.
  ///
  /// In en, this message translates to:
  /// **'Schedules'**
  String get reportsSchedules;

  /// In-panel empty state: this client has saved no report definitions.
  ///
  /// In en, this message translates to:
  /// **'No saved reports.'**
  String get reportsEmptyHeadline;

  /// Body of the reports empty state.
  ///
  /// In en, this message translates to:
  /// **'Build one, then run it to see how many rows it returns.'**
  String get reportsEmptyBody;

  /// Verb that opens the create-report form.
  ///
  /// In en, this message translates to:
  /// **'New report'**
  String get reportsNew;

  /// Pagination footer with no total: it never invents the number the endpoint does not send.
  ///
  /// In en, this message translates to:
  /// **'Showing the first {shown}. There are more.'**
  String reportsFooterMore(String shown);

  /// Pagination footer with a total from the server.
  ///
  /// In en, this message translates to:
  /// **'Showing the first {shown} of {total}.'**
  String reportsFooterOf(String shown, String total);

  /// Row verb that generates this report's CSV.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get reportRun;

  /// The Run verb while the report is being generated.
  ///
  /// In en, this message translates to:
  /// **'Running…'**
  String get reportRunning;

  /// Row verb that deletes a saved report definition.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get reportDelete;

  /// Row word while the report is being generated.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get reportWordRunning;

  /// Row word: the definition has not been run in this session.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get reportWordReady;

  /// Row word: the run failed. The previous count is kept.
  ///
  /// In en, this message translates to:
  /// **'Could not run'**
  String get reportWordFailed;

  /// Row word for a measured zero. Zero is a real answer, never an error and never suppressed.
  ///
  /// In en, this message translates to:
  /// **'0 rows — the query matched nothing'**
  String get reportWordZeroRows;

  /// Row word: the run produced a file.
  ///
  /// In en, this message translates to:
  /// **'Generated'**
  String get reportWordGenerated;

  /// Row subtitle after a run: the count saved and the file it was saved as.
  ///
  /// In en, this message translates to:
  /// **'{rows} rows · {filename}'**
  String reportRowsAndFile(String rows, String filename);

  /// The row count alone, in the row's spoken sentence.
  ///
  /// In en, this message translates to:
  /// **'{rows} rows'**
  String reportRowsSpoken(String rows);

  /// Toast after a run when the platform did not say where the file landed.
  ///
  /// In en, this message translates to:
  /// **'Downloaded {filename}.'**
  String reportDownloaded(String filename);

  /// Toast after a run, naming the folder the file landed in.
  ///
  /// In en, this message translates to:
  /// **'Saved {filename} to {location}.'**
  String reportSavedTo(String filename, String location);

  /// What the confirm sheet says will happen.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String reportDeleteAction(String name);

  /// First consequence of deleting a report definition.
  ///
  /// In en, this message translates to:
  /// **'The definition is removed for everyone on this client.'**
  String get reportDeleteConsequenceEveryone;

  /// Second consequence of deleting a report definition.
  ///
  /// In en, this message translates to:
  /// **'Any schedule that runs it stops running.'**
  String get reportDeleteConsequenceSchedules;

  /// Third consequence: what deleting does NOT do.
  ///
  /// In en, this message translates to:
  /// **'Files already downloaded are not affected.'**
  String get reportDeleteConsequenceFiles;

  /// The confirm sheet's commit verb.
  ///
  /// In en, this message translates to:
  /// **'Delete this report'**
  String get reportDeleteCommit;

  /// The confirm sheet's way out.
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get reportDeleteCancel;

  /// Failure toast after a delete. The reason is the sanitised server message.
  ///
  /// In en, this message translates to:
  /// **'That report was not deleted. {reason}'**
  String reportDeleteFailed(String reason);

  /// Report type: one row per submitted visit. A slug is what the machine calls it; this is what a manager picks it by.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get reportTypeVisits;

  /// Report type: one row per scored visit.
  ///
  /// In en, this message translates to:
  /// **'Scorecards'**
  String get reportTypeScorecards;

  /// Report type: one row per task raised.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get reportTypeTasks;

  /// Report type: one row per order captured in store.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get reportTypeOrders;

  /// What choosing the Visits report type will produce.
  ///
  /// In en, this message translates to:
  /// **'One row per submitted visit.'**
  String get reportTypeVisitsConsequence;

  /// What choosing the Scorecards report type will produce.
  ///
  /// In en, this message translates to:
  /// **'One row per scored visit.'**
  String get reportTypeScorecardsConsequence;

  /// What choosing the Tasks report type will produce.
  ///
  /// In en, this message translates to:
  /// **'One row per task raised.'**
  String get reportTypeTasksConsequence;

  /// What choosing the Orders report type will produce.
  ///
  /// In en, this message translates to:
  /// **'One row per order captured in store.'**
  String get reportTypeOrdersConsequence;

  /// Fallback consequence for a report type the app does not know by name.
  ///
  /// In en, this message translates to:
  /// **'One row per record.'**
  String get reportTypeOtherConsequence;

  /// Why a date box cannot be saved. The server stores filters verbatim and reads them back as ISO dates, so the format is not localised.
  ///
  /// In en, this message translates to:
  /// **'Use the form 2026-09-20, or leave it blank for any date.'**
  String get reportFilterDateFormat;

  /// Title of the create-report form.
  ///
  /// In en, this message translates to:
  /// **'New report'**
  String get reportFormTitle;

  /// Header fact on the create-report form.
  ///
  /// In en, this message translates to:
  /// **'It runs on demand against live data.'**
  String get reportFormFact;

  /// The way out of the create-report form, naming where it lands.
  ///
  /// In en, this message translates to:
  /// **'Back to Reports'**
  String get reportFormBack;

  /// The form's commit verb.
  ///
  /// In en, this message translates to:
  /// **'Create this report'**
  String get reportFormCommit;

  /// Blocked reason while the create request is in flight.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get reportFormSaving;

  /// Why Create cannot be pressed: the name box is empty.
  ///
  /// In en, this message translates to:
  /// **'Give the report a name first.'**
  String get reportFormBlockedName;

  /// Why Create cannot be pressed: the From box does not hold an ISO date.
  ///
  /// In en, this message translates to:
  /// **'The From date is not a date. Use the form 2026-09-20.'**
  String get reportFormBlockedFrom;

  /// Why Create cannot be pressed: the To box does not hold an ISO date.
  ///
  /// In en, this message translates to:
  /// **'The To date is not a date. Use the form 2026-09-20.'**
  String get reportFormBlockedTo;

  /// Why Create cannot be pressed: the window runs backwards.
  ///
  /// In en, this message translates to:
  /// **'The To date is before the From date.'**
  String get reportFormBlockedOrder;

  /// Section rule above the report's name and kind.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get reportFormSectionReport;

  /// Section rule above the filters.
  ///
  /// In en, this message translates to:
  /// **'Narrowed to'**
  String get reportFormSectionNarrowed;

  /// Label of the report's name box.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get reportFormName;

  /// Example report name, shown as a hint.
  ///
  /// In en, this message translates to:
  /// **'Outlet coverage, September'**
  String get reportFormNameHint;

  /// Help under the report's name box.
  ///
  /// In en, this message translates to:
  /// **'What a manager will look for in the list.'**
  String get reportFormNameHelp;

  /// Label of the report-type choice.
  ///
  /// In en, this message translates to:
  /// **'What it queries'**
  String get reportFormType;

  /// State line of the report-type choice while nothing is selected.
  ///
  /// In en, this message translates to:
  /// **'Pick what the report is about.'**
  String get reportFormTypeNotAnswered;

  /// Label of the filter's start-date box.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get reportFormFrom;

  /// Label of the filter's end-date box.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get reportFormTo;

  /// Help under each date box: an empty box is not a filter.
  ///
  /// In en, this message translates to:
  /// **'Leave blank for any date.'**
  String get reportFormDateHelp;

  /// Label of the outlet filter, and title of the picker sheet.
  ///
  /// In en, this message translates to:
  /// **'Outlet'**
  String get reportFormOutlet;

  /// The outlet filter's unset value — a real choice, and the first row of the picker, rather than an absence.
  ///
  /// In en, this message translates to:
  /// **'All outlets'**
  String get reportFormAllOutlets;

  /// Spoken sentence of the outlet filter row.
  ///
  /// In en, this message translates to:
  /// **'Outlet. {outlet}. Choose an outlet.'**
  String reportFormOutletSemantics(String outlet);

  /// Headline of the inline error when the create request was refused.
  ///
  /// In en, this message translates to:
  /// **'The report was not created.'**
  String get reportFormFailed;

  /// Subtitle of the outlet picker sheet.
  ///
  /// In en, this message translates to:
  /// **'The report is narrowed to the one you pick.'**
  String get reportOutletSheetSubtitle;

  /// What the outlet picker's skeleton says it is loading.
  ///
  /// In en, this message translates to:
  /// **'outlets'**
  String get reportOutletSheetSkeleton;

  /// In-panel empty state of the outlet picker.
  ///
  /// In en, this message translates to:
  /// **'No outlets on this client yet.'**
  String get reportOutletSheetEmptyHeadline;

  /// Body of the outlet picker's empty state.
  ///
  /// In en, this message translates to:
  /// **'The report will cover every outlet added later.'**
  String get reportOutletSheetEmptyBody;

  /// A schedule's cadence, as a person reads it. The slug stays English on the wire.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get cadenceDaily;

  /// A schedule's cadence, as a person reads it.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get cadenceWeekly;

  /// Screen title: which saved reports run on their own.
  ///
  /// In en, this message translates to:
  /// **'Report schedules'**
  String get schedulesTitle;

  /// Header fact under the Report schedules title.
  ///
  /// In en, this message translates to:
  /// **'A schedule runs its report server-side and delivers the result.'**
  String get schedulesFact;

  /// Semantic label of the header's refresh button.
  ///
  /// In en, this message translates to:
  /// **'Refresh the schedules'**
  String get schedulesRefresh;

  /// What the skeleton and the error region say they are for.
  ///
  /// In en, this message translates to:
  /// **'report schedules'**
  String get schedulesSkeleton;

  /// The standing note on the schedules screen. 'report.generated' is a wire event name and stays as it is.
  ///
  /// In en, this message translates to:
  /// **'Active schedules run automatically on their cadence and are sent to your webhooks subscribed to report.generated. Recipients are emailed when email is set up on the server.'**
  String get schedulesDeliveryNote;

  /// Verb that returns to the Reports list.
  ///
  /// In en, this message translates to:
  /// **'Back to reports'**
  String get schedulesBackToReports;

  /// In-panel empty state: nothing runs on its own yet.
  ///
  /// In en, this message translates to:
  /// **'No schedules.'**
  String get schedulesEmptyHeadline;

  /// Body of the schedules empty state.
  ///
  /// In en, this message translates to:
  /// **'A report runs on demand until you schedule it.'**
  String get schedulesEmptyBody;

  /// Verb that opens the create-schedule form.
  ///
  /// In en, this message translates to:
  /// **'New schedule'**
  String get schedulesNew;

  /// Section rule over the schedules that run on their own.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get schedulesGroupActive;

  /// Section rule over the paused schedules. Off is a section, not a shade.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get schedulesGroupOff;

  /// Empty line of the Active section, which renders whatever its count is.
  ///
  /// In en, this message translates to:
  /// **'Nothing is running on its own.'**
  String get schedulesGroupActiveEmpty;

  /// Empty line of the Off section.
  ///
  /// In en, this message translates to:
  /// **'Nothing is paused.'**
  String get schedulesGroupOffEmpty;

  /// Stand-in when the API sends a schedule with no report name.
  ///
  /// In en, this message translates to:
  /// **'Untitled report'**
  String get scheduleUntitledReport;

  /// A schedule that has not fired yet. Not a blank and not a zero.
  ///
  /// In en, this message translates to:
  /// **'Never run'**
  String get scheduleNeverRun;

  /// When the schedule last fired, in local time.
  ///
  /// In en, this message translates to:
  /// **'Last run {stamp}'**
  String scheduleLastRun(String stamp);

  /// When the schedule fires next, in local time.
  ///
  /// In en, this message translates to:
  /// **'Next run {stamp}'**
  String scheduleNextRun(String stamp);

  /// An active schedule the server has set no next run for.
  ///
  /// In en, this message translates to:
  /// **'Next run not scheduled'**
  String get scheduleNextRunNone;

  /// A paused schedule says so rather than showing a stale time.
  ///
  /// In en, this message translates to:
  /// **'Paused, no next run'**
  String get schedulePausedNoNextRun;

  /// Severity word on a schedule that delivers to nobody by email.
  ///
  /// In en, this message translates to:
  /// **'No recipients'**
  String get scheduleNoRecipients;

  /// The meta line under a schedule with an empty recipients list.
  ///
  /// In en, this message translates to:
  /// **'No recipients — this schedule delivers to nobody by email.'**
  String get scheduleNoRecipientsLine;

  /// How many addresses a schedule delivers to.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 recipient} other{{count} recipients}}'**
  String scheduleRecipientCount(int count);

  /// Label of the toggle that activates or pauses a schedule.
  ///
  /// In en, this message translates to:
  /// **'Runs on its own'**
  String get scheduleRunsOnItsOwn;

  /// The toggle's on word.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get scheduleOn;

  /// The toggle's off word.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get scheduleOff;

  /// Why the toggle is disabled: a request is in flight.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the server.'**
  String get scheduleWaitingForServer;

  /// Spoken state of an active schedule, at the end of the row's sentence.
  ///
  /// In en, this message translates to:
  /// **'Running on its own'**
  String get scheduleRunningOnItsOwn;

  /// Verb that expands the addresses in place.
  ///
  /// In en, this message translates to:
  /// **'Show recipients'**
  String get scheduleShowRecipients;

  /// Verb that collapses the expanded addresses.
  ///
  /// In en, this message translates to:
  /// **'Hide recipients'**
  String get scheduleHideRecipients;

  /// Row verb that generates and delivers the report immediately.
  ///
  /// In en, this message translates to:
  /// **'Run now'**
  String get scheduleRunNow;

  /// Row verb that opens this schedule's run history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get scheduleHistory;

  /// Row verb that opens the schedule for editing.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get scheduleEdit;

  /// Row verb that deletes the schedule.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get scheduleDelete;

  /// What the confirm sheet says will happen.
  ///
  /// In en, this message translates to:
  /// **'Delete this schedule?'**
  String get scheduleDeleteAction;

  /// First consequence of deleting a schedule.
  ///
  /// In en, this message translates to:
  /// **'{name} stops running on its own.'**
  String scheduleDeleteConsequenceStops(String name);

  /// Second consequence: what deleting does NOT do.
  ///
  /// In en, this message translates to:
  /// **'The saved report itself is kept.'**
  String get scheduleDeleteConsequenceReportKept;

  /// Third consequence of deleting a schedule.
  ///
  /// In en, this message translates to:
  /// **'Runs already delivered are not withdrawn.'**
  String get scheduleDeleteConsequenceRuns;

  /// The confirm sheet's commit verb.
  ///
  /// In en, this message translates to:
  /// **'Delete this schedule'**
  String get scheduleDeleteCommit;

  /// The confirm sheet's way out.
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get scheduleDeleteCancel;

  /// Lead of the failure toast after a delete.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the schedule.'**
  String get scheduleDeleteFailed;

  /// Lead of the failure toast when activating a schedule was refused. The toggle goes back.
  ///
  /// In en, this message translates to:
  /// **'Could not resume the schedule.'**
  String get scheduleResumeFailed;

  /// Lead of the failure toast when pausing a schedule was refused.
  ///
  /// In en, this message translates to:
  /// **'Could not pause the schedule.'**
  String get schedulePauseFailed;

  /// Lead of the failure toast after Run now.
  ///
  /// In en, this message translates to:
  /// **'Run failed.'**
  String get scheduleRunFailed;

  /// A failure toast: what could not be done, then the sanitised server message.
  ///
  /// In en, this message translates to:
  /// **'{lead} {reason}'**
  String scheduleFailureToast(String lead, String reason);

  /// First sentence of the Run now report. `rowsText` is the count already formatted through TiqNumber, so it groups the reader's way; `rows` only picks the singular or the plural.
  ///
  /// In en, this message translates to:
  /// **'Generated {rowsText} {rows, plural, =1{row} other{rows}}.'**
  String runNowGeneratedRows(String rowsText, int rows);

  /// How many webhooks the run was queued for.
  ///
  /// In en, this message translates to:
  /// **'Queued for {count, plural, =1{1 webhook} other{{count} webhooks}}.'**
  String runNowQueuedWebhooks(int count);

  /// The webhook channel refused the run.
  ///
  /// In en, this message translates to:
  /// **'Webhook delivery failed.'**
  String get runNowWebhookFailed;

  /// Nothing listens for the run. 'report.generated' is a wire event name.
  ///
  /// In en, this message translates to:
  /// **'Not sent: no webhook is subscribed to report.generated.'**
  String get runNowNoSubscriber;

  /// How many addresses the run is being emailed to.
  ///
  /// In en, this message translates to:
  /// **'Emailing {count, plural, =1{1 recipient} other{{count} recipients}}.'**
  String runNowEmailing(int count);

  /// Why nothing was emailed: the server has no SMTP.
  ///
  /// In en, this message translates to:
  /// **'Email is not set up on the server.'**
  String get runNowEmailNotConfigured;

  /// Why nothing was emailed: no address on the schedule is usable.
  ///
  /// In en, this message translates to:
  /// **'Not emailed: no valid email recipients.'**
  String get runNowEmailNoSubscribers;

  /// The email channel refused the run.
  ///
  /// In en, this message translates to:
  /// **'Email delivery failed.'**
  String get runNowEmailFailed;

  /// Run status word: the run is still being sent.
  ///
  /// In en, this message translates to:
  /// **'Delivering'**
  String get runStatusDelivering;

  /// Run status word: every channel took it.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get runStatusDelivered;

  /// Run status word: some channel did not take it.
  ///
  /// In en, this message translates to:
  /// **'Partly delivered'**
  String get runStatusPartial;

  /// Run status word: the run did not deliver at all.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get runStatusFailed;

  /// Run status word: nothing was subscribed, or email is not set up. Not a failure.
  ///
  /// In en, this message translates to:
  /// **'Not sent'**
  String get runStatusNotSent;

  /// Run status word: the API sent a status this app does not know. Never guessed at.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get runStatusUnknown;

  /// Title of a run the schedule fired on its own.
  ///
  /// In en, this message translates to:
  /// **'Scheduled run'**
  String get runTitleScheduled;

  /// Title of a run a manager started by hand.
  ///
  /// In en, this message translates to:
  /// **'Run now'**
  String get runTitleManual;

  /// When the run produced its file, in local time.
  ///
  /// In en, this message translates to:
  /// **'Generated {stamp}'**
  String runGeneratedAt(String stamp);

  /// A scheduled run's due time and when it actually ran. A Run now has no due time.
  ///
  /// In en, this message translates to:
  /// **'Due {due} · {generated}'**
  String runDueAndGenerated(String due, String generated);

  /// How many rows the run produced. `rowsText` is the count already formatted through TiqNumber so it groups the reader's way; `rows` only picks the singular or the plural.
  ///
  /// In en, this message translates to:
  /// **'{rowsText} {rows, plural, =1{row} other{rows}}'**
  String runRowCount(String rowsText, int rows);

  /// Pagination footer with no total. It never invents a number: a fabricated total on a delivery history is a manager believing they have seen every failure.
  ///
  /// In en, this message translates to:
  /// **'Showing the {shown} most recent. There are more.'**
  String runHistoryFooterMore(String shown);

  /// Pagination footer with a total from the server.
  ///
  /// In en, this message translates to:
  /// **'Showing the {shown} most recent of {total}.'**
  String runHistoryFooterOf(String shown, String total);

  /// Part of a channel's count line.
  ///
  /// In en, this message translates to:
  /// **'{count} delivered'**
  String runCountDelivered(int count);

  /// Part of a channel's count line.
  ///
  /// In en, this message translates to:
  /// **'{count} pending'**
  String runCountPending(int count);

  /// Part of a channel's count line.
  ///
  /// In en, this message translates to:
  /// **'{count} failed'**
  String runCountFailed(int count);

  /// Part of the email channel's count line.
  ///
  /// In en, this message translates to:
  /// **'{count} sent'**
  String runCountSent(int count);

  /// What a channel's count line says when every count is zero: it was queued and nothing has happened yet.
  ///
  /// In en, this message translates to:
  /// **'queued'**
  String get runCountsQueued;

  /// What the webhook channel did with the run.
  ///
  /// In en, this message translates to:
  /// **'Webhooks: {counts}'**
  String runWebhooksLine(String counts);

  /// Nothing listened for this run.
  ///
  /// In en, this message translates to:
  /// **'Webhooks: none subscribed'**
  String get runWebhooksNoneSubscribed;

  /// The webhook channel refused the run.
  ///
  /// In en, this message translates to:
  /// **'Webhooks: failed'**
  String get runWebhooksFailedLine;

  /// What the email channel did with the run.
  ///
  /// In en, this message translates to:
  /// **'Email: {counts}'**
  String runEmailLine(String counts);

  /// The server has no SMTP, and how many addresses went without.
  ///
  /// In en, this message translates to:
  /// **'Email: not set up ({count} not emailed)'**
  String runEmailNotSetUpLine(int count);

  /// No address on the schedule was usable.
  ///
  /// In en, this message translates to:
  /// **'Email: no valid recipients'**
  String get runEmailNoRecipientsLine;

  /// The email channel refused the run.
  ///
  /// In en, this message translates to:
  /// **'Email: failed'**
  String get runEmailFailedLine;

  /// The run has no delivery outcome at all — stated, never guessed at.
  ///
  /// In en, this message translates to:
  /// **'No delivery recorded'**
  String get runNoDeliveryRecorded;

  /// One delivery's state: waiting to be attempted.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get deliveryWordQueued;

  /// One webhook delivery's state: the endpoint took it.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get deliveryWordDelivered;

  /// One email delivery's state: the server accepted it.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get deliveryWordSent;

  /// One delivery's state: it failed and is being tried again.
  ///
  /// In en, this message translates to:
  /// **'Retrying'**
  String get deliveryWordRetrying;

  /// One webhook delivery's state: every retry is spent.
  ///
  /// In en, this message translates to:
  /// **'Gave up'**
  String get deliveryWordGaveUp;

  /// One email delivery's state: every retry is spent.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get deliveryWordEmailFailed;

  /// How many times a delivery has been tried.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 attempt} other{{count} attempts}}'**
  String deliveryAttempts(int count);

  /// The status code the endpoint answered with. HTTP is a protocol name and stays as it is.
  ///
  /// In en, this message translates to:
  /// **'HTTP {code}'**
  String deliveryHttpStatus(int code);

  /// A webhook delivery with no attempts behind it.
  ///
  /// In en, this message translates to:
  /// **'Not sent yet'**
  String get deliveryNotSentYet;

  /// A webhook delivery that was attempted and got nothing back.
  ///
  /// In en, this message translates to:
  /// **'No response'**
  String get deliveryNoResponse;

  /// Why a run has no download link. The API does not say which of the two it is, so both are named.
  ///
  /// In en, this message translates to:
  /// **'No download link. Links need signed links set up on the server, and stop working 7 days after the run.'**
  String get runNoCsvLinkNote;

  /// Screen title: a schedule's runs, newest first.
  ///
  /// In en, this message translates to:
  /// **'Run history'**
  String get runHistoryTitle;

  /// The way out of the run history, naming where it lands.
  ///
  /// In en, this message translates to:
  /// **'Back to Report schedules'**
  String get runHistoryBack;

  /// What the skeleton and the error region say they are for.
  ///
  /// In en, this message translates to:
  /// **'report runs'**
  String get runHistorySkeleton;

  /// Verb that reloads the first page of runs.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get runHistoryRefresh;

  /// Section rule above the list of runs.
  ///
  /// In en, this message translates to:
  /// **'Runs'**
  String get runHistorySection;

  /// In-panel empty state: the schedule has never fired.
  ///
  /// In en, this message translates to:
  /// **'No runs yet.'**
  String get runHistoryEmptyHeadline;

  /// Body of the run history's empty state.
  ///
  /// In en, this message translates to:
  /// **'A run appears each time the schedule fires or you use Run now.'**
  String get runHistoryEmptyBody;

  /// Verb that fetches the next page of runs.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get runHistoryLoadMore;

  /// Row verb that opens a run's per-channel results.
  ///
  /// In en, this message translates to:
  /// **'Show run details'**
  String get runShowDetails;

  /// Row verb that closes a run's per-channel results.
  ///
  /// In en, this message translates to:
  /// **'Hide run details'**
  String get runHideDetails;

  /// Row verb that opens the signed link sheet. CSV is a file format and stays as it is.
  ///
  /// In en, this message translates to:
  /// **'Download CSV'**
  String get runDownloadCsv;

  /// A run row's subtitle: how many rows, and what each channel did.
  ///
  /// In en, this message translates to:
  /// **'{rows} · {delivery}'**
  String runRowSubtitle(String rows, String delivery);

  /// Section rule over a run's webhook results.
  ///
  /// In en, this message translates to:
  /// **'Webhooks'**
  String get runDetailSectionWebhooks;

  /// Section rule over a run's per-recipient email deliveries.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get runDetailSectionEmail;

  /// Section rule over what happened to the run's CSV.
  ///
  /// In en, this message translates to:
  /// **'The file'**
  String get runDetailSectionFile;

  /// The run has a working link, with no expiry given.
  ///
  /// In en, this message translates to:
  /// **'Signed download link.'**
  String get runSignedLink;

  /// The run has a working link and when it stops working.
  ///
  /// In en, this message translates to:
  /// **'Signed download link, works until {stamp}.'**
  String runSignedLinkUntil(String stamp);

  /// Detail note: nothing listened for this run. 'report.generated' is a wire event name.
  ///
  /// In en, this message translates to:
  /// **'Not sent: no webhook is subscribed to report.generated.'**
  String get runWebhookNoSubscriber;

  /// Detail note: the webhook channel refused the run, with no diagnostic.
  ///
  /// In en, this message translates to:
  /// **'Webhook delivery failed.'**
  String get runWebhookDeliveryFailed;

  /// Detail note: the webhook channel refused the run, and why.
  ///
  /// In en, this message translates to:
  /// **'Webhook delivery failed: {detail}'**
  String runWebhookDeliveryFailedWhy(String detail);

  /// Detail note: the run was queued, and its targets no longer exist.
  ///
  /// In en, this message translates to:
  /// **'The webhooks this run was sent to have since been deleted.'**
  String get runWebhookTargetsDeleted;

  /// Detail note: the run has no webhook outcome at all.
  ///
  /// In en, this message translates to:
  /// **'No webhook delivery was recorded.'**
  String get runWebhookNoneRecorded;

  /// Detail note: the server has no SMTP, and how many addresses went without.
  ///
  /// In en, this message translates to:
  /// **'Not emailed to {count, plural, =1{1 recipient} other{{count} recipients}}: email is not set up on the server.'**
  String runEmailNotConfiguredDetail(int count);

  /// Detail note: no address on the schedule was usable.
  ///
  /// In en, this message translates to:
  /// **'Not emailed: no valid email recipients.'**
  String get runEmailNoRecipientsDetail;

  /// Detail note: the email channel refused the run, with no diagnostic.
  ///
  /// In en, this message translates to:
  /// **'Email delivery failed.'**
  String get runEmailDeliveryFailed;

  /// Detail note: the email channel refused the run, and why.
  ///
  /// In en, this message translates to:
  /// **'Email delivery failed: {detail}'**
  String runEmailDeliveryFailedWhy(String detail);

  /// Detail note: the run has no email outcome at all.
  ///
  /// In en, this message translates to:
  /// **'No email delivery was recorded.'**
  String get runEmailNoneRecorded;

  /// What the per-recipient skeleton says it is loading.
  ///
  /// In en, this message translates to:
  /// **'email deliveries'**
  String get runEmailSkeleton;

  /// The run queued email and the list came back empty.
  ///
  /// In en, this message translates to:
  /// **'No emails were queued for this run.'**
  String get runEmailNoneQueued;

  /// Subtitle of the CSV link sheet, when the link has no stated expiry.
  ///
  /// In en, this message translates to:
  /// **'Open this link in a browser to download the report. Anyone with the link can download it.'**
  String get csvLinkSheetSubtitle;

  /// Subtitle of the CSV link sheet, naming when the link stops working.
  ///
  /// In en, this message translates to:
  /// **'Open this link in a browser to download the report. Anyone with the link can download it until {stamp}.'**
  String csvLinkSheetSubtitleUntil(String stamp);

  /// The CSV link sheet's action. The console has no way to open a URL, so the link is text and Copy is the verb.
  ///
  /// In en, this message translates to:
  /// **'Copy the link'**
  String get csvLinkCopy;

  /// Title of the create-schedule form.
  ///
  /// In en, this message translates to:
  /// **'New schedule'**
  String get scheduleFormTitleNew;

  /// Title of the edit-schedule form.
  ///
  /// In en, this message translates to:
  /// **'Edit schedule'**
  String get scheduleFormTitleEdit;

  /// Header fact on the schedule form.
  ///
  /// In en, this message translates to:
  /// **'It runs server-side and delivers the result.'**
  String get scheduleFormFact;

  /// The way out of the schedule form, naming where it lands.
  ///
  /// In en, this message translates to:
  /// **'Back to Report schedules'**
  String get scheduleFormBack;

  /// The create form's commit verb.
  ///
  /// In en, this message translates to:
  /// **'Create this schedule'**
  String get scheduleFormCommitNew;

  /// The edit form's commit verb.
  ///
  /// In en, this message translates to:
  /// **'Save these changes'**
  String get scheduleFormCommitEdit;

  /// Blocked reason while the save is in flight.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get scheduleFormSaving;

  /// Why the commit cannot be pressed: the report list has not arrived.
  ///
  /// In en, this message translates to:
  /// **'Loading the saved reports.'**
  String get scheduleFormBlockedLoading;

  /// Why the commit cannot be pressed: the report list failed.
  ///
  /// In en, this message translates to:
  /// **'The saved reports could not be loaded, so there is nothing to schedule yet.'**
  String get scheduleFormBlockedReportsFailed;

  /// Why the commit cannot be pressed: this client has no report definitions.
  ///
  /// In en, this message translates to:
  /// **'There are no saved reports yet. Build one on Reports first.'**
  String get scheduleFormBlockedNoReports;

  /// Why the commit cannot be pressed: no report is chosen.
  ///
  /// In en, this message translates to:
  /// **'Pick the report this schedule runs.'**
  String get scheduleFormBlockedNoReport;

  /// Why the commit cannot be pressed: no cadence is chosen. Also the cadence choice's own state line.
  ///
  /// In en, this message translates to:
  /// **'Pick how often it runs.'**
  String get scheduleFormBlockedNoCadence;

  /// Section rule above the schedule's report. Also the label and the picker sheet's title.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get scheduleFormSectionReport;

  /// Section rule above the cadence and the recipients.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get scheduleFormSectionSchedule;

  /// Subtitle of the read-only report on an edited schedule.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get scheduleFormReportLocked;

  /// Why the report cannot be picked when editing: the PATCH route accepts only active, cadence and recipients.
  ///
  /// In en, this message translates to:
  /// **'The report on a schedule cannot be changed. To schedule a different report, create a new schedule.'**
  String get scheduleFormReportLockedNote;

  /// Spoken sentence of the read-only report row.
  ///
  /// In en, this message translates to:
  /// **'{name}. Locked. {note}'**
  String scheduleFormReportLockedSemantics(String name, String note);

  /// What the report picker's skeleton says it is loading.
  ///
  /// In en, this message translates to:
  /// **'saved reports'**
  String get scheduleFormReportsSkeleton;

  /// In-panel empty state: there is nothing to schedule.
  ///
  /// In en, this message translates to:
  /// **'No saved reports yet.'**
  String get scheduleFormNoReportsHeadline;

  /// Body of the no-reports empty state.
  ///
  /// In en, this message translates to:
  /// **'Build one on the Reports screen, then schedule it.'**
  String get scheduleFormNoReportsBody;

  /// Subtitle of the report field before a report is chosen.
  ///
  /// In en, this message translates to:
  /// **'Not picked yet'**
  String get scheduleFormReportNotPicked;

  /// Spoken sentence of the report picker row.
  ///
  /// In en, this message translates to:
  /// **'Report. {report}. Choose the report this schedule runs.'**
  String scheduleFormReportSemantics(String report);

  /// Label of the cadence choice.
  ///
  /// In en, this message translates to:
  /// **'How often'**
  String get scheduleFormCadence;

  /// What choosing Daily means. UTC is a time standard and stays as it is.
  ///
  /// In en, this message translates to:
  /// **'Every day, 06:00 UTC.'**
  String get scheduleFormCadenceDailyConsequence;

  /// What choosing Weekly means.
  ///
  /// In en, this message translates to:
  /// **'Every Monday, 06:00 UTC.'**
  String get scheduleFormCadenceWeeklyConsequence;

  /// Help under the cadence choice. 'report.generated' is a wire event name.
  ///
  /// In en, this message translates to:
  /// **'Runs automatically on this cadence (UTC), is sent to webhooks subscribed to report.generated, and is emailed to the recipients when email is set up on the server.'**
  String get scheduleFormCadenceHelp;

  /// Label of the recipients box.
  ///
  /// In en, this message translates to:
  /// **'Recipients'**
  String get scheduleFormRecipients;

  /// Help under the recipients box.
  ///
  /// In en, this message translates to:
  /// **'Email addresses, one per line or separated by commas.'**
  String get scheduleFormRecipientsHelp;

  /// Why the recipients box cannot be saved: it is empty. Mirrors the backend.
  ///
  /// In en, this message translates to:
  /// **'Add at least one recipient'**
  String get scheduleFormRecipientsEmpty;

  /// Why the recipients box cannot be saved, naming the first entry that is not an address.
  ///
  /// In en, this message translates to:
  /// **'Not an email address: {entry}'**
  String scheduleFormRecipientsInvalid(String entry);

  /// Why the recipients box cannot be saved: the API's cap.
  ///
  /// In en, this message translates to:
  /// **'At most {max} recipients'**
  String scheduleFormRecipientsTooMany(int max);

  /// Headline when the create request was refused.
  ///
  /// In en, this message translates to:
  /// **'The schedule was not created.'**
  String get scheduleFormFailedNew;

  /// Headline when the update request was refused.
  ///
  /// In en, this message translates to:
  /// **'The changes were not saved.'**
  String get scheduleFormFailedEdit;

  /// The inline error's body: what was refused, then the sanitised server message.
  ///
  /// In en, this message translates to:
  /// **'{headline} {reason}'**
  String scheduleFormFailedBody(String headline, String reason);

  /// Subtitle of the report picker sheet.
  ///
  /// In en, this message translates to:
  /// **'The schedule runs this definition on its cadence.'**
  String get scheduleReportSheetSubtitle;

  /// A moment less than a minute ago.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get relativeJustNow;

  /// A moment less than a minute from now.
  ///
  /// In en, this message translates to:
  /// **'in under a minute'**
  String get relativeUnderAMinute;

  /// How long ago, in minutes. The unit is abbreviated because it sits in a row subtitle.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String relativeMinutesAgo(int minutes);

  /// How long ago, in hours.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String relativeHoursAgo(int hours);

  /// How long ago, in days.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String relativeDaysAgo(int days);

  /// How long until, in minutes.
  ///
  /// In en, this message translates to:
  /// **'in {minutes}m'**
  String relativeInMinutes(int minutes);

  /// How long until, in hours.
  ///
  /// In en, this message translates to:
  /// **'in {hours}h'**
  String relativeInHours(int hours);

  /// How long until, in days.
  ///
  /// In en, this message translates to:
  /// **'in {days}d'**
  String relativeInDays(int days);

  /// An endpoint that is receiving.
  ///
  /// In en, this message translates to:
  /// **'Healthy'**
  String get webhookHealthHealthy;

  /// An endpoint some deliveries to which are failing and still retrying.
  ///
  /// In en, this message translates to:
  /// **'Failing'**
  String get webhookHealthFailing;

  /// An endpoint a delivery to which has given up after every retry.
  ///
  /// In en, this message translates to:
  /// **'Unhealthy'**
  String get webhookHealthUnhealthy;

  /// A delivery waiting to be attempted.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get webhookDeliveryQueued;

  /// A delivery the endpoint took.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get webhookDeliveryDelivered;

  /// A delivery that failed and is being tried again.
  ///
  /// In en, this message translates to:
  /// **'Retrying'**
  String get webhookDeliveryRetrying;

  /// A delivery whose retries are spent.
  ///
  /// In en, this message translates to:
  /// **'Gave up'**
  String get webhookDeliveryGaveUp;

  /// Screen title: the client's outbound endpoints.
  ///
  /// In en, this message translates to:
  /// **'Webhooks'**
  String get webhooksTitle;

  /// Header fact. POST is an HTTP method and stays as it is.
  ///
  /// In en, this message translates to:
  /// **'Each endpoint receives a POST when its event fires.'**
  String get webhooksFactPost;

  /// Header fact: how long the server keeps trying.
  ///
  /// In en, this message translates to:
  /// **'Failed deliveries retry for about eight hours.'**
  String get webhooksFactRetries;

  /// Semantic label of the header's refresh button.
  ///
  /// In en, this message translates to:
  /// **'Refresh the endpoints'**
  String get webhooksRefresh;

  /// What the skeleton and the error region say they are for.
  ///
  /// In en, this message translates to:
  /// **'webhooks'**
  String get webhooksSkeleton;

  /// Section rule above the list of endpoints.
  ///
  /// In en, this message translates to:
  /// **'Endpoints'**
  String get webhooksSection;

  /// The standing warning above the list when some endpoint has stopped receiving.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 endpoint is not receiving. A delivery to it has given up after every retry.} other{{count} endpoints are not receiving. A delivery to them has given up after every retry.}}'**
  String webhooksUnhealthyNote(int count);

  /// In-panel empty state: this client forwards nothing.
  ///
  /// In en, this message translates to:
  /// **'No endpoints registered.'**
  String get webhooksEmptyHeadline;

  /// Body of the webhooks empty state.
  ///
  /// In en, this message translates to:
  /// **'Add one to forward events to an external system.'**
  String get webhooksEmptyBody;

  /// Verb that opens the create sheet. Also the sheet's title.
  ///
  /// In en, this message translates to:
  /// **'Add an endpoint'**
  String get webhookAdd;

  /// Row subtitle for an endpoint nothing has been sent to.
  ///
  /// In en, this message translates to:
  /// **'No deliveries yet'**
  String get webhookNoDeliveriesYet;

  /// Row subtitle: when something was last sent to this endpoint.
  ///
  /// In en, this message translates to:
  /// **'Last delivery {when}'**
  String webhookLastDelivery(String when);

  /// The endpoint has a signing secret. The WORD, never the value: the secret is not on this screen at all. HMAC is a standard's name.
  ///
  /// In en, this message translates to:
  /// **'Signed — deliveries carry an HMAC signature.'**
  String get webhookSigned;

  /// The endpoint has no signing secret.
  ///
  /// In en, this message translates to:
  /// **'Not signed — deliveries carry no signature.'**
  String get webhookNotSigned;

  /// The signing state in the row's spoken sentence.
  ///
  /// In en, this message translates to:
  /// **'Signed'**
  String get webhookSignedShort;

  /// The signing state in the row's spoken sentence.
  ///
  /// In en, this message translates to:
  /// **'Not signed'**
  String get webhookNotSignedShort;

  /// Label of the toggle that activates or pauses an endpoint.
  ///
  /// In en, this message translates to:
  /// **'Receiving events'**
  String get webhookReceivingEvents;

  /// The toggle's on word.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get webhookOn;

  /// The toggle's off word.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get webhookOff;

  /// Why the toggle is disabled: a request is in flight.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the server.'**
  String get webhookWaitingForServer;

  /// Spoken state of an active endpoint.
  ///
  /// In en, this message translates to:
  /// **'Receiving'**
  String get webhookReceiving;

  /// Spoken state of a paused endpoint.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get webhookPaused;

  /// Row verb that opens this endpoint's recent deliveries.
  ///
  /// In en, this message translates to:
  /// **'Show deliveries'**
  String get webhookShowDeliveries;

  /// Row verb that closes the deliveries list.
  ///
  /// In en, this message translates to:
  /// **'Hide deliveries'**
  String get webhookHideDeliveries;

  /// Row verb that deletes the endpoint.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get webhookDelete;

  /// Failure toast when activating was refused. The toggle goes back.
  ///
  /// In en, this message translates to:
  /// **'That endpoint was not resumed. {reason}'**
  String webhookResumeFailed(String reason);

  /// Failure toast when pausing was refused.
  ///
  /// In en, this message translates to:
  /// **'That endpoint was not paused. {reason}'**
  String webhookPauseFailed(String reason);

  /// What the confirm sheet says will happen.
  ///
  /// In en, this message translates to:
  /// **'Delete this endpoint?'**
  String get webhookDeleteAction;

  /// First consequence of deleting an endpoint.
  ///
  /// In en, this message translates to:
  /// **'It stops receiving events immediately.'**
  String get webhookDeleteConsequenceStops;

  /// Second consequence of deleting an endpoint.
  ///
  /// In en, this message translates to:
  /// **'Its delivery history is removed with it.'**
  String get webhookDeleteConsequenceHistory;

  /// Third consequence: what deleting does NOT do.
  ///
  /// In en, this message translates to:
  /// **'Nothing already delivered is withdrawn.'**
  String get webhookDeleteConsequenceDelivered;

  /// The confirm sheet's commit verb.
  ///
  /// In en, this message translates to:
  /// **'Delete this endpoint'**
  String get webhookDeleteCommit;

  /// The confirm sheet's way out.
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get webhookDeleteCancel;

  /// Failure toast after a delete.
  ///
  /// In en, this message translates to:
  /// **'That endpoint was not deleted. {reason}'**
  String webhookDeleteFailed(String reason);

  /// Section rule above an endpoint's deliveries.
  ///
  /// In en, this message translates to:
  /// **'Recent deliveries'**
  String get webhookDeliveriesSection;

  /// What the deliveries skeleton says it is loading.
  ///
  /// In en, this message translates to:
  /// **'deliveries'**
  String get webhookDeliveriesSkeleton;

  /// In-panel empty state: nothing has been sent to this endpoint.
  ///
  /// In en, this message translates to:
  /// **'No deliveries yet.'**
  String get webhookDeliveriesEmptyHeadline;

  /// Body of the deliveries empty state.
  ///
  /// In en, this message translates to:
  /// **'One appears each time the event fires.'**
  String get webhookDeliveriesEmptyBody;

  /// When a delivery succeeded.
  ///
  /// In en, this message translates to:
  /// **'Delivered {when}'**
  String webhookDeliveredWhen(String when);

  /// When a failing delivery will be tried again.
  ///
  /// In en, this message translates to:
  /// **'Next retry {when}'**
  String webhookNextRetryWhen(String when);

  /// A delivery whose retries are spent.
  ///
  /// In en, this message translates to:
  /// **'No more retries'**
  String get webhookNoMoreRetries;

  /// When a delivery was queued, where nothing better is known.
  ///
  /// In en, this message translates to:
  /// **'Created {when}'**
  String webhookCreatedWhen(String when);

  /// The status code the endpoint answered with. HTTP is a protocol name.
  ///
  /// In en, this message translates to:
  /// **'HTTP {code}'**
  String webhookHttpStatus(int code);

  /// A delivery with no attempts behind it.
  ///
  /// In en, this message translates to:
  /// **'Not sent yet'**
  String get webhookNotSentYet;

  /// A delivery that was attempted and got nothing back.
  ///
  /// In en, this message translates to:
  /// **'No response'**
  String get webhookNoResponse;

  /// How many times a delivery has been tried.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 attempt} other{{count} attempts}}'**
  String webhookAttempts(int count);

  /// Row verb that queues a delivery again.
  ///
  /// In en, this message translates to:
  /// **'Redeliver'**
  String get webhookRedeliver;

  /// The Redeliver verb while the request is in flight.
  ///
  /// In en, this message translates to:
  /// **'Queueing…'**
  String get webhookQueueing;

  /// Toast after a successful redeliver.
  ///
  /// In en, this message translates to:
  /// **'Redelivery queued.'**
  String get webhookRedeliveryQueued;

  /// Failure toast after a redeliver.
  ///
  /// In en, this message translates to:
  /// **'That delivery was not re-queued. {reason}'**
  String webhookRedeliverFailed(String reason);

  /// Subtitle of the create sheet.
  ///
  /// In en, this message translates to:
  /// **'It receives a POST every time its event fires.'**
  String get webhookCreateSubtitle;

  /// Label of the endpoint's URL box.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get webhookCreateAddress;

  /// Help under the URL box. Mirrors the server's own guard.
  ///
  /// In en, this message translates to:
  /// **'A public http or https address the server can reach.'**
  String get webhookCreateAddressHelp;

  /// Why the URL cannot be saved: it does not parse.
  ///
  /// In en, this message translates to:
  /// **'That is not a web address.'**
  String get webhookCreateNotAUrl;

  /// Why the URL cannot be saved: the scheme is not http(s). The schemes are not translated.
  ///
  /// In en, this message translates to:
  /// **'The address has to start with http:// or https://.'**
  String get webhookCreateWrongScheme;

  /// Why Add cannot be pressed: the URL box is empty.
  ///
  /// In en, this message translates to:
  /// **'Give the endpoint a web address.'**
  String get webhookCreateBlockedUrl;

  /// Why Add cannot be pressed: no event is chosen. Also the event choice's own state line.
  ///
  /// In en, this message translates to:
  /// **'Pick the event it listens for.'**
  String get webhookCreateBlockedEvent;

  /// Label of the event choice. The event names themselves are wire values and are not translated.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get webhookCreateEvent;

  /// Label of the write-only secret box.
  ///
  /// In en, this message translates to:
  /// **'Signing secret (optional)'**
  String get webhookCreateSecret;

  /// Help under the secret box: it is write-only by construction.
  ///
  /// In en, this message translates to:
  /// **'Deliveries are signed with it. It is stored on the server and never shown again — keep your own copy.'**
  String get webhookCreateSecretHelp;

  /// Headline of the inline error when the create request was refused.
  ///
  /// In en, this message translates to:
  /// **'The endpoint was not added.'**
  String get webhookCreateFailed;

  /// The create sheet's commit verb.
  ///
  /// In en, this message translates to:
  /// **'Add this endpoint'**
  String get webhookCreateCommit;

  /// Blocked reason while the create request is in flight.
  ///
  /// In en, this message translates to:
  /// **'Adding…'**
  String get webhookCreateAdding;

  /// The create sheet's way out.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get webhookCreateCancel;

  /// Screen title of the team channel. Also the Messages feed's own rail chip and section rule.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messagesTitle;

  /// Header fact under the Messages title.
  ///
  /// In en, this message translates to:
  /// **'Everything the team can see.'**
  String get messagesFact;

  /// Semantic label of the header's refresh button.
  ///
  /// In en, this message translates to:
  /// **'Refresh the team channel'**
  String get messagesRefresh;

  /// Semantic label of the rail that switches between Messages and Announcements.
  ///
  /// In en, this message translates to:
  /// **'Which feed'**
  String get messagesWhichFeed;

  /// The Announcements feed's rail chip and section rule.
  ///
  /// In en, this message translates to:
  /// **'Announcements'**
  String get messagesFeedAnnouncements;

  /// What the Messages skeleton and error region say they are for.
  ///
  /// In en, this message translates to:
  /// **'messages'**
  String get messagesSkeleton;

  /// What the Announcements skeleton and error region say they are for.
  ///
  /// In en, this message translates to:
  /// **'announcements'**
  String get announcementsSkeleton;

  /// In-panel empty state of the message thread.
  ///
  /// In en, this message translates to:
  /// **'No messages yet.'**
  String get messagesEmptyHeadline;

  /// Body of the messages empty state.
  ///
  /// In en, this message translates to:
  /// **'Anything you send below reaches the whole team.'**
  String get messagesEmptyBody;

  /// In-panel empty state of the announcements feed.
  ///
  /// In en, this message translates to:
  /// **'No announcements yet.'**
  String get announcementsEmptyHeadline;

  /// Body of the announcements empty state for somebody who may post. The guidance names a next action only if you are allowed to do it.
  ///
  /// In en, this message translates to:
  /// **'Post one and every user on this client sees it.'**
  String get announcementsEmptyBodyCanPost;

  /// Body of the announcements empty state for somebody who may not post.
  ///
  /// In en, this message translates to:
  /// **'Your managers post here when something affects everyone.'**
  String get announcementsEmptyBodyReadOnly;

  /// Verb that opens the compose sheet. Also the sheet's title.
  ///
  /// In en, this message translates to:
  /// **'New announcement'**
  String get announcementNew;

  /// Toast after a successful post.
  ///
  /// In en, this message translates to:
  /// **'Posted to everyone on this client.'**
  String get announcementPosted;

  /// Failure toast after a post.
  ///
  /// In en, this message translates to:
  /// **'That announcement was not posted. {reason}'**
  String announcementPostFailed(String reason);

  /// Headline of a message that is one photo and no words.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get messagePhotoOne;

  /// Headline of a message that is several photos and no words.
  ///
  /// In en, this message translates to:
  /// **'{count} photos'**
  String messagePhotoMany(int count);

  /// Meta word: the message went to one person.
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get messageDirect;

  /// Meta word: the message went to the whole team.
  ///
  /// In en, this message translates to:
  /// **'Broadcast'**
  String get messageBroadcast;

  /// Who sent the message, by name and never by id.
  ///
  /// In en, this message translates to:
  /// **'From {name}'**
  String messageFrom(String name);

  /// Who a direct message went to, by name.
  ///
  /// In en, this message translates to:
  /// **'To {name}'**
  String messageTo(String name);

  /// Who a broadcast went to.
  ///
  /// In en, this message translates to:
  /// **'To the whole team'**
  String get messageToTeam;

  /// A direct message whose recipient the roster cannot name.
  ///
  /// In en, this message translates to:
  /// **'Direct message'**
  String get messageDirectUnknownRecipient;

  /// The explicit unknown state. The id appears here and nowhere else: a deleted account, or a roster that has not loaded.
  ///
  /// In en, this message translates to:
  /// **'Sender not on the roster: {id}'**
  String messageSenderNotOnRoster(String id);

  /// The explicit unknown state for the recipient.
  ///
  /// In en, this message translates to:
  /// **'Recipient not on the roster: {id}'**
  String messageRecipientNotOnRoster(String id);

  /// How many photos a message carries, in its spoken sentence.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo} other{{count} photos}}'**
  String messagePhotoCount(int count);

  /// What a reader hears on one attachment thumb, so two thumbs on a message are told apart.
  ///
  /// In en, this message translates to:
  /// **'Photo {index} of {count}'**
  String messagePhotoOfCount(int index, int count);

  /// How to reach the id, at the end of the row's spoken sentence.
  ///
  /// In en, this message translates to:
  /// **'Long press to copy the message id'**
  String get messageLongPressForId;

  /// Toast after a long press copies the id.
  ///
  /// In en, this message translates to:
  /// **'Message id copied.'**
  String get messageIdCopied;

  /// Subtitle of an announcement row.
  ///
  /// In en, this message translates to:
  /// **'Broadcast to the whole client'**
  String get announcementSubtitle;

  /// Spoken sentence of an announcement row.
  ///
  /// In en, this message translates to:
  /// **'{title}. {body}. Broadcast to the whole client.'**
  String announcementSemantics(String title, String body);

  /// Title of the camera-or-library sheet.
  ///
  /// In en, this message translates to:
  /// **'Add a photo'**
  String get attachSheetTitle;

  /// Subtitle of the attach sheet: an abandoned draft leaves nothing on the server.
  ///
  /// In en, this message translates to:
  /// **'It is uploaded when the message is sent, not before.'**
  String get attachSheetSubtitle;

  /// The camera source.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get attachCamera;

  /// The library source.
  ///
  /// In en, this message translates to:
  /// **'Choose from the library'**
  String get attachGallery;

  /// Subtitle of the compose sheet.
  ///
  /// In en, this message translates to:
  /// **'Every user on this client sees it.'**
  String get announcementSheetSubtitle;

  /// Label of the announcement's title box.
  ///
  /// In en, this message translates to:
  /// **'Headline'**
  String get announcementSheetHeadline;

  /// Label of the announcement's body box.
  ///
  /// In en, this message translates to:
  /// **'What it says'**
  String get announcementSheetBody;

  /// Why Post cannot be pressed: the headline is empty. The endpoint rejects a blank either way.
  ///
  /// In en, this message translates to:
  /// **'Give the announcement a headline.'**
  String get announcementSheetBlockedTitle;

  /// Why Post cannot be pressed: the body is empty.
  ///
  /// In en, this message translates to:
  /// **'Say what it is about.'**
  String get announcementSheetBlockedBody;

  /// The compose sheet's commit verb.
  ///
  /// In en, this message translates to:
  /// **'Post this announcement'**
  String get announcementSheetCommit;

  /// The compose sheet's way out.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get announcementSheetCancel;

  /// Label of the composer's text box.
  ///
  /// In en, this message translates to:
  /// **'Message the team'**
  String get composerLabel;

  /// Headline of the composer's inline error.
  ///
  /// In en, this message translates to:
  /// **'Not sent.'**
  String get composerNotSent;

  /// The composer's commit verb.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get composerSend;

  /// The Send verb while the message is in flight, and its blocked reason.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get composerSending;

  /// Why Send is not armed: the draft is empty. A Send with nothing to send is not armed.
  ///
  /// In en, this message translates to:
  /// **'Write something, or add a photo.'**
  String get composerBlockedEmpty;

  /// Semantic label of the attach button.
  ///
  /// In en, this message translates to:
  /// **'Add a photo to this message'**
  String get composerAddPhoto;

  /// Semantic label of the attach button once the cap is reached — it says why it stops.
  ///
  /// In en, this message translates to:
  /// **'Up to {max} photos per message'**
  String composerPhotoCap(int max);

  /// The line beside the attach button while nothing is attached.
  ///
  /// In en, this message translates to:
  /// **'Up to {max} photos.'**
  String composerPhotoCapLine(int max);

  /// The line beside the attach button once photos are in the draft.
  ///
  /// In en, this message translates to:
  /// **'{count} of {max} photos attached.'**
  String composerPhotosAttached(int count, int max);

  /// A denied camera permission lands here. It says so rather than doing nothing.
  ///
  /// In en, this message translates to:
  /// **'Could not add a photo. Check camera and photo permissions.'**
  String get composerPhotoFailed;

  /// On an upload failure nothing is sent and the draft — words and photos — stays where the sender left it.
  ///
  /// In en, this message translates to:
  /// **'A photo failed to upload, so nothing was sent. {reason} Your draft is kept.'**
  String composerUploadFailed(String reason);

  /// The send was refused and the draft is kept for a retry.
  ///
  /// In en, this message translates to:
  /// **'Message not sent. {reason} Your draft is kept.'**
  String composerSendFailed(String reason);

  /// What a reader hears on a picked photo waiting in the draft.
  ///
  /// In en, this message translates to:
  /// **'Photo {index} ready to send'**
  String pendingPhotoReady(int index);

  /// Semantic label of the button that removes a picked photo. Its own node, beside the image's, not wrapped around it.
  ///
  /// In en, this message translates to:
  /// **'Take photo {index} out of this message'**
  String pendingPhotoRemove(int index);

  /// Title of the sheet that shows one message attachment full size.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get attachmentSheetTitle;

  /// What the attachment sheet's skeleton says it is loading.
  ///
  /// In en, this message translates to:
  /// **'the photo'**
  String get attachmentSheetSkeleton;

  /// The attachment sheet's way out.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get attachmentSheetClose;

  /// Headline when the bytes arrived and are not an image this device can decode.
  ///
  /// In en, this message translates to:
  /// **'This photo could not be displayed.'**
  String get attachmentUndecodableHeadline;

  /// Body of the undecodable-photo error. Retry would not help, so none is offered.
  ///
  /// In en, this message translates to:
  /// **'The file arrived, but it is not an image this device can decode.'**
  String get attachmentUndecodableBody;

  /// A figure computed from too thin a sample. It greys the figure and drops the delta.
  ///
  /// In en, this message translates to:
  /// **'small sample'**
  String get figureSmallSample;

  /// A figure with no score behind it.
  ///
  /// In en, this message translates to:
  /// **'not scored'**
  String get figureNotScored;

  /// The marker beside a figure that is not final yet.
  ///
  /// In en, this message translates to:
  /// **'Provisional'**
  String get figureProvisional;

  /// Spoken first in a picker option's label when that option is the one currently set. On screen the same fact is a tick — this is the word, so the tick is not the only channel and a reader can tell which value is set without leaving the sheet.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get pickerSelected;

  /// Spoken in a pin report's label to say that photographic evidence is attached. On screen the photograph itself is shown, not a count of them — a manager deciding where a shop is from a count is deciding from nothing — but a screen reader cannot be shown a photograph, and silence would be worse than a number.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 storefront photograph attached} other{{count} storefront photographs attached}}'**
  String outletDisputePhotoCount(int count);

  /// Title of an order row while the store list is still being fetched. Not "Store not on this list": nothing is yet known either way, and the ids in the meta line are what tells two such rows apart.
  ///
  /// In en, this message translates to:
  /// **'Store list still loading'**
  String get ordersStoreListLoading;

  /// Title of an order row when the store list failed to load. The order is real; what is missing is the register that would name its store.
  ///
  /// In en, this message translates to:
  /// **'Store list did not load'**
  String get ordersStoreListUnavailable;

  /// Title of a beat plan stop whose store is genuinely absent from the loaded store list.
  ///
  /// In en, this message translates to:
  /// **'Store not on this list'**
  String get beatPlanStopUnknownStore;

  /// Title of a beat plan stop while the store list is still being fetched.
  ///
  /// In en, this message translates to:
  /// **'Store list still loading'**
  String get beatPlanStopStoreLoading;

  /// Title of a beat plan stop when the store list failed to load.
  ///
  /// In en, this message translates to:
  /// **'Store list did not load'**
  String get beatPlanStopStoreUnavailable;

  /// Reason shown in place of an attainment percentage for a level whose targets all ask for nought units. The server returns no percentage there, because a share of nothing is not a number.
  ///
  /// In en, this message translates to:
  /// **'Every target at this level is 0 units, so there is nothing to attain.'**
  String get salesLevelZeroTarget;

  /// Reason shown in place of an attainment percentage the server did not send. Said in words rather than guessed at from the units, which would be inventing a total.
  ///
  /// In en, this message translates to:
  /// **'The share of target was not worked out for this level.'**
  String get salesLevelAttainmentUnknown;

  /// Word for a SKU or scope whose target asks for nought units — a real target that happens to ask for nothing. Distinct from salesNoTarget, which is the absence of one: a row that printed "target 0 units" and "No target" in the same breath said both at once.
  ///
  /// In en, this message translates to:
  /// **'Target of 0 units'**
  String get salesZeroTarget;

  /// Title of the agent trail screen.
  ///
  /// In en, this message translates to:
  /// **'Agent trail'**
  String get trailTitle;

  /// Screen-reader label for the refresh control on the agent trail.
  ///
  /// In en, this message translates to:
  /// **'Refresh this day'**
  String get trailRefresh;

  /// Action that opens the date picker on the agent trail.
  ///
  /// In en, this message translates to:
  /// **'Pick another day'**
  String get trailPickDay;

  /// What is loading on the agent trail, read as 'Loading this day'.
  ///
  /// In en, this message translates to:
  /// **'this day'**
  String get trailSkeleton;

  /// Retry action on the agent trail's error state.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get trailRetry;

  /// Headline when no agent checked in on the chosen day.
  ///
  /// In en, this message translates to:
  /// **'No check-ins on this day.'**
  String get trailEmptyHeadline;

  /// Body of the agent trail's empty state.
  ///
  /// In en, this message translates to:
  /// **'A pin appears here when an agent confirms a check-in. Pick another day to see one that has some.'**
  String get trailEmptyBody;

  /// How many agents have stops on the chosen day, in the header facts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 agent} other{{count} agents}}'**
  String trailAgentCount(int count);

  /// How many stops the chosen day holds, in the header facts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 stop} other{{count} stops}}'**
  String trailStopCount(int count);

  /// Section rule above the trail map's legend.
  ///
  /// In en, this message translates to:
  /// **'How to read it'**
  String get trailHowToRead;

  /// The trail map's legend line about the numbered check-in pins.
  ///
  /// In en, this message translates to:
  /// **'Numbered pins are confirmed check-ins, in order, and the last one of each agent is filled. Dashed lines connect them — they are not a recorded route.'**
  String get trailLegendPins;

  /// The trail map's legend line about live positions.
  ///
  /// In en, this message translates to:
  /// **'Squares are live positions from the agent app, labelled with their age first. Last updated {when}.'**
  String trailLegendLive(String when);

  /// Pagination footer when the day holds more agents than the map draws.
  ///
  /// In en, this message translates to:
  /// **'Showing the first 200 agents only.'**
  String get trailFooterSummary;

  /// Why the trail map says it is truncated.
  ///
  /// In en, this message translates to:
  /// **'A partial map that looks complete is worse than no map: the rest of the day is not here.'**
  String get trailFooterNarrow;

  /// Word on a trail stop whose visit has not been submitted yet.
  ///
  /// In en, this message translates to:
  /// **'Still in this shop'**
  String get trailStillInShop;

  /// Word on the agent's final stop of the day.
  ///
  /// In en, this message translates to:
  /// **'Last stop'**
  String get trailLastStop;

  /// Spoken part of a trail stop's label, giving the check-in time.
  ///
  /// In en, this message translates to:
  /// **'checked in at {time}'**
  String trailCheckedInAt(String time);

  /// Headline of the Veld note that stands in for the trail map.
  ///
  /// In en, this message translates to:
  /// **'No map in the sun.'**
  String get trailNoMapHeadline;

  /// Body of the Veld note that stands in for the trail map.
  ///
  /// In en, this message translates to:
  /// **'A dark basemap read outdoors is a black rectangle. Every stop is listed below, in order, with the time it was confirmed.'**
  String get trailNoMapBody;

  /// Headline when the trail map's tiles never arrive.
  ///
  /// In en, this message translates to:
  /// **'The map will not load.'**
  String get trailMapOfflineHeadline;

  /// Body shown when the trail map's tiles never arrive.
  ///
  /// In en, this message translates to:
  /// **'The tiles are not arriving. Every stop is listed below, in order: nothing about the day is missing, only the picture of it.'**
  String get trailMapOfflineBody;

  /// How old a live position is when it was derived from a ping near an outlet.
  ///
  /// In en, this message translates to:
  /// **'last near {when}'**
  String liveLastNear(String when);

  /// How old a live position is when it came from a check-in.
  ///
  /// In en, this message translates to:
  /// **'last check-in {when}'**
  String liveLastCheckIn(String when);

  /// Where a live position is, by the nearest outlet's name.
  ///
  /// In en, this message translates to:
  /// **'Near {place}'**
  String liveNear(String place);

  /// Said of an agent whose app has never sent a position.
  ///
  /// In en, this message translates to:
  /// **'never shared'**
  String get liveNeverShared;

  /// Screen-reader label for one agent's live position marker.
  ///
  /// In en, this message translates to:
  /// **'Live location: {description}'**
  String liveLocationOf(String description);

  /// Said when the live location layer failed to load.
  ///
  /// In en, this message translates to:
  /// **'Live location could not load. Trying again shortly.'**
  String get liveLocationFailed;

  /// Said while the live location layer is still loading.
  ///
  /// In en, this message translates to:
  /// **'Live location: loading…'**
  String get liveLocationLoading;

  /// Heading of the live location panel.
  ///
  /// In en, this message translates to:
  /// **'Live location'**
  String get liveLocationHeading;

  /// When the live location layer last heard from the server.
  ///
  /// In en, this message translates to:
  /// **'Last updated {when}'**
  String liveLastUpdated(String when);

  /// What the live location panel is and is not.
  ///
  /// In en, this message translates to:
  /// **'Sent by the agent app only while it is open. Each row starts with how old that position was at the last update.'**
  String get liveLocationNote;

  /// Said when a live location refresh failed but an older one still stands.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh. Showing the last update.'**
  String get liveCouldNotRefresh;

  /// Said when the live location layer holds more agents than it draws.
  ///
  /// In en, this message translates to:
  /// **'Showing the first 200 agents.'**
  String get liveFirst200;

  /// Title of the fraud review queue.
  ///
  /// In en, this message translates to:
  /// **'Fraud review'**
  String get fraudTitle;

  /// Header fact explaining how a risk score is arrived at.
  ///
  /// In en, this message translates to:
  /// **'Risk is scored 0–100 on submit. The signals are the evidence.'**
  String get fraudFact;

  /// Screen-reader label for the fraud queue's refresh control.
  ///
  /// In en, this message translates to:
  /// **'Refresh the review queue'**
  String get fraudRefresh;

  /// What is loading on the fraud queue, read as 'Loading flagged visits'.
  ///
  /// In en, this message translates to:
  /// **'flagged visits'**
  String get fraudSkeleton;

  /// Retry action on the fraud queue's error state.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get fraudRetry;

  /// Screen-reader label for the fraud queue's filter rail.
  ///
  /// In en, this message translates to:
  /// **'Which flagged visits'**
  String get fraudFilterRail;

  /// Filter chip for flagged visits nobody has ruled on.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get fraudFilterOpen;

  /// Filter chip for flagged visits that carry a ruling.
  ///
  /// In en, this message translates to:
  /// **'Decided'**
  String get fraudFilterDecided;

  /// Filter chip for every flagged visit.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get fraudFilterAll;

  /// Section rule over the open fraud queue.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get fraudSectionOpen;

  /// Section rule over the ruled-on fraud queue.
  ///
  /// In en, this message translates to:
  /// **'Decided'**
  String get fraudSectionDecided;

  /// Section rule over the whole fraud queue.
  ///
  /// In en, this message translates to:
  /// **'Every flagged visit'**
  String get fraudSectionAll;

  /// Section rule's empty line for the open fraud queue.
  ///
  /// In en, this message translates to:
  /// **'Nothing waiting on a ruling.'**
  String get fraudEmptyLineOpen;

  /// Section rule's empty line for the decided fraud queue.
  ///
  /// In en, this message translates to:
  /// **'Nothing ruled on yet.'**
  String get fraudEmptyLineDecided;

  /// Section rule's empty line for the whole fraud queue.
  ///
  /// In en, this message translates to:
  /// **'Nothing flagged.'**
  String get fraudEmptyLineAll;

  /// Empty-state headline for the open fraud queue.
  ///
  /// In en, this message translates to:
  /// **'Nothing waiting on you.'**
  String get fraudEmptyHeadlineOpen;

  /// Empty-state headline for the decided fraud queue.
  ///
  /// In en, this message translates to:
  /// **'No rulings recorded yet.'**
  String get fraudEmptyHeadlineDecided;

  /// Empty-state headline for the whole fraud queue.
  ///
  /// In en, this message translates to:
  /// **'Nothing flagged.'**
  String get fraudEmptyHeadlineAll;

  /// Empty-state body for the open fraud queue.
  ///
  /// In en, this message translates to:
  /// **'A visit appears here when the fraud engine scores one above the review threshold. Ruled visits move to Decided.'**
  String get fraudEmptyBodyOpen;

  /// Empty-state body for the decided fraud queue.
  ///
  /// In en, this message translates to:
  /// **'A visit appears here once somebody records a ruling on it.'**
  String get fraudEmptyBodyDecided;

  /// Empty-state body for the whole fraud queue.
  ///
  /// In en, this message translates to:
  /// **'Visits appear here when the fraud engine scores one above the review threshold.'**
  String get fraudEmptyBodyAll;

  /// Pagination footer when the fraud queue holds more than it lists.
  ///
  /// In en, this message translates to:
  /// **'Showing the {count} riskiest.'**
  String fraudFooterShowing(String count);

  /// Says how many submitted visits carry no risk score yet, so a short queue never reads as an all-clear.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 submitted visit has not been scored yet and is not listed here.} other{{count} submitted visits have not been scored yet and are not listed here.}}'**
  String fraudUnscoredNote(int count);

  /// What a flagged row says where the roster does not carry the agent.
  ///
  /// In en, this message translates to:
  /// **'Unknown agent'**
  String get fraudUnknownAgent;

  /// What a flagged row says where the outlet list does not carry the shop.
  ///
  /// In en, this message translates to:
  /// **'Outlet name unavailable'**
  String get fraudUnnamedOutlet;

  /// Label on the raw visit id, shown only where the agent has no name.
  ///
  /// In en, this message translates to:
  /// **'Visit'**
  String get fraudVisitIdentifier;

  /// The risk figure in a flagged row's trailing lane.
  ///
  /// In en, this message translates to:
  /// **'Risk {score}'**
  String fraudRisk(String score);

  /// The spoken form of a flagged row's risk figure.
  ///
  /// In en, this message translates to:
  /// **'Risk {score} of 100'**
  String fraudRiskOf100(String score);

  /// Where a flagged visit stands when nobody has ruled on it.
  ///
  /// In en, this message translates to:
  /// **'Not yet reviewed'**
  String get fraudNotYetReviewed;

  /// The ruling that lets a flagged visit stand.
  ///
  /// In en, this message translates to:
  /// **'Cleared'**
  String get fraudVerdictCleared;

  /// The ruling that records a visit as faked.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get fraudVerdictConfirmed;

  /// The ruling that says nobody can tell yet.
  ///
  /// In en, this message translates to:
  /// **'Needs evidence'**
  String get fraudVerdictNeedsEvidence;

  /// The word for a risk score of 70 or more.
  ///
  /// In en, this message translates to:
  /// **'High risk'**
  String get fraudBandHigh;

  /// The word for a risk score from 50 to 69.
  ///
  /// In en, this message translates to:
  /// **'Elevated'**
  String get fraudBandElevated;

  /// The word for a risk score under 50.
  ///
  /// In en, this message translates to:
  /// **'Low risk'**
  String get fraudBandLow;

  /// Action that opens the ruling sheet on an unruled visit.
  ///
  /// In en, this message translates to:
  /// **'Rule on this visit'**
  String get fraudRuleOnThisVisit;

  /// Action that opens the ruling sheet on a visit that already carries one.
  ///
  /// In en, this message translates to:
  /// **'See the ruling'**
  String get fraudSeeTheRuling;

  /// Action that opens the flagged visit's own record.
  ///
  /// In en, this message translates to:
  /// **'See the visit'**
  String get fraudSeeTheVisit;

  /// Stands in for the reviewer's name where the record does not carry one.
  ///
  /// In en, this message translates to:
  /// **'A reviewer'**
  String get fraudReviewerFallback;

  /// Who ruled on a flagged visit, and what they ruled.
  ///
  /// In en, this message translates to:
  /// **'{who} ruled it {verdict}.'**
  String fraudRuledIt(String who, String verdict);

  /// The cleared ruling inside the sentence naming who ruled it.
  ///
  /// In en, this message translates to:
  /// **'cleared'**
  String get fraudVerdictClearedPast;

  /// The confirmed ruling inside the sentence naming who ruled it.
  ///
  /// In en, this message translates to:
  /// **'confirmed'**
  String get fraudVerdictConfirmedPast;

  /// The needs-evidence ruling inside the sentence naming who ruled it.
  ///
  /// In en, this message translates to:
  /// **'as needing evidence'**
  String get fraudVerdictNeedsEvidencePast;

  /// Said where a ruling was made against no risk score at all.
  ///
  /// In en, this message translates to:
  /// **'The visit was unscored at the time.'**
  String get fraudSeenUnscored;

  /// The score the reviewer was looking at when they ruled.
  ///
  /// In en, this message translates to:
  /// **'They were looking at risk {score}.'**
  String fraudSeenAtRisk(String score);

  /// Subtitle of the ruling sheet: where, how hard, and the band's word.
  ///
  /// In en, this message translates to:
  /// **'{outlet} · risk {score} of 100 · {band}'**
  String fraudSheetSubtitle(String outlet, String score, String band);

  /// Section rule over the signals that fired on a flagged visit.
  ///
  /// In en, this message translates to:
  /// **'What the engine found'**
  String get fraudWhatEngineFound;

  /// Headline where a flagged visit carries no stored signals.
  ///
  /// In en, this message translates to:
  /// **'No signals recorded.'**
  String get fraudNoSignalsHeadline;

  /// Body where a flagged visit carries no stored signals.
  ///
  /// In en, this message translates to:
  /// **'The visit scored above the threshold but the rules that fired were not stored with it. Open the visit to judge it on its own record.'**
  String get fraudNoSignalsBody;

  /// Label of the verdict control on the ruling sheet.
  ///
  /// In en, this message translates to:
  /// **'Your ruling'**
  String get fraudYourRuling;

  /// The commit that records a ruling on a flagged visit.
  ///
  /// In en, this message translates to:
  /// **'Record this ruling'**
  String get fraudRecordThisRuling;

  /// Label of the note field on the ruling sheet.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get fraudNoteLabel;

  /// Hint in the ruling sheet's note field.
  ///
  /// In en, this message translates to:
  /// **'What you checked, and what you found'**
  String get fraudNoteHint;

  /// Help line under the ruling sheet's note field.
  ///
  /// In en, this message translates to:
  /// **'Whoever reads this decision next sees only what you write here.'**
  String get fraudNoteHelp;

  /// What the verdict control says before a ruling is chosen.
  ///
  /// In en, this message translates to:
  /// **'No ruling chosen yet'**
  String get fraudNotChosenLine;

  /// Why the ruling sheet's commit is not armed yet.
  ///
  /// In en, this message translates to:
  /// **'Choose a ruling first.'**
  String get fraudChooseFirst;

  /// What ruling a visit cleared does.
  ///
  /// In en, this message translates to:
  /// **'The visit stands and leaves the queue. The agent keeps its points.'**
  String get fraudConsequenceCleared;

  /// What ruling a visit confirmed does.
  ///
  /// In en, this message translates to:
  /// **'The work is recorded as faked. This is the one ruling that accuses a person.'**
  String get fraudConsequenceConfirmed;

  /// What ruling a visit as needing evidence does.
  ///
  /// In en, this message translates to:
  /// **'Nobody can tell yet. It leaves the open queue and the note is what somebody works from.'**
  String get fraudConsequenceNeedsEvidence;

  /// Why the needs-evidence ruling demands a note.
  ///
  /// In en, this message translates to:
  /// **'Say what evidence is missing, so somebody can go and get it. \"Needs evidence\" with no note is a visit that was processed rather than reviewed.'**
  String get fraudNeedsEvidenceNoteBecause;

  /// Dismisses the ruling sheet without ruling.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get fraudNotNow;

  /// Dismisses the ruling sheet once a ruling stands.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get fraudClose;

  /// Section rule over a flagged visit's standing ruling.
  ///
  /// In en, this message translates to:
  /// **'The ruling that stands'**
  String get fraudRulingStands;

  /// Said on the ruling sheet where a ruling was made against no score.
  ///
  /// In en, this message translates to:
  /// **'The visit was unscored at the time, so there is no number behind this decision.'**
  String get fraudStandingUnscored;

  /// The score a standing ruling was made against.
  ///
  /// In en, this message translates to:
  /// **'They were looking at risk {score} of 100. A rescore since then does not move the ruling.'**
  String fraudStandingAtRisk(String score);

  /// Why a standing ruling cannot be changed on this sheet.
  ///
  /// In en, this message translates to:
  /// **'A visit is ruled once. Reopening it is a change to the record and is not done from here.'**
  String get fraudRuledOnce;

  /// Title of the leaderboard screen.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get leaderboardTitle;

  /// Header fact saying what a point is on the leaderboard.
  ///
  /// In en, this message translates to:
  /// **'Points: the average scorecard, plus 5 a closed task and 2 a submitted visit.'**
  String get leaderboardFact;

  /// Screen-reader label for the leaderboard's refresh control.
  ///
  /// In en, this message translates to:
  /// **'Refresh the leaderboard'**
  String get leaderboardRefresh;

  /// Action that opens the contests route from the leaderboard.
  ///
  /// In en, this message translates to:
  /// **'Contests'**
  String get leaderboardContests;

  /// What is loading, read as 'Loading the leaderboard'.
  ///
  /// In en, this message translates to:
  /// **'the leaderboard'**
  String get leaderboardSkeleton;

  /// Retry action on the leaderboard's error state.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get leaderboardRetry;

  /// Headline when the leaderboard holds no agents.
  ///
  /// In en, this message translates to:
  /// **'Nobody on the board yet.'**
  String get leaderboardEmptyHeadline;

  /// Body of the leaderboard's empty state.
  ///
  /// In en, this message translates to:
  /// **'Agents appear here once there is a field agent on this client to measure.'**
  String get leaderboardEmptyBody;

  /// Section rule over the agents who have a place this window.
  ///
  /// In en, this message translates to:
  /// **'Ranked'**
  String get leaderboardRanked;

  /// Section rule's empty line where nobody is ranked.
  ///
  /// In en, this message translates to:
  /// **'Nobody has a place in this window yet.'**
  String get leaderboardRankedEmptyLine;

  /// Section rule and trailing word for agents nobody has measured.
  ///
  /// In en, this message translates to:
  /// **'Not ranked yet'**
  String get leaderboardNotRanked;

  /// Why an agent is in the unranked section, so it does not read as a bottom.
  ///
  /// In en, this message translates to:
  /// **'Nothing measured for these agents in this window — no submitted visit, no closed task, no scorecard. They are not last; nobody has measured them.'**
  String get leaderboardUnrankedNote;

  /// An agent's place on the leaderboard.
  ///
  /// In en, this message translates to:
  /// **'Rank {rank}'**
  String leaderboardRank(String rank);

  /// The spoken form of a ranked agent's rank and payout.
  ///
  /// In en, this message translates to:
  /// **'Rank {rank}, {points} points'**
  String leaderboardRowTrailing(String rank, String points);

  /// Screen-reader label for the points history's refresh control.
  ///
  /// In en, this message translates to:
  /// **'Refresh this points history'**
  String get pointsRefresh;

  /// Action that returns from one agent's ledger to the board.
  ///
  /// In en, this message translates to:
  /// **'Back to the leaderboard'**
  String get pointsBackToLeaderboard;

  /// Title of the points history before the agent's name has arrived.
  ///
  /// In en, this message translates to:
  /// **'Points history'**
  String get pointsTitle;

  /// What is loading, read as 'Loading this points history'.
  ///
  /// In en, this message translates to:
  /// **'this points history'**
  String get pointsSkeleton;

  /// Retry action on the points history's error state.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get pointsRetry;

  /// Section rule over one agent's points entries.
  ///
  /// In en, this message translates to:
  /// **'Ledger'**
  String get pointsLedgerHeading;

  /// Section rule's empty line on an agent with no ledger entries.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded yet.'**
  String get pointsNothingRecorded;

  /// Headline when an agent's ledger is empty.
  ///
  /// In en, this message translates to:
  /// **'No points yet.'**
  String get pointsEmptyHeadline;

  /// Body of the points history's empty state.
  ///
  /// In en, this message translates to:
  /// **'Entries appear as this agent submits visits, closes tasks and is scored.'**
  String get pointsEmptyBody;

  /// Screen-reader label for the payout-and-average pair.
  ///
  /// In en, this message translates to:
  /// **'Two figures for {name}.'**
  String pointsTwoFigures(String name);

  /// Eyebrow over the payout figure.
  ///
  /// In en, this message translates to:
  /// **'Points earned'**
  String get pointsEarnedEyebrow;

  /// The unit worded beside a points figure.
  ///
  /// In en, this message translates to:
  /// **'pts'**
  String get pointsUnitWord;

  /// What the payout figure is made of.
  ///
  /// In en, this message translates to:
  /// **'The average scorecard, plus 5 a closed task and 2 a submitted visit.'**
  String get pointsStateLine;

  /// Why an unranked agent's payout is an absence rather than a nought.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded for this agent in this window.'**
  String get pointsPayoutAbsent;

  /// Eyebrow over the average scorecard figure.
  ///
  /// In en, this message translates to:
  /// **'Average scorecard'**
  String get pointsAverageEyebrow;

  /// Why an agent's average scorecard is an absence rather than a nought.
  ///
  /// In en, this message translates to:
  /// **'No scored visit in this window.'**
  String get pointsNoScoredVisit;

  /// The two counts the payout is built from.
  ///
  /// In en, this message translates to:
  /// **'{visits} visits submitted · {tasks} tasks closed'**
  String pointsCounts(String visits, String tasks);

  /// Pagination footer on an agent's ledger.
  ///
  /// In en, this message translates to:
  /// **'Showing the {count} newest entries. There are more.'**
  String pointsFooterSummary(String count);

  /// The spoken form of a scorecard ledger entry's figure.
  ///
  /// In en, this message translates to:
  /// **'scored {score}'**
  String pointsScored(String score);

  /// The spoken form of a ledger entry's signed payout.
  ///
  /// In en, this message translates to:
  /// **'{points} points'**
  String pointsSpokenPoints(String points);

  /// Title of the incentives screen.
  ///
  /// In en, this message translates to:
  /// **'Incentives'**
  String get incentivesTitle;

  /// Header fact saying what an incentive scheme does.
  ///
  /// In en, this message translates to:
  /// **'A scheme awards points when an agent reaches its threshold on the chosen metric. Paused schemes stop awarding.'**
  String get incentivesFact;

  /// Screen-reader label for the incentives refresh control.
  ///
  /// In en, this message translates to:
  /// **'Refresh the incentive schemes'**
  String get incentivesRefresh;

  /// What is loading, read as 'Loading incentive schemes'.
  ///
  /// In en, this message translates to:
  /// **'incentive schemes'**
  String get incentivesSkeleton;

  /// Retry action on the incentives error state.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get incentivesRetry;

  /// How many of the configured schemes are currently awarding.
  ///
  /// In en, this message translates to:
  /// **'{awarding} of {total} awarding'**
  String incentivesAwardingFact(String awarding, String total);

  /// Section rule over the configured incentive schemes.
  ///
  /// In en, this message translates to:
  /// **'Schemes'**
  String get incentivesSchemes;

  /// Section rule's empty line where no scheme exists.
  ///
  /// In en, this message translates to:
  /// **'None configured.'**
  String get incentivesNoneConfigured;

  /// Action that opens the scheme form.
  ///
  /// In en, this message translates to:
  /// **'Add a scheme'**
  String get incentivesAddScheme;

  /// Headline where no incentive scheme exists.
  ///
  /// In en, this message translates to:
  /// **'No schemes configured.'**
  String get incentivesEmptyHeadline;

  /// Body of the incentives empty state.
  ///
  /// In en, this message translates to:
  /// **'Add one to start rewarding agents who clear a threshold. Nothing pays out until there is a scheme.'**
  String get incentivesEmptyBody;

  /// The word for a scheme that is currently paying out.
  ///
  /// In en, this message translates to:
  /// **'Awarding'**
  String get incentivesAwarding;

  /// The word for a scheme that has stopped paying out.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get incentivesPaused;

  /// A scheme's rule line where the metric has a unit word.
  ///
  /// In en, this message translates to:
  /// **'{state} · {metric} · {threshold} {unit} · {reward}'**
  String incentivesRuleWithUnit(
    String state,
    String metric,
    String threshold,
    String unit,
    String reward,
  );

  /// A scheme's rule line where the metric key is unknown to this client, so there is no unit word to count the threshold in. The threshold is worded rather than written with a maths sign: the sign is not in the PDF font subset, and a reader announces it inconsistently or not at all.
  ///
  /// In en, this message translates to:
  /// **'{state} · {metric} · at least {threshold} · {reward}'**
  String incentivesRuleNoUnit(
    String state,
    String metric,
    String threshold,
    String reward,
  );

  /// Screen-reader label for the control that pauses a scheme.
  ///
  /// In en, this message translates to:
  /// **'Pause {name}'**
  String incentivesPauseScheme(String name);

  /// Screen-reader label for the control that starts a scheme awarding.
  ///
  /// In en, this message translates to:
  /// **'Start {name} awarding'**
  String incentivesStartScheme(String name);

  /// Action that opens every agent's progress toward one reward.
  ///
  /// In en, this message translates to:
  /// **'See everyone'**
  String get incentivesSeeEveryone;

  /// Action that deletes an incentive scheme.
  ///
  /// In en, this message translates to:
  /// **'Delete this scheme'**
  String get incentivesDeleteScheme;

  /// Toast when starting a scheme failed.
  ///
  /// In en, this message translates to:
  /// **'Could not start {name} awarding.'**
  String incentivesCouldNotStart(String name);

  /// Toast when pausing a scheme failed.
  ///
  /// In en, this message translates to:
  /// **'Could not pause {name}.'**
  String incentivesCouldNotPause(String name);

  /// The question the delete confirmation asks.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String incentivesDeleteAction(String name);

  /// First consequence of deleting a scheme.
  ///
  /// In en, this message translates to:
  /// **'It stops awarding immediately.'**
  String get incentivesDeleteStops;

  /// Second consequence of deleting a scheme.
  ///
  /// In en, this message translates to:
  /// **'Points already awarded stay on the agents who earned them.'**
  String get incentivesDeleteKeeps;

  /// Third consequence of deleting a scheme: who has already earned it.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 agent has earned it so far.} other{{count} agents have earned it so far.}}'**
  String incentivesEarnedSoFar(int count);

  /// Toast when deleting a scheme failed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete {name}. It is still awarding.'**
  String incentivesCouldNotDelete(String name);

  /// Said where a scheme pays on a metric key this build does not know.
  ///
  /// In en, this message translates to:
  /// **'This client does not recognise the metric \"{metric}\", so progress toward it cannot be shown here.'**
  String incentivesUnknownMetric(String metric);

  /// Said where the leaderboard the progress bars read from did not answer.
  ///
  /// In en, this message translates to:
  /// **'No agent figures loaded, so progress toward this reward is not shown.'**
  String get incentivesNoBoard;

  /// Said where the board answered but the scheme's own metric can measure nobody on it.
  ///
  /// In en, this message translates to:
  /// **'Nobody has been measured on {metric} in this window, so there is no progress toward this reward to show yet.'**
  String incentivesNobodyMeasured(String metric);

  /// Said where every measurable agent has already reached the threshold.
  ///
  /// In en, this message translates to:
  /// **'Everybody this metric can measure has earned it.'**
  String get incentivesEverybodyEarned;

  /// Label on the progress bar naming the agent nearest the reward.
  ///
  /// In en, this message translates to:
  /// **'Closest: {name}'**
  String incentivesClosest(String name);

  /// How far along a progress bar is, in the metric's own unit.
  ///
  /// In en, this message translates to:
  /// **'{value} of {threshold} {unit}'**
  String incentivesFractionUnit(String value, String threshold, String unit);

  /// How far along a progress bar is where the metric has no unit word.
  ///
  /// In en, this message translates to:
  /// **'{value} of {threshold}'**
  String incentivesFraction(String value, String threshold);

  /// The milestone label naming what reaching the threshold awards.
  ///
  /// In en, this message translates to:
  /// **'{reward} at {threshold} {unit}'**
  String incentivesRewardAt(String reward, String threshold, String unit);

  /// A scheme's reward, in points.
  ///
  /// In en, this message translates to:
  /// **'{points} pts'**
  String incentivesRewardPoints(String points);

  /// How many of the agents this metric can measure have reached the threshold. The denominator is who the metric measures, never the board.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{earned} of 1 agent has earned it.} other{{earned} of {count} agents have earned it.}}'**
  String incentivesEarnedOf(int count, String earned);

  /// The metric that pays on an agent's 0-100 scorecard mean.
  ///
  /// In en, this message translates to:
  /// **'Average scorecard'**
  String get incentiveMetricScorecard;

  /// The metric that pays on a count of closed tasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks closed'**
  String get incentiveMetricTasksClosed;

  /// The metric that pays on a count of submitted visits.
  ///
  /// In en, this message translates to:
  /// **'Visits submitted'**
  String get incentiveMetricVisits;

  /// The unit the average-scorecard threshold is counted in.
  ///
  /// In en, this message translates to:
  /// **'points'**
  String get incentiveUnitPoints;

  /// The unit the tasks-closed threshold is counted in.
  ///
  /// In en, this message translates to:
  /// **'tasks'**
  String get incentiveUnitTasks;

  /// The unit the visits-submitted threshold is counted in.
  ///
  /// In en, this message translates to:
  /// **'visits'**
  String get incentiveUnitVisits;

  /// Title of the sheet that creates an incentive scheme.
  ///
  /// In en, this message translates to:
  /// **'Add a scheme'**
  String get schemeFormTitle;

  /// Subtitle of the scheme form, saying when it takes effect.
  ///
  /// In en, this message translates to:
  /// **'It starts awarding as soon as it is saved.'**
  String get schemeFormSubtitle;

  /// Label of the scheme's name field.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get schemeFormName;

  /// Hint in the scheme's name field.
  ///
  /// In en, this message translates to:
  /// **'What a manager will call it — \"Twenty visits\"'**
  String get schemeFormNameHint;

  /// Refusal where the scheme has no name.
  ///
  /// In en, this message translates to:
  /// **'Give the scheme a name.'**
  String get schemeFormNameError;

  /// Label of the metric choice on the scheme form.
  ///
  /// In en, this message translates to:
  /// **'What it pays on'**
  String get schemeFormMetricLabel;

  /// What the metric choice says before one is chosen.
  ///
  /// In en, this message translates to:
  /// **'No metric chosen yet'**
  String get schemeFormMetricNotAnswered;

  /// Refusal where no metric is chosen.
  ///
  /// In en, this message translates to:
  /// **'Choose what the scheme pays on.'**
  String get schemeFormMetricError;

  /// What choosing the average-scorecard metric means.
  ///
  /// In en, this message translates to:
  /// **'Pays when the agent\'s 0–100 mean clears the threshold.'**
  String get schemeFormScorecardConsequence;

  /// What choosing the tasks-closed metric means.
  ///
  /// In en, this message translates to:
  /// **'Pays on a count of closures.'**
  String get schemeFormTasksConsequence;

  /// What choosing the visits-submitted metric means.
  ///
  /// In en, this message translates to:
  /// **'Pays on a count of submitted visits.'**
  String get schemeFormVisitsConsequence;

  /// Label of the scheme's threshold field.
  ///
  /// In en, this message translates to:
  /// **'Threshold'**
  String get schemeFormThreshold;

  /// Help under the threshold field before a metric is chosen.
  ///
  /// In en, this message translates to:
  /// **'What an agent has to reach.'**
  String get schemeFormThresholdHelp;

  /// Help under the threshold field once a metric is chosen.
  ///
  /// In en, this message translates to:
  /// **'What an agent has to reach, in {unit}.'**
  String schemeFormThresholdHelpUnit(String unit);

  /// Refusal where the threshold is not a number.
  ///
  /// In en, this message translates to:
  /// **'Say the figure an agent has to reach.'**
  String get schemeFormThresholdError;

  /// Refusal where the threshold is zero or less.
  ///
  /// In en, this message translates to:
  /// **'A threshold of nought is a scheme that pays out to everybody the moment it is created.'**
  String get schemeFormThresholdZero;

  /// Label of the scheme's reward field.
  ///
  /// In en, this message translates to:
  /// **'Reward'**
  String get schemeFormReward;

  /// Help under the reward field.
  ///
  /// In en, this message translates to:
  /// **'What clearing it awards.'**
  String get schemeFormRewardHelp;

  /// Refusal where the reward is not a number.
  ///
  /// In en, this message translates to:
  /// **'Say how many points it awards.'**
  String get schemeFormRewardError;

  /// Refusal where the reward is zero or less.
  ///
  /// In en, this message translates to:
  /// **'A reward of nought is not a reward.'**
  String get schemeFormRewardZero;

  /// The commit that creates the scheme.
  ///
  /// In en, this message translates to:
  /// **'Save this scheme'**
  String get schemeFormSave;

  /// Why the scheme form's commit is not armed yet.
  ///
  /// In en, this message translates to:
  /// **'A scheme needs a name, a metric, a threshold and a reward.'**
  String get schemeFormBlocked;

  /// Dismisses the scheme form without creating anything.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get schemeFormNotNow;

  /// Section rule over every agent's progress toward one reward.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get schemeProgressEveryone;

  /// Subtitle of the everyone-sheet: the metric and what it awards.
  ///
  /// In en, this message translates to:
  /// **'{metric} · {reward}'**
  String schemeProgressSubtitle(String metric, String reward);

  /// Headline where the board the sheet reads from did not answer.
  ///
  /// In en, this message translates to:
  /// **'No agent figures loaded.'**
  String get schemeProgressEmptyHeadline;

  /// Body where the board the sheet reads from did not answer.
  ///
  /// In en, this message translates to:
  /// **'Progress toward this reward is read from the board, and the board has not answered.'**
  String get schemeProgressEmptyBody;

  /// Said of an agent the scheme's metric cannot answer for.
  ///
  /// In en, this message translates to:
  /// **'Not measured on this metric yet.'**
  String get schemeProgressUnmeasured;

  /// The word on a progress bar that has reached its reward.
  ///
  /// In en, this message translates to:
  /// **'Earned'**
  String get schemeProgressEarned;

  /// Said in place of a fraction where the metric can measure nobody listed.
  ///
  /// In en, this message translates to:
  /// **'Nobody above has been measured on this metric in this window, so there is nothing to count yet.'**
  String get schemeProgressNobodyMeasured;

  /// Dismisses the everyone-sheet.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get schemeProgressClose;

  /// The live state of an agent whose ping is inside a store's fence.
  ///
  /// In en, this message translates to:
  /// **'At store'**
  String get liveStateAtStore;

  /// The live state of an agent whose ping is close to a store.
  ///
  /// In en, this message translates to:
  /// **'Near store'**
  String get liveStateNearStore;

  /// The live state of an agent who is on the road.
  ///
  /// In en, this message translates to:
  /// **'In transit'**
  String get liveStateInTransit;

  /// The live state of an agent whose last position is too old to trust.
  ///
  /// In en, this message translates to:
  /// **'Stale'**
  String get liveStateStale;

  /// The live state of an agent whose app has stopped reporting.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get liveStateOffline;

  /// The live state of an agent who has declined to share a position.
  ///
  /// In en, this message translates to:
  /// **'Not sharing'**
  String get liveStateNotSharing;

  /// How old a live position is, in seconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String liveAgeSeconds(String seconds);

  /// How old a live position is, in minutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String liveAgeMinutes(String minutes);

  /// How old a live position is, in whole hours.
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String liveAgeHours(String hours);

  /// How old a live position is, in hours and minutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String liveAgeHoursMinutes(String hours, String minutes);

  /// How old a live position is, in days.
  ///
  /// In en, this message translates to:
  /// **'{days} d'**
  String liveAgeDays(String days);

  /// Where an agent is, when the ping is inside that store's fence.
  ///
  /// In en, this message translates to:
  /// **'at {outlet}'**
  String liveAtOutlet(String outlet);

  /// Where an agent is, when the ping is close to that store.
  ///
  /// In en, this message translates to:
  /// **'near {outlet}'**
  String liveNearOutlet(String outlet);

  /// How old a live position is, inside the spoken description.
  ///
  /// In en, this message translates to:
  /// **'{age} old'**
  String liveAgeOld(String age);

  /// Screen-reader label for one numbered check-in pin on the trail map.
  ///
  /// In en, this message translates to:
  /// **'{agent}, stop {ordinal}, {outlet}, {time}'**
  String trailPinLabel(
    String agent,
    String ordinal,
    String outlet,
    String time,
  );

  /// The title of the manager's multi-panel console at /dashboard/overview.
  ///
  /// In en, this message translates to:
  /// **'Execution overview'**
  String get dashOverviewTitle;

  /// Screen-reader label for the header's refetch button. It refetches all panels together so none can disagree with another.
  ///
  /// In en, this message translates to:
  /// **'Refresh every panel'**
  String get dashRefresh;

  /// Label for the filter rail that scopes every panel on the execution overview.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get dashFilters;

  /// The unfiltered territory choice.
  ///
  /// In en, this message translates to:
  /// **'All territories'**
  String get dashAllTerritories;

  /// The territory chip's label while the territory list has not loaded, so it can still say that a filter is on without naming it.
  ///
  /// In en, this message translates to:
  /// **'One territory'**
  String get dashOneTerritory;

  /// Title of the sheet that chooses which territory the console is scoped to.
  ///
  /// In en, this message translates to:
  /// **'Territory'**
  String get dashTerritory;

  /// Subtitle of the territory sheet.
  ///
  /// In en, this message translates to:
  /// **'Every figure below is scoped to this choice.'**
  String get dashTerritorySheetBody;

  /// Announced first in a picker row's label, because a tick is silence to a screen reader.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get dashSelected;

  /// A window the console's figures are measured over.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get dashRangeLast7;

  /// A window the console's figures are measured over.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get dashRangeLast30;

  /// A window the console's figures are measured over.
  ///
  /// In en, this message translates to:
  /// **'Last 90 days'**
  String get dashRangeLast90;

  /// A window the console's figures are measured over.
  ///
  /// In en, this message translates to:
  /// **'Year to date'**
  String get dashRangeYtd;

  /// The unbounded window. It has no previous period, so it shows no deltas at all.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get dashRangeAll;

  /// The console's headline figure.
  ///
  /// In en, this message translates to:
  /// **'Execution score'**
  String get dashExecutionScore;

  /// The supporting line under the execution score.
  ///
  /// In en, this message translates to:
  /// **'Weighted S2–S8, all outlets · target {target}'**
  String dashExecutionScoreSupports(int target);

  /// Heading for the execution score's trend chart and its table twin.
  ///
  /// In en, this message translates to:
  /// **'Execution score over time'**
  String get dashScoreTrend;

  /// What a delta on this console is measured against — the like-for-like window, complete days on both sides.
  ///
  /// In en, this message translates to:
  /// **'vs the window before'**
  String get dashVsWindowBefore;

  /// Section heading over the open alert and task counts.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get dashNeedsAttention;

  /// The needs-attention section's ghost action, into the alerts worklist.
  ///
  /// In en, this message translates to:
  /// **'All alerts'**
  String get dashViewAllAlerts;

  /// Row title: open alerts at critical severity.
  ///
  /// In en, this message translates to:
  /// **'Critical alerts open'**
  String get dashCriticalAlerts;

  /// Row title: open alerts below critical severity.
  ///
  /// In en, this message translates to:
  /// **'Warnings awaiting acknowledgement'**
  String get dashWarningAlerts;

  /// Row title: tasks that are not closed.
  ///
  /// In en, this message translates to:
  /// **'Tasks still open'**
  String get dashTasksOpen;

  /// The detail line on a needs-attention row whose count is a measured zero. The row still renders its 0.
  ///
  /// In en, this message translates to:
  /// **'Nothing outstanding'**
  String get dashNothingOutstanding;

  /// The detail line when no open task is at critical priority.
  ///
  /// In en, this message translates to:
  /// **'None at critical priority'**
  String get dashNoneAtCritical;

  /// The detail line counting open tasks at critical priority.
  ///
  /// In en, this message translates to:
  /// **'{count} at critical priority'**
  String dashNAtCritical(int count);

  /// The word beside a critical severity bar. The bar is crimson; the word is the channel that survives greyscale and a screen reader.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get dashSeverityCritical;

  /// The word beside a watch severity bar.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get dashSeverityWatch;

  /// Section heading over the seven indicators and their published targets.
  ///
  /// In en, this message translates to:
  /// **'Where we sit against the standard'**
  String get dashAgainstStandard;

  /// Explains the meter's target tick above the indicator list.
  ///
  /// In en, this message translates to:
  /// **'The tick marks the target.'**
  String get dashTickMarksTarget;

  /// Indicator name.
  ///
  /// In en, this message translates to:
  /// **'On-shelf availability'**
  String get dashKpiOsa;

  /// The published standard for on-shelf availability.
  ///
  /// In en, this message translates to:
  /// **'Floor 95% · target 97–99%'**
  String get dashKpiOsaNote;

  /// Indicator name.
  ///
  /// In en, this message translates to:
  /// **'Perfect-store rate'**
  String get dashKpiPerfectStore;

  /// The published standard for the perfect-store rate.
  ///
  /// In en, this message translates to:
  /// **'Healthy 80–90% · below 70% is an execution gap'**
  String get dashKpiPerfectStoreNote;

  /// Indicator name.
  ///
  /// In en, this message translates to:
  /// **'Price compliance'**
  String get dashKpiPrice;

  /// The standard for price compliance.
  ///
  /// In en, this message translates to:
  /// **'Within tolerance of the recommended price'**
  String get dashKpiPriceNote;

  /// Indicator name.
  ///
  /// In en, this message translates to:
  /// **'Visibility compliance'**
  String get dashKpiVisibility;

  /// The standard for visibility compliance.
  ///
  /// In en, this message translates to:
  /// **'Planogram threshold'**
  String get dashKpiVisibilityNote;

  /// Indicator name.
  ///
  /// In en, this message translates to:
  /// **'Share of shelf'**
  String get dashKpiShareOfShelf;

  /// The standard for share of shelf.
  ///
  /// In en, this message translates to:
  /// **'Category fair share'**
  String get dashKpiShareOfShelfNote;

  /// Indicator name.
  ///
  /// In en, this message translates to:
  /// **'Weighted distribution'**
  String get dashKpiWeighted;

  /// The standard for weighted distribution.
  ///
  /// In en, this message translates to:
  /// **'Volume-weighted'**
  String get dashKpiWeightedNote;

  /// Indicator name.
  ///
  /// In en, this message translates to:
  /// **'Numeric distribution'**
  String get dashKpiNumeric;

  /// The standard for numeric distribution.
  ///
  /// In en, this message translates to:
  /// **'Outlets stocking'**
  String get dashKpiNumericNote;

  /// An indicator more than ten points under its target.
  ///
  /// In en, this message translates to:
  /// **'Below the standard'**
  String get dashStandingCritical;

  /// An indicator within ten points of its target but not on it.
  ///
  /// In en, this message translates to:
  /// **'Close to the standard'**
  String get dashStandingWatch;

  /// An indicator at or above its target.
  ///
  /// In en, this message translates to:
  /// **'On the standard'**
  String get dashStandingOnTarget;

  /// The standard a figure is read against, already formatted by the locale formatter.
  ///
  /// In en, this message translates to:
  /// **'Target {target}'**
  String dashTargetIs(String target);

  /// Section heading over the score-band counts.
  ///
  /// In en, this message translates to:
  /// **'Perfect-store distribution'**
  String get dashDistribution;

  /// Explains what the score-band counts are counting.
  ///
  /// In en, this message translates to:
  /// **'Outlets by their latest scored visit · healthy band 80–90.'**
  String get dashHealthyBand;

  /// Screen-reader label for one score band's row.
  ///
  /// In en, this message translates to:
  /// **'{count} outlets scoring {band}'**
  String dashBandOutlets(int count, String band);

  /// Section heading over the per-territory score list.
  ///
  /// In en, this message translates to:
  /// **'Execution score by territory'**
  String get dashByTerritory;

  /// Empty state when the tenant has no territories at all.
  ///
  /// In en, this message translates to:
  /// **'No territories defined'**
  String get dashNoTerritories;

  /// Body of the no-territories empty state.
  ///
  /// In en, this message translates to:
  /// **'Add a territory to compare scores across the field.'**
  String get dashNoTerritoriesBody;

  /// Empty state when territories exist but no summary overlaps them. A settled answer, never a loader.
  ///
  /// In en, this message translates to:
  /// **'No territory scores yet'**
  String get dashNoTerritoryScores;

  /// Body of the no-territory-scores empty state.
  ///
  /// In en, this message translates to:
  /// **'Scores appear once visits in this window have been scored.'**
  String get dashNoTerritoryScoresBody;

  /// Heading for the availability trend chart and its table twin.
  ///
  /// In en, this message translates to:
  /// **'On-shelf availability by period'**
  String get dashAvailabilityByPeriod;

  /// Section heading over the agent map and list.
  ///
  /// In en, this message translates to:
  /// **'Where are my agents'**
  String get dashWhereAgents;

  /// Explains what the agent map plots, so a pin is never read as a live position.
  ///
  /// In en, this message translates to:
  /// **'Today’s confirmed check-ins. A pin is where somebody checked in, not where they are now.'**
  String get dashTodaysCheckIns;

  /// The agent section's ghost action, into the full-screen activity map.
  ///
  /// In en, this message translates to:
  /// **'Open the map'**
  String get dashViewMap;

  /// Headline of the agent panel's empty state.
  ///
  /// In en, this message translates to:
  /// **'Nobody to show'**
  String get dashNoAgentsHeadline;

  /// Body of the agent empty state when no territory filter is on, so the filter cannot be the reason.
  ///
  /// In en, this message translates to:
  /// **'No field agents yet.'**
  String get dashNoAgentsYet;

  /// Body of the agent empty state when a territory is filtered but its name is not known.
  ///
  /// In en, this message translates to:
  /// **'No agents match this territory filter.'**
  String get dashNoAgentsForFilter;

  /// Body of the agent empty state, naming the filtered territory.
  ///
  /// In en, this message translates to:
  /// **'No agents are assigned to {name}.'**
  String dashNoAgentsIn(String name);

  /// Said in words when there is nothing at all to draw on the map, rather than drawing an empty one.
  ///
  /// In en, this message translates to:
  /// **'No outlets yet — add outlets to see them here.'**
  String get dashNoOutletsToPlot;

  /// Says who is plotted and who is not, so the map never reads as the whole team.
  ///
  /// In en, this message translates to:
  /// **'{plotted} on the map · {notPlotted} not checked in today'**
  String dashOnTheMap(int plotted, int notPlotted);

  /// Said when the agent page is truncated, so a cut list never reads as the whole team.
  ///
  /// In en, this message translates to:
  /// **'Showing the first 200 agents. Filter by territory to narrow.'**
  String get dashFirst200Agents;

  /// The check-in state of an agent who has not checked in today.
  ///
  /// In en, this message translates to:
  /// **'No check-in'**
  String get dashNoCheckIn;

  /// The age column for an agent who has never been seen today.
  ///
  /// In en, this message translates to:
  /// **'no check-in today'**
  String get dashNoCheckInToday;

  /// Stands in where an agent is at a store whose name the page did not carry.
  ///
  /// In en, this message translates to:
  /// **'unknown store'**
  String get dashUnknownStore;

  /// Stands in where an agent is on the road and no previous store is known.
  ///
  /// In en, this message translates to:
  /// **'in transit'**
  String get dashInTransit;

  /// Where an agent in transit was last confirmed.
  ///
  /// In en, this message translates to:
  /// **'left {outlet}'**
  String dashLeft(String outlet);

  /// Screen-reader label for one outlet dot on the base layer of the agent map.
  ///
  /// In en, this message translates to:
  /// **'{outlet} outlet'**
  String dashOutletPin(String outlet);

  /// The sentence that goes with an em dash. An absence, never a nought.
  ///
  /// In en, this message translates to:
  /// **'No visits in this window'**
  String get dashNoVisitsInWindow;

  /// Whole-screen state for a tenant with no outlets at all. Not a scoreboard of noughts.
  ///
  /// In en, this message translates to:
  /// **'Nothing on the books yet'**
  String get dashFirstRunHeadline;

  /// Body of the first-run state.
  ///
  /// In en, this message translates to:
  /// **'Add outlets and territories, and this console fills in as visits are submitted and scored.'**
  String get dashFirstRunBody;

  /// A caveat under the console, so two derived figures are never read as measured ones.
  ///
  /// In en, this message translates to:
  /// **'Visibility compliance and share of shelf are derived from the Phase-1 computer-vision stub.'**
  String get dashStubCaveat;

  /// The name of the manager's supervisory view of one visit.
  ///
  /// In en, this message translates to:
  /// **'Visit review'**
  String get visitReviewTitle;

  /// Screen-reader label for the back control. Named for where it goes, never "Back".
  ///
  /// In en, this message translates to:
  /// **'Back to the list you came from'**
  String get visitBackToList;

  /// The back control on a deep link, which has nothing to pop to. Losing this escape strands a reviewer on a screen with no exit.
  ///
  /// In en, this message translates to:
  /// **'Back to The Floor'**
  String get visitBackToFloor;

  /// Header flag: the visit was never submitted, which is why half this screen is empty.
  ///
  /// In en, this message translates to:
  /// **'Unfinished'**
  String get visitInProgress;

  /// The check-in was further from the store than the geofence allows. A measurement, not a verdict.
  ///
  /// In en, this message translates to:
  /// **'Outside the fence'**
  String get visitOutsideFence;

  /// The check-in was within the geofence.
  ///
  /// In en, this message translates to:
  /// **'Inside the fence'**
  String get visitInsideFence;

  /// Header flag and fact value: the visit fell outside the fence because the store's own coordinates are disputed (#386).
  ///
  /// In en, this message translates to:
  /// **'The agent reported the pin is wrong'**
  String get visitPinReported;

  /// Section heading over who went where and when.
  ///
  /// In en, this message translates to:
  /// **'The visit'**
  String get visitTheVisit;

  /// Fact label: when the visit started.
  ///
  /// In en, this message translates to:
  /// **'Checked in'**
  String get visitCheckedIn;

  /// Qualifies the check-in time, so it is never read as a server timestamp.
  ///
  /// In en, this message translates to:
  /// **'From the phone\'s own clock'**
  String get visitDeviceClock;

  /// Fact label: when the visit was sent.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get visitSubmitted;

  /// The submitted time of a visit that has not been submitted.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get visitNotYet;

  /// How long the agent was at the store, between check-in and submit.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes on site'**
  String visitMinutesOnSite(int minutes);

  /// Fact label: how far the check-in was from the outlet's pin.
  ///
  /// In en, this message translates to:
  /// **'Distance from the store'**
  String get visitGeofence;

  /// Said in words where there is no measured distance. A nought would read as a perfect check-in.
  ///
  /// In en, this message translates to:
  /// **'No distance was recorded'**
  String get visitNoDistance;

  /// Fact label for a disputed outlet pin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get visitPin;

  /// A pin dispute that was accepted.
  ///
  /// In en, this message translates to:
  /// **'The pin was moved'**
  String get visitPinMoved;

  /// A pin dispute that was accepted, and by whom.
  ///
  /// In en, this message translates to:
  /// **'The pin was moved by {name}'**
  String visitPinMovedBy(String name);

  /// A pin dispute that was rejected.
  ///
  /// In en, this message translates to:
  /// **'The pin was kept'**
  String get visitPinKept;

  /// A pin dispute that was rejected, and by whom.
  ///
  /// In en, this message translates to:
  /// **'The pin was kept by {name}'**
  String visitPinKeptBy(String name);

  /// A pin dispute nobody has answered yet.
  ///
  /// In en, this message translates to:
  /// **'Waiting for review'**
  String get visitPinWaiting;

  /// Section heading over the score and its band.
  ///
  /// In en, this message translates to:
  /// **'Perfect store score'**
  String get visitScoreHeading;

  /// Headline where a visit has no scorecard.
  ///
  /// In en, this message translates to:
  /// **'Not scored'**
  String get visitNotScored;

  /// Why a draft has no score.
  ///
  /// In en, this message translates to:
  /// **'The score is calculated when the visit is submitted.'**
  String get visitScoredOnSubmit;

  /// Why a submitted visit has no score. A different fact from a draft, and the reviewer needs to know which.
  ///
  /// In en, this message translates to:
  /// **'No scorecard has been generated for this visit.'**
  String get visitNoScorecard;

  /// A rating band this build does not recognise. Never guessed at, and never given a severity.
  ///
  /// In en, this message translates to:
  /// **'Unbanded'**
  String get visitUnbanded;

  /// The score meter's spoken value.
  ///
  /// In en, this message translates to:
  /// **'{value} out of 100, target {target}'**
  String visitScoreMeterSemantics(int value, int target);

  /// Section heading over the six dimensions.
  ///
  /// In en, this message translates to:
  /// **'How it was scored'**
  String get visitHowScored;

  /// A dimension at or above the visit's target.
  ///
  /// In en, this message translates to:
  /// **'On target'**
  String get visitOnTarget;

  /// A dimension under the visit's target.
  ///
  /// In en, this message translates to:
  /// **'Below target'**
  String get visitBelowTarget;

  /// Which version of the template the agent answered.
  ///
  /// In en, this message translates to:
  /// **'Answered against v{version}'**
  String visitAnsweredVersion(int version);

  /// Said when the template has moved on since the visit, so a label that no longer matches the question is not read as the question.
  ///
  /// In en, this message translates to:
  /// **'Answered against v{version} · the template is now v{current}, and the labels below come from the current version'**
  String visitAnsweredOlderVersion(int version, int current);

  /// An answer whose question has since been removed. Kept rather than dropped: it is still something the agent recorded.
  ///
  /// In en, this message translates to:
  /// **'{field} (no longer in the template)'**
  String visitAnswerOrphan(String field);

  /// A template question that blocks a submit.
  ///
  /// In en, this message translates to:
  /// **'{label} (required)'**
  String visitRequiredQuestion(String label);

  /// The client template's own score.
  ///
  /// In en, this message translates to:
  /// **'Template score {score} of {max}'**
  String visitTemplateScore(String score, String max);

  /// Keeps two different scores from being read as one.
  ///
  /// In en, this message translates to:
  /// **'The template score is the client\'s own measure. It is not part of the perfect store score.'**
  String get visitTemplateScoreNote;

  /// Headline where a template carries no answers.
  ///
  /// In en, this message translates to:
  /// **'No answers were recorded'**
  String get visitNoAnswersHeadline;

  /// Body of the no-answers state.
  ///
  /// In en, this message translates to:
  /// **'The template was attached to this visit and nothing was filled in.'**
  String get visitNoAnswersBody;

  /// A template photo question. The app does not capture template photos.
  ///
  /// In en, this message translates to:
  /// **'Not captured in the app'**
  String get visitNotCaptured;

  /// A template question the agent left blank.
  ///
  /// In en, this message translates to:
  /// **'Not answered'**
  String get visitNotAnswered;

  /// A true answer to a template question.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get visitYes;

  /// A false answer to a template question.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get visitNo;

  /// Section heading over the five capture sections.
  ///
  /// In en, this message translates to:
  /// **'What was captured'**
  String get visitWhatWasCaptured;

  /// Said where a section holds nothing at all.
  ///
  /// In en, this message translates to:
  /// **'Nothing was captured'**
  String get visitNothingCaptured;

  /// Visibility is captured or it is not; there is no meaningful count of it.
  ///
  /// In en, this message translates to:
  /// **'Captured'**
  String get visitCaptured;

  /// How many rows a capture section holds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 captured} other{{count} captured}}'**
  String visitNCaptured(int count);

  /// A capture section with nothing flagged.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get visitClear;

  /// How many rows in a capture section were flagged.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 flagged} other{{count} flagged}}'**
  String visitNFlagged(int count);

  /// A capture section the agent never opened.
  ///
  /// In en, this message translates to:
  /// **'Not captured'**
  String get visitNotCapturedSection;

  /// A section that was captured and raised nothing.
  ///
  /// In en, this message translates to:
  /// **'No findings.'**
  String get visitNoFindings;

  /// A section the agent never opened.
  ///
  /// In en, this message translates to:
  /// **'Nothing was recorded in this section.'**
  String get visitNothingRecorded;

  /// Said when the server cut the rows it derived findings from, so a short list never reads as the whole section.
  ///
  /// In en, this message translates to:
  /// **'Findings drawn from the first 500 rows.'**
  String get visitFindingsTruncated;

  /// The word beside a critical severity bar. The bar is crimson; the word is the channel that survives greyscale and a screen reader.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get visitSeverityCritical;

  /// The word beside a watch severity bar.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get visitSeverityWatch;

  /// Section heading over the visit's photographs.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get visitPhotos;

  /// Said in words. On a fraud review this absence is itself a signal.
  ///
  /// In en, this message translates to:
  /// **'No photos were captured on this visit.'**
  String get visitNoPhotos;

  /// Said when the photo list is cut, so it never reads as everything that was captured.
  ///
  /// In en, this message translates to:
  /// **'Showing {shown} of {total}'**
  String visitShowingOf(int shown, int total);

  /// What a thumbnail is of, in words. A picture with no label is a picture a screen reader cannot report.
  ///
  /// In en, this message translates to:
  /// **'{outlet}, {section}, {time}'**
  String visitPhotoSemantics(String outlet, String section, String time);

  /// Section heading over the fraud detector's output.
  ///
  /// In en, this message translates to:
  /// **'Fraud signals'**
  String get visitFraudSignals;

  /// The risk figure's scale.
  ///
  /// In en, this message translates to:
  /// **'of 100'**
  String get visitRiskOfHundred;

  /// The risk figure and its band as one utterance.
  ///
  /// In en, this message translates to:
  /// **'Risk {value} out of 100. {band}.'**
  String visitRiskSemantics(int value, String band);

  /// Whole-screen state for a visit id that resolves to nothing.
  ///
  /// In en, this message translates to:
  /// **'This visit is not here'**
  String get visitNotFoundHeadline;

  /// Body of the not-found state.
  ///
  /// In en, this message translates to:
  /// **'It does not exist, or it belongs to another client.'**
  String get visitNotFoundBody;

  /// The way on from the not-found state.
  ///
  /// In en, this message translates to:
  /// **'Back to alerts'**
  String get visitBackToAlerts;

  /// The reviewed visit's score and its band as one utterance, so a reader never hears the figure without the verdict.
  ///
  /// In en, this message translates to:
  /// **'{value} out of 100. {band}.'**
  String visitReviewScoreSemantics(int value, String band);

  /// Section heading over the answers to the client's own audit template (#122), on the manager's visit review.
  ///
  /// In en, this message translates to:
  /// **'Client questions · {template}'**
  String visitReviewClientQuestions(String template);

  /// Fallback name of the full-screen artifact route, for a tool this build has not heard of. A server that shipped ahead of the app is normal, not an error.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get artifactTitleView;

  /// Screen-reader label for the back control, which returns to the conversation with its transcript and scroll position intact.
  ///
  /// In en, this message translates to:
  /// **'Back to Ask TradeIQ'**
  String get artifactBackToAsk;

  /// The back control on a deep link, which has no conversation to return to.
  ///
  /// In en, this message translates to:
  /// **'Back to The Floor'**
  String get artifactBackToFloor;

  /// Section heading over the controls that steer the artifact.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get artifactFilters;

  /// Reverts the last filter change. Hidden rather than disabled when there is nothing to undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get artifactUndo;

  /// Block label over the period chips.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get artifactPeriod;

  /// A period the artifact can be re-run over.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get artifactPeriodToday;

  /// A period the artifact can be re-run over.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get artifactPeriodYesterday;

  /// A period the artifact can be re-run over.
  ///
  /// In en, this message translates to:
  /// **'Last week'**
  String get artifactPeriodLastWeek;

  /// A period the artifact can be re-run over.
  ///
  /// In en, this message translates to:
  /// **'Month to date'**
  String get artifactPeriodMonthToDate;

  /// A period the artifact can be re-run over.
  ///
  /// In en, this message translates to:
  /// **'Year to date'**
  String get artifactPeriodYearToDate;

  /// A period kind this build does not recognise. Named neutrally rather than guessed at.
  ///
  /// In en, this message translates to:
  /// **'Selected period'**
  String get artifactPeriodSelected;

  /// Opens the date-range picker for a custom period.
  ///
  /// In en, this message translates to:
  /// **'Pick dates'**
  String get artifactPickDates;

  /// The chosen custom period, on the chip that chose it.
  ///
  /// In en, this message translates to:
  /// **'{from} to {to}'**
  String artifactCustomRange(String from, String to);

  /// Title of the date-range picker.
  ///
  /// In en, this message translates to:
  /// **'Custom period'**
  String get artifactCustomPeriod;

  /// Block label over the bucket-size chips.
  ///
  /// In en, this message translates to:
  /// **'Granularity'**
  String get artifactGranularity;

  /// One bucket per day.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get artifactDaily;

  /// One bucket per week.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get artifactWeekly;

  /// Block label over the comparison chips.
  ///
  /// In en, this message translates to:
  /// **'Compare with'**
  String get artifactCompareWith;

  /// No comparison series at all.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get artifactCompareNone;

  /// Compare against the equally long window before this one.
  ///
  /// In en, this message translates to:
  /// **'The period before'**
  String get artifactComparePreviousPeriod;

  /// Compare against the same calendar window a year back.
  ///
  /// In en, this message translates to:
  /// **'Same period last year'**
  String get artifactCompareLastYear;

  /// Compare against a second territory.
  ///
  /// In en, this message translates to:
  /// **'Another territory'**
  String get artifactCompareTerritory;

  /// A comparison kind this build does not recognise.
  ///
  /// In en, this message translates to:
  /// **'Compared'**
  String get artifactCompared;

  /// The comparison series' name in the legend, where the server sent none. A legend never names a line it cannot name.
  ///
  /// In en, this message translates to:
  /// **'Comparison'**
  String get artifactComparison;

  /// Block label over the territory picker, and the picker's own label.
  ///
  /// In en, this message translates to:
  /// **'Territory'**
  String get artifactTerritory;

  /// The unscoped territory choice. Nothing selected is a state, and here it has a name.
  ///
  /// In en, this message translates to:
  /// **'The whole business'**
  String get artifactWholeBusiness;

  /// Subtitle of the territory picker's sheet.
  ///
  /// In en, this message translates to:
  /// **'Every figure in this view is scoped to this choice.'**
  String get artifactTerritorySheetBody;

  /// Said while the territory list is in flight.
  ///
  /// In en, this message translates to:
  /// **'Loading territories…'**
  String get artifactTerritoriesLoading;

  /// The artifact still works unscoped, so a failed territory list is a missing control rather than a broken screen.
  ///
  /// In en, this message translates to:
  /// **'Territories are unavailable — showing the whole business.'**
  String get artifactTerritoriesUnavailable;

  /// Empty state inside the territory picker's sheet.
  ///
  /// In en, this message translates to:
  /// **'No territories yet'**
  String get artifactNoTerritoriesHeadline;

  /// Body of the no-territories state.
  ///
  /// In en, this message translates to:
  /// **'Add a territory to scope this view to part of the business.'**
  String get artifactNoTerritoriesBody;

  /// Why the territory picker is dead for a moment.
  ///
  /// In en, this message translates to:
  /// **'The last change is still being applied.'**
  String get artifactBusyReason;

  /// Says what a control costs, because the honest answer is surprising: it is a re-query, so it neither spends a turn nor changes the answer above it in the conversation.
  ///
  /// In en, this message translates to:
  /// **'Changing a filter re-runs the same query. It does not ask the assistant again.'**
  String get artifactRerunsTheQuery;

  /// The route's one commit.
  ///
  /// In en, this message translates to:
  /// **'Export as a PDF'**
  String get artifactExportPdf;

  /// The export's busy label. The words stay on the button while it works — a spinner in their place leaves a screen reader announcing an unlabelled button.
  ///
  /// In en, this message translates to:
  /// **'Preparing…'**
  String get artifactPreparing;

  /// Why the export is disabled mid-refine: exporting now would produce a report of neither state.
  ///
  /// In en, this message translates to:
  /// **'The figures are still being replaced.'**
  String get artifactExportBlocked;

  /// Says what the exported document contains.
  ///
  /// In en, this message translates to:
  /// **'The chart as an image, every figure as text you can select.'**
  String get artifactExportNote;

  /// A transient export failure — a dismissed share sheet, a platform that refused once.
  ///
  /// In en, this message translates to:
  /// **'That view could not be exported. Please try again.'**
  String get artifactExportFailed;

  /// An export that has nothing to share to. It fails identically on every retry, so telling the user to try again would send them round a loop.
  ///
  /// In en, this message translates to:
  /// **'Exporting is not available in this build of the app. Reload the page — if it keeps happening, the build needs replacing.'**
  String get artifactExportUnavailable;

  /// Whole-screen state when the artifact will not load.
  ///
  /// In en, this message translates to:
  /// **'That view could not be opened'**
  String get artifactCouldNotOpenHeadline;

  /// Body of the could-not-open state, where the server gave no words of its own.
  ///
  /// In en, this message translates to:
  /// **'It may have been removed, or it belongs to a tool you do not have.'**
  String get artifactCouldNotOpenBody;

  /// Announced while the figures are being replaced, so the dimming is not the only channel.
  ///
  /// In en, this message translates to:
  /// **'Applying the change…'**
  String get artifactRefining;

  /// Empty state for a pillar view with nothing in it.
  ///
  /// In en, this message translates to:
  /// **'No figures were returned for this period'**
  String get artifactNoFiguresHeadline;

  /// Body of the no-figures state — what to actually do about it.
  ///
  /// In en, this message translates to:
  /// **'Widen the period, or clear the territory filter.'**
  String get artifactNoFiguresBody;

  /// Empty state where a table twin has no rows.
  ///
  /// In en, this message translates to:
  /// **'Nothing to tabulate'**
  String get artifactNothingToTabulate;

  /// Stands where a percentage change would be, when the server declined to compute one rather than inventing it.
  ///
  /// In en, this message translates to:
  /// **'no baseline'**
  String get artifactNoBaseline;

  /// The applied-filters sentence when there are none.
  ///
  /// In en, this message translates to:
  /// **'No filters applied.'**
  String get artifactNoFilters;

  /// The custom period, inside the applied-filters sentence.
  ///
  /// In en, this message translates to:
  /// **'{from} to {to}'**
  String artifactRangeInWords(String from, String to);

  /// Part of the applied-filters sentence.
  ///
  /// In en, this message translates to:
  /// **'daily buckets'**
  String get artifactDailyBuckets;

  /// Part of the applied-filters sentence.
  ///
  /// In en, this message translates to:
  /// **'weekly buckets'**
  String get artifactWeeklyBuckets;

  /// Part of the applied-filters sentence.
  ///
  /// In en, this message translates to:
  /// **'one territory'**
  String get artifactOneTerritory;

  /// Part of the applied-filters sentence.
  ///
  /// In en, this message translates to:
  /// **'compared with the period before'**
  String get artifactComparedPreviousPeriod;

  /// Part of the applied-filters sentence.
  ///
  /// In en, this message translates to:
  /// **'compared with the same period last year'**
  String get artifactComparedLastYear;

  /// Part of the applied-filters sentence.
  ///
  /// In en, this message translates to:
  /// **'compared with another territory'**
  String get artifactComparedTerritory;

  /// Part of a view's subtitle, naming its bucket size.
  ///
  /// In en, this message translates to:
  /// **'By day'**
  String get artifactByDay;

  /// Part of a view's subtitle, naming its bucket size.
  ///
  /// In en, this message translates to:
  /// **'By week'**
  String get artifactByWeek;

  /// Part of a view's subtitle, naming what it is compared with.
  ///
  /// In en, this message translates to:
  /// **'vs {label}'**
  String artifactVersus(String label);

  /// Fallback name of a ranked-bars view whose server title is absent.
  ///
  /// In en, this message translates to:
  /// **'Ranking'**
  String get artifactTitleRanking;

  /// Name of a stat-tiles view.
  ///
  /// In en, this message translates to:
  /// **'Key figures'**
  String get artifactTitleKeyFigures;

  /// Fallback name of a trend view whose metric this build does not know.
  ///
  /// In en, this message translates to:
  /// **'Trend'**
  String get artifactTitleTrend;

  /// Name of the sales pillar view.
  ///
  /// In en, this message translates to:
  /// **'Sales figures'**
  String get artifactTitleSalesFigures;

  /// Name of the stock pillar view.
  ///
  /// In en, this message translates to:
  /// **'Stock figures'**
  String get artifactTitleStockFigures;

  /// Name of the visibility pillar view.
  ///
  /// In en, this message translates to:
  /// **'Visibility figures'**
  String get artifactTitleVisibilityFigures;

  /// Name of the competition pillar view.
  ///
  /// In en, this message translates to:
  /// **'Competition figures'**
  String get artifactTitleCompetitionFigures;

  /// The honest fallback where the pillar is unknown: the row stores tool arguments, which carry no pillar.
  ///
  /// In en, this message translates to:
  /// **'Figures'**
  String get artifactTitleFigures;

  /// The name of the tool behind this artifact.
  ///
  /// In en, this message translates to:
  /// **'Sales performance'**
  String get artifactToolSalesPerformance;

  /// The name of the tool behind this artifact.
  ///
  /// In en, this message translates to:
  /// **'SKU movement'**
  String get artifactToolSkuMovement;

  /// The name of the tool behind this artifact.
  ///
  /// In en, this message translates to:
  /// **'Stock levels'**
  String get artifactToolStockLevels;

  /// The name of the tool behind this artifact.
  ///
  /// In en, this message translates to:
  /// **'Share of shelf'**
  String get artifactToolShareOfShelf;

  /// The name of the tool behind this artifact.
  ///
  /// In en, this message translates to:
  /// **'Visibility compliance'**
  String get artifactToolVisibility;

  /// The name of the tool behind this artifact.
  ///
  /// In en, this message translates to:
  /// **'Competitor activity'**
  String get artifactToolCompetitor;

  /// The name of the tool behind this artifact.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get artifactToolVisits;

  /// The name of the tool behind this artifact.
  ///
  /// In en, this message translates to:
  /// **'Flagged visits'**
  String get artifactToolFlaggedVisits;

  /// The name of the tool behind this artifact.
  ///
  /// In en, this message translates to:
  /// **'Agent scorecard'**
  String get artifactToolAgentScorecard;

  /// The name of the tool behind this artifact.
  ///
  /// In en, this message translates to:
  /// **'Trend'**
  String get artifactToolTrend;
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
