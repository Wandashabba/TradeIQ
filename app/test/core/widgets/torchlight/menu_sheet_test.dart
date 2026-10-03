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
    String at = '/here',
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
              initialLocation: at,
              routes: <RouteBase>[
                GoRoute(
                  path: '/here',
                  builder: (context, state) => const _Host(),
                ),
                GoRoute(
                  path: '/account/password',
                  builder: (context, state) => const Text('PASSWORD SCREEN'),
                ),
                // Names itself AND hosts the opener, so one route serves both
                // "the row went there" and "the sheet opened from a location
                // that IS a destination" — which is every real opening of it.
                GoRoute(
                  path: '/territories',
                  builder: (context, state) => const _Host(name: 'TERRITORIES'),
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

  /// The groups fold shut, so a destination has to be asked for before it is
  /// in the tree at all. Every test below that wants a row opens its group
  /// first — which is also the assertion that the fold is what is hiding it.
  Future<void> openGroup(WidgetTester tester, NavGroup group) async {
    await scrollMenuTo(tester, key('menu-fold-${group.name}'));
    await tester.tap(key('menu-fold-${group.name}'));
    await tester.pumpAndSettle();
  }

  group('the destinations', () {
    testWidgets('every manager destination is in the sheet, once', (
      tester,
    ) async {
      await pumpMenu(tester);
      for (final group in NavGroup.values) {
        await openGroup(tester, group);
        for (final destination in destinationsIn(group)) {
          await scrollMenuTo(tester, key('menu-${destination.route}'));
          expect(
            key('menu-${destination.route}'),
            findsOneWidget,
            reason: '${destination.route} is missing from the menu',
          );
        }
        // Shut it again, so the next group is opened from a known state and
        // the single-open rule is exercised 24 rows deep rather than asserted
        // once.
        await openGroup(tester, group);
      }
    });

    testWidgets('they are grouped by the three verbs', (tester) async {
      await pumpMenu(tester);
      // Sentence case now, and carrying the group's size: these are rows with
      // titles rather than kickers on the ground. `SectionRule`'s own
      // `name · count` grammar, which is where the middot comes from.
      for (final group in NavGroup.values) {
        final name = navGroupName(lookupAppLocalizations(const Locale('en')), group);
        expect(
          find.text('$name · ${destinationsIn(group).length}'),
          findsOneWidget,
          reason: 'the $name group row is missing or does not carry its count',
        );
      }
    });

    testWidgets('a group row carries the real length of its own list', (
      tester,
    ) async {
      await pumpMenu(tester);
      // The one number this sheet shows, and the reason it is allowed to: it
      // is a const list's length, not a fetch.
      final counted = <NavGroup, int>{
        for (final g in NavGroup.values) g: destinationsIn(g).length,
      };
      expect(counted, <NavGroup, int>{
        NavGroup.operate: 9,
        NavGroup.insight: 8,
        NavGroup.configure: 7,
      });
      expect(counted.values.reduce((a, b) => a + b), managerDestinations.length);
      for (final group in NavGroup.values) {
        final row = tester.widget<SoftRow>(key('menu-fold-${group.name}'));
        expect(row.title, endsWith('· ${counted[group]}'));
      }
    });

    testWidgets('only one group is open at a time', (tester) async {
      await pumpMenu(tester);

      await openGroup(tester, NavGroup.operate);
      expect(key('menu-/tasks'), findsOneWidget);
      expect(key('menu-/reports'), findsNothing);

      // Opening Insight shuts Operate without being asked to. This is the
      // invariant the whole redesign rests on: the sheet cannot be grown back
      // into a 2,132dp scroll by tapping every header.
      await openGroup(tester, NavGroup.insight);
      expect(
        key('menu-/tasks'),
        findsNothing,
        reason: 'Operate stayed open when Insight was opened',
      );
      expect(key('menu-/reports'), findsOneWidget);

      // And a second tap on the open one shuts it, leaving nothing open.
      await openGroup(tester, NavGroup.insight);
      expect(key('menu-/reports'), findsNothing);
      for (final destination in managerDestinations) {
        expect(
          key('menu-${destination.route}'),
          findsNothing,
          reason: '${destination.route} is still built with every group shut',
        );
      }
    });

    testWidgets('the group holding the current route is open on appear', (
      tester,
    ) async {
      // /territories is in Configure, so Configure is open and the other two
      // are shut before anybody has tapped anything.
      await pumpMenu(tester, at: '/territories');

      expect(key('menu-/territories'), findsOneWidget);
      expect(key('menu-/users'), findsOneWidget, reason: 'its group-mate');
      expect(key('menu-/tasks'), findsNothing, reason: 'Operate is shut');
      expect(key('menu-/reports'), findsNothing, reason: 'Insight is shut');
    });

    testWidgets('a sub-route opens its parent destination’s group', (
      tester,
    ) async {
      // The longest-prefix match: /territories/42 is Territories, which is
      // Configure — a manager who opens the menu from a detail screen is shown
      // where they are standing.
      expect(menuDestinationFor('/territories/42')?.route, '/territories');
      // And the pair that makes it longest-prefix rather than first-match.
      expect(menuDestinationFor('/dashboard')?.route, '/dashboard');
      expect(
        menuDestinationFor('/dashboard/overview')?.route,
        '/dashboard/overview',
        reason:
            '/dashboard/overview starts with /dashboard; first-match would '
            'call it The Floor',
      );
      // A route that is not a destination opens nothing rather than guessing.
      expect(menuDestinationFor('/account/password'), isNull);
      expect(menuDestinationFor(null), isNull);
    });

    testWidgets('the row you are on is set apart without amber', (
      tester,
    ) async {
      await pumpMenu(tester, at: '/territories');
      final skin = TiqSkin.night(density: TiqDensity.console);

      Text labelOf(String route) => tester.widget<Text>(
        find.descendant(of: key('menu-$route'), matching: find.byType(Text)),
      );

      // Same size, more weight — the signal costs no light. `body.strong` and
      // `body` are both 13 on this scale, so nothing reflows either.
      expect(labelOf('/territories').style?.fontWeight, skin.text.bodyStrong.weight);
      expect(labelOf('/users').style?.fontWeight, skin.text.body.weight);
      expect(skin.text.bodyStrong.size, skin.text.body.size);
      expect(labelOf('/territories').style?.color, skin.palette.ink1);
      expect(labelOf('/users').style?.color, skin.palette.ink2);
    });

    testWidgets('a destination row goes there and closes the sheet', (
      tester,
    ) async {
      await pumpMenu(tester);
      await openGroup(tester, NavGroup.configure);
      await scrollMenuTo(tester, key('menu-/territories'));
      await tester.tap(key('menu-/territories'));
      await tester.pumpAndSettle();

      expect(find.text('TERRITORIES'), findsOneWidget);
    });

    testWidgets('a group row is a compact soft row, not a bordered tile', (
      tester,
    ) async {
      await pumpMenu(tester);
      final row = tester.widget<SoftRow>(key('menu-fold-operate'));
      expect(row.density, SoftRowDensity.compact);

      // And its children are deliberately NOT cards: nine more radius-22
      // cards under a card is nine more top-level rows, which is the one way
      // to draw an accordion so that opening it says nothing.
      await openGroup(tester, NavGroup.operate);
      expect(
        find.descendant(
          of: key('menu-/tasks'),
          matching: find.byType(SoftRow),
        ),
        findsNothing,
      );
    });

    testWidgets('every destination row draws its own icon', (tester) async {
      await pumpMenu(tester);
      for (final group in NavGroup.values) {
        await openGroup(tester, group);
        for (final destination in destinationsIn(group)) {
          await scrollMenuTo(tester, key('menu-${destination.route}'));
          final icon = tester.widget<Icon>(
            find.descendant(
              of: key('menu-${destination.route}'),
              matching: find.byType(Icon),
            ),
          );
          expect(
            icon.icon,
            destination.icon,
            reason:
                '${destination.route} carries an icon in the data and the '
                'sheet drew something else',
          );
        }
        await openGroup(tester, group);
      }
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
      // The group rows, in Afrikaans, carrying their counts.
      expect(find.text('Uitvoering · 9'), findsOneWidget);
      expect(find.text('Prestasie · 8'), findsOneWidget);
      expect(find.text('Opstelling · 7'), findsOneWidget);
      // And a destination inside one, which needs the fold opened first.
      await openGroup(tester, NavGroup.operate);
      expect(find.text('Die Vloer'), findsOneWidget);
      // The English words are nowhere on an Afrikaans screen.
      for (final english in <String>[
        'Menu',
        'Execution',
        'Performance',
        'Setup',
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

      // THE FOLD ADDED TWO STATES THAT WANT TO BE LIT. An open group and the
      // row you are standing on are both things a designer reaches for amber
      // to say, and this sheet says them in weight, ink and fill instead. The
      // budget is 2 objects on Night and 1 on Day; the sheet spends none of
      // it, expanded or shut, which is the claim this test makes quotable.
      testWidgets('${skin.name}: still no amber with a group open', (
        tester,
      ) async {
        await pumpMenu(tester, skin: skin, at: '/territories');
        // Opened on Configure, and Configure holds the current row — so this
        // frame has both new states in it at once.
        expect(key('menu-/territories'), findsOneWidget);
        final census = await amberCensus(tester);
        expect(
          census.objectCount,
          0,
          reason:
              'the open group or the current row lit something\n'
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

/// A screen with one control on it: the thing that opens the menu. [name] is
/// printed beside it so a test can tell which route it landed on.
class _Host extends StatelessWidget {
  const _Host({this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return ColoredBox(
      color: skin.palette.ground,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (name != null)
              Text(name!, style: skin.text.body.style(color: skin.palette.ink1)),
            GestureDetector(
              onTap: () => showTorchMenuSheet(context),
              child: Text(
                'OPEN THE MENU',
                style: skin.text.body.style(color: skin.palette.ink1),
              ),
            ),
          ],
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
