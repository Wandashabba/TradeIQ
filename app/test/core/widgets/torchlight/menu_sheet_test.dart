import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/auth/auth_repository.dart';
import 'package:tradeiq_app/core/auth/token_store.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/nav_destinations.dart';
import 'package:tradeiq_app/core/widgets/torchlight/menu_sheet.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

import '../../../features/auth/entry_harness.dart';
import '../../design/amber_golden.dart';

/// THE MENU SHEET — one sheet, and the sign-out that went missing.
///
/// The glass `nav_menu_sheet.dart` carried a theme toggle and Sign out; the
/// Torchlight `showConsoleMenu` that replaced it on migrated routes carried
/// neither. A manager on a migrated route on a phone could not sign out of
/// the app. These tests are the reason that cannot happen again quietly.
void main() {
  Finder key(String k) => find.byKey(ValueKey<String>(k));

  Future<void> pumpMenu(
    WidgetTester tester, {
    SkinMode skin = SkinMode.night,
    Locale locale = const Locale('en'),
    double textScale = 1.0,
    List<Override> overrides = const <Override>[],
    TokenStore? tokens,
    Size size = const Size(360, 720),
  }) async {
    // The open-sheet count is an app-wide static. Every test here ends with
    // the menu up, which is the frame under test rather than a leak.
    TorchSheets.resetForTest();
    addTearDown(TorchSheets.resetForTest);

    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final resolved = switch (skin) {
      SkinMode.veld => TiqSkin.veld(),
      SkinMode.day => TiqSkin.day(density: TiqDensity.console),
      _ => TiqSkin.night(density: TiqDensity.console),
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          localDbProvider.overrideWithValue(entryTestDb()),
          tokenStoreProvider.overrideWithValue(tokens ?? FakeTokenStore()),
          ...overrides,
        ],
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            devicePixelRatio: 1.0,
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: MaterialApp.router(
            locale: locale,
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            localeListResolutionCallback: resolveAppLocale,
            theme: AppTheme.torchlight(resolved),
            builder: (context, child) => RepaintBoundary(
              key: const ValueKey<String>('amber-golden-boundary'),
              child: ColoredBox(color: resolved.palette.ground, child: child!),
            ),
            routerConfig: GoRouter(
              initialLocation: '/here',
              routes: <RouteBase>[
                GoRoute(
                  path: '/here',
                  builder: (context, state) => const _Host(),
                ),
                GoRoute(
                  path: '/account/password',
                  builder: (context, state) => const Text('PASSWORD SCREEN'),
                ),
                GoRoute(
                  path: '/territories',
                  builder: (context, state) => const Text('TERRITORIES'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Through the real opener, not by pumping the body: the rows pop the
    // sheet on their way out, and a body pumped as its own route would pop
    // the only route there is.
    await tester.tap(find.text('OPEN THE MENU'));
    await tester.pumpAndSettle();
  }

  Future<void> scrollMenuTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      160,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 60,
    );
    await tester.pumpAndSettle();
  }

  group('the destinations', () {
    testWidgets('every manager destination is in the sheet, once', (
      tester,
    ) async {
      await pumpMenu(tester);
      for (final destination in managerDestinations) {
        await scrollMenuTo(tester, key('menu-${destination.route}'));
        expect(
          key('menu-${destination.route}'),
          findsOneWidget,
          reason: '${destination.route} is missing from the menu',
        );
      }
    });

    testWidgets('they are grouped by the three verbs', (tester) async {
      await pumpMenu(tester);
      for (final name in <String>['Operate', 'Insight', 'Configure']) {
        expect(find.text(name.toUpperCase()), findsOneWidget);
      }
    });

    testWidgets('a destination row goes there and closes the sheet', (
      tester,
    ) async {
      await pumpMenu(tester);
      await scrollMenuTo(tester, key('menu-/territories'));
      await tester.tap(key('menu-/territories'));
      await tester.pumpAndSettle();

      expect(find.text('TERRITORIES'), findsOneWidget);
    });

    testWidgets('a row is a compact soft row, not a bordered tile', (
      tester,
    ) async {
      await pumpMenu(tester);
      final row = tester.widget<SoftRow>(key('menu-/tasks'));
      expect(row.density, SoftRowDensity.compact);
    });
  });

  group('the housekeeping the glass sheet had and the Torchlight one lost', () {
    testWidgets('Sign out is there, and it signs out', (tester) async {
      final tokens = FakeTokenStore()
        ..session = const StoredSession(token: 't', role: 'manager');
      await pumpMenu(
        tester,
        tokens: tokens,
        overrides: <Override>[
          authRepositoryProvider.overrideWithValue(_NeverAuth()),
        ],
      );
      await scrollMenuTo(tester, key('menu-sign-out'));
      await tester.tap(key('menu-sign-out'));
      await tester.pumpAndSettle();

      expect(
        tokens.session,
        isNull,
        reason:
            'a manager on a migrated route had no way out of the app from a '
            'phone; this is the test that says so out loud',
      );
    });

    testWidgets('the theme toggle is there, and it toggles', (tester) async {
      await pumpMenu(tester);
      await scrollMenuTo(tester, key('menu-theme'));
      final before = tester.widget<SoftRow>(key('menu-theme')).title;
      await tester.tap(key('menu-theme'));
      await tester.pumpAndSettle();
      final after = tester.widget<SoftRow>(key('menu-theme')).title;

      expect(before, isNot(after));
      // Names where it GOES, never where it is.
      expect(<String>{before, after}, <String>{'Light theme', 'Dark theme'});
    });

    testWidgets('Change password goes to the password screen', (tester) async {
      await pumpMenu(tester);
      await scrollMenuTo(tester, key('menu-password'));
      await tester.tap(key('menu-password'));
      await tester.pumpAndSettle();

      expect(find.text('PASSWORD SCREEN'), findsOneWidget);
    });

    testWidgets('a reader can reach Sign out and press it', (tester) async {
      final tokens = FakeTokenStore()
        ..session = const StoredSession(token: 't', role: 'manager');
      await pumpMenu(
        tester,
        tokens: tokens,
        overrides: <Override>[
          authRepositoryProvider.overrideWithValue(_NeverAuth()),
        ],
      );
      await scrollMenuTo(tester, key('menu-sign-out'));
      final handle = tester.ensureSemantics();
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(
          type: SemanticsAction.tap,
          nodeId: tester.getSemantics(find.bySemanticsLabel('Sign out')).id,
          viewId: tester.view.viewId,
        ),
      );
      await tester.pumpAndSettle();

      expect(tokens.session, isNull, reason: 'Sign out is a label, not a key');
      handle.dispose();
    });
  });

  group('every word in it is translated', () {
    testWidgets('Afrikaans names the groups, the rows and the way out', (
      tester,
    ) async {
      await pumpMenu(tester, locale: const Locale('af'));

      expect(find.text('Kieslys'), findsOneWidget);
      expect(find.text('Bedryf'.toUpperCase()), findsOneWidget);
      expect(find.text('Insig'.toUpperCase()), findsOneWidget);
      expect(find.text('Stel op'.toUpperCase()), findsOneWidget);
      expect(find.text('Die Vloer'), findsOneWidget);
      // The English words are nowhere on an Afrikaans screen.
      for (final english in <String>[
        'Menu',
        'Operate',
        'Insight',
        'Configure',
        'The Floor',
        'Sign out',
      ]) {
        expect(
          find.text(english, skipOffstage: false),
          findsNothing,
          reason: '"$english" is hardcoded English inside an Afrikaans screen',
        );
      }
    });

    /// THE FAILURE, WRITTEN AS ITSELF.
    ///
    /// `TorchSheet.closeLabel` defaulted to the literal `'Close'` and
    /// `_MenuSheet` passed nothing, so in Veld — the one form with no scrim
    /// and, until this change, a Close row instead of a back gesture — an
    /// Afrikaans agent outdoors was shown one way out of the menu, in a
    /// language she may not read.
    testWidgets('the Veld way out is Afrikaans too', (tester) async {
      await pumpMenu(tester, skin: SkinMode.veld, locale: const Locale('af'));

      expect(find.text('Maak toe'), findsOneWidget);
      expect(
        find.text('Close', skipOffstage: false),
        findsNothing,
        reason:
            '"Close" is hardcoded English on the only way out of a Veld sheet',
      );
    });

    testWidgets('and in English it still says Close', (tester) async {
      await pumpMenu(tester, skin: SkinMode.veld);
      expect(find.text('Close'), findsOneWidget);
    });

    test('every manager destination has an Afrikaans name', () {
      final af = lookupAppLocalizations(const Locale('af'));
      final en = lookupAppLocalizations(const Locale('en'));
      for (final destination in managerDestinations) {
        expect(
          destination.labelIn(af),
          isNot(destination.label),
          reason:
              '${destination.route} falls through to its English label — add '
              'a nav* key for it',
          skip: destination.route == '/webhooks'
              ? 'a technical term, deliberately untranslated'
              : null,
        );
        expect(destination.labelIn(en), isNotEmpty);
      }
    });
  });

  group('the menu commits nothing', () {
    for (final skin in <SkinMode>[
      SkinMode.night,
      SkinMode.day,
      SkinMode.veld,
    ]) {
      testWidgets('${skin.name}: no amber anywhere in it', (tester) async {
        await pumpMenu(tester, skin: skin);
        final census = await amberCensus(tester);
        expect(
          census.objectCount,
          0,
          reason:
              'a menu has nothing to commit, so it lights nothing\n'
              '${census.describe()}',
        );
      });
    }
  });

  testWidgets('2.0× Afrikaans does not overflow', (tester) async {
    await pumpMenu(tester, locale: const Locale('af'), textScale: 2.0);
    expect(tester.takeException(), isNull);
  });
}

/// A screen with one control on it: the thing that opens the menu.
class _Host extends StatelessWidget {
  const _Host();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.skin.palette.ground,
      child: Center(
        child: GestureDetector(
          onTap: () => showTorchMenuSheet(context),
          child: Text(
            'OPEN THE MENU',
            style: context.skin.text.body.style(
              color: context.skin.palette.ink1,
            ),
          ),
        ),
      ),
    );
  }
}

class _NeverAuth implements AuthRepository {
  @override
  Future<AuthResult> login(String email, String password) =>
      throw UnimplementedError();
}
