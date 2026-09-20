import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

/// The locales the app ships, English first: English is the template locale
/// and the fallback for any device language we do not support.
const appSupportedLocales = <Locale>[Locale('en'), Locale('af')];

/// The app's messages plus Material/Cupertino/widgets' own translations
/// (date pickers, "Back" semantics, text direction).
const appLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// Picks the UI locale from the device's preference list: the first device
/// language we support wins (so `af_ZA` → `af`), anything else → English.
///
/// Deliberately not Flutter's default resolution, which falls back to the
/// *first* supported locale and would depend on list order.
Locale resolveAppLocale(List<Locale>? preferred, Iterable<Locale> supported) {
  for (final device in preferred ?? const <Locale>[]) {
    for (final candidate in supported) {
      if (candidate.languageCode == device.languageCode) return candidate;
    }
  }
  return const Locale('en');
}

/// The English (template) messages, for callers with no [BuildContext] or no
/// installed delegate.
final AppLocalizations englishLocalizations = lookupAppLocalizations(
  const Locale('en'),
);

extension AppLocalizationsContext on BuildContext {
  /// The active translations.
  ///
  /// Falls back to English when no [AppLocalizations] delegate is installed
  /// — a widget test pumping a bare `MaterialApp(home: ...)` still renders
  /// the exact English copy it always did.
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ?? englishLocalizations;
}

/// "14:20" in the active locale.
///
/// The outbox says when a capture was queued and when it was last tried, and
/// those are clock times rather than "2h ago": an agent deciding whether to
/// wait for signal needs the time on the till receipt, not a duration. The
/// format is the locale's, so a locale that reads 2:20 PM gets 2:20 PM.
String formatClock(BuildContext context, DateTime when) {
  try {
    return DateFormat.Hm(context.l10n.localeName).format(when);
  } on Exception {
    // intl throws when a locale's date symbols were never loaded — a screen
    // pumped without the Material delegates has none. en_US is built in.
    return DateFormat.Hm('en_US').format(when);
  }
}

/// "Monday, 14 September" in the active locale ("Maandag, 14 September" in
/// Afrikaans).
String formatDayHeading(BuildContext context, DateTime date) {
  try {
    return DateFormat('EEEE, d MMMM', context.l10n.localeName).format(date);
  } on Exception {
    // intl throws when a locale's date symbols were never loaded — the app
    // loads them through GlobalMaterialLocalizations, but a screen pumped
    // without those delegates has none. en_US is built into intl, so the
    // heading still reads exactly as it did in English.
    return DateFormat('EEEE, d MMMM', 'en_US').format(date);
  }
}

/// "Thu 18 Sep" in the active locale — the day a row happened, short enough to
/// sit in a meta line beside a dwell time and a task count.
///
/// Same fallback as [formatDayHeading], and for the same reason.
String formatDayShort(BuildContext context, DateTime date) {
  try {
    return DateFormat('EEE d MMM', context.l10n.localeName).format(date);
  } on Exception {
    return DateFormat('EEE d MMM', 'en_US').format(date);
  }
}

