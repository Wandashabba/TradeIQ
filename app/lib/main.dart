import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/app_language_controller.dart';
import 'core/push/push_registration.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_controller.dart';
import 'core/theme/torchlight/tiq_skin.dart';
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
      // Torchlight Aisle (#401). Screens still reading `context.colors` render
      // through `TiqColors.fromSkin`, so the palette lands everywhere at once
      // and the per-screen migration is about layout and components, not colour.
      theme: AppTheme.day(),
      darkTheme: AppTheme.night(),
      // Persisted choice; defaults to dark, so nobody's console changes until
      // they touch the toggle (Task 7).
      themeMode: ref.watch(themeModeProvider),
      // The agent's language override (#40); null follows the device.
      locale: ref.watch(appLanguageProvider).locale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      localeListResolutionCallback: resolveAppLocale,
      // Torchlight's text-scaling policy: clamp the OS setting to 1.0–2.0 for
      // the whole app. The audit found no textScale handling anywhere, which
      // meant a reader at the largest Android setting got whatever the layouts
      // happened to do. 2.0 rather than a lower ceiling on purpose — anything
      // under 2.0 on body text is a 1.4.4 failure dressed as a layout policy.
      // The one role that caps lower (hero.figure, at 1.6) declares that on its
      // own token and wraps itself in TiqRoleTextScale.
      builder: (context, child) =>
          TiqTextScaleScope(child: child ?? const SizedBox.shrink()),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
