import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/app_language_controller.dart';
import 'core/push/push_registration.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_controller.dart';
import 'l10n/l10n.dart';

void main() {
  runApp(const ProviderScope(child: TradeIqApp()));
}

class TradeIqApp extends ConsumerWidget {
  const TradeIqApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Push (#67): registers this install's token for whoever signs in and
    // removes it on sign-out. Listened, not watched — a registration must not
    // rebuild the whole app. Inert while push is unconfigured.
    ref.listen(pushRegistrationProvider, (_, _) {});
    return MaterialApp.router(
      title: 'TradeIQ',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Persisted choice; defaults to dark, so nobody's console changes until
      // they touch the toggle (Task 7).
      themeMode: ref.watch(themeModeProvider),
      // The agent's language override (#40); null follows the device.
      locale: ref.watch(appLanguageProvider).locale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      localeListResolutionCallback: resolveAppLocale,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
