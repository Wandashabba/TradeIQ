import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/auth/token_store.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/menu_sheet.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/features/auth/presentation/login_screen.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

import '../agent_harness.dart';
import '../auth/entry_harness.dart';

/// THE TWO SCREENS THE OWNER IS LOOKING AT.
///
/// "The menu on the manager side still has the rectangular shapes, I don't want
/// that, and the login as well." These are those two, rendered with Onest and
/// JetBrains Mono so the corners are the real corners.
///
/// Skipped in CI behind `SOFT_LOOK`, for the reason `floor_look_test.dart`
/// gives: CI rasterises anti-aliased Onest on Linux and this repository is
/// developed on macOS.
void main() {
  final looking = Platform.environment['SOFT_LOOK'] == '1';

  setUpAll(loadAgentFonts);

  testWidgets('the manager’s menu', (tester) async {
    TorchSheets.resetForTest();
    addTearDown(TorchSheets.resetForTest);
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final skin = TiqSkin.night(density: TiqDensity.console);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          localDbProvider.overrideWithValue(entryTestDb()),
          tokenStoreProvider.overrideWithValue(FakeTokenStore()),
        ],
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            devicePixelRatio: 1.0,
            disableAnimations: true,
          ),
          child: MaterialApp.router(
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            theme: AppTheme.torchlight(skin),
            builder: (context, child) => RepaintBoundary(
              key: const ValueKey<String>('amber-golden-boundary'),
              child: ColoredBox(color: skin.palette.ground, child: child!),
            ),
            routerConfig: GoRouter(
              initialLocation: '/here',
              routes: <RouteBase>[
                GoRoute(
                  path: '/here',
                  builder: (context, state) => Builder(
                    builder: (context) => Center(
                      child: GestureDetector(
                        onTap: () => showTorchMenuSheet(context),
                        child: const Text('OPEN'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const ValueKey<String>('amber-golden-boundary')),
      matchesGoldenFile('goldens/soft_menu_390x844.png'),
    );
  }, skip: !looking);

  for (final mode in <SkinMode>[SkinMode.night, SkinMode.day]) {
    testWidgets('sign in — ${mode.name}', (tester) async {
      await pumpEntryScreen(
        tester,
        const LoginScreen(),
        path: '/login',
        overrides: <Override>[
          ...entryBaseOverrides(db: entryTestDb(), skin: mode),
        ],
        extraRoutes: <GoRoute>[
          namedRoute('/', 'SPLASH'),
          namedRoute('/forgot-password', 'FORGOT'),
          namedRoute('/dashboard', 'DASHBOARD'),
        ],
      );

      await expectLater(
        find.byKey(entryBoundaryKey),
        matchesGoldenFile('goldens/soft_login_${mode.name}.png'),
      );
    }, skip: !looking);
  }
}
