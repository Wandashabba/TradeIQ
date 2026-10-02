import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/auth/token_store.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/nav_destinations.dart';
import 'package:tradeiq_app/core/widgets/torchlight/menu_sheet.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

import '../../../features/agent_harness.dart';
import '../../../features/auth/entry_harness.dart';

/// THE NUMBER THAT JUSTIFIES THE FOLD, measured rather than claimed.
///
/// This file is the probe that produced the figures in `menu_sheet.dart`'s doc
/// comment, promoted into a test so they cannot quietly stop being true. It
/// prints what it measures, so when one of them moves the failure names the
/// new value instead of only going red.
///
/// ## What it was, before the fold — 2 October 2026
///
/// Measured on `integration/look` at 82ac5ddc, at 390×844, Night, 1.0×, in
/// English, with this same harness: **26 rows** (24 destinations plus the
/// theme and password rows), **2,132dp** of content inside a **710.7dp**
/// viewport — **1,421.3dp of scroll**. Every destination row was **68dp**
/// except *Execution overview*, which was **74dp** because its label already
/// wrapped to two lines at 390dp.
///
/// Those numbers are a historical record and cannot be re-measured from here:
/// the code that produced them is gone. The two constants below carry them so
/// the comparison is stated in one place rather than in prose.
const int beforeRowCount = 26;
const double beforeContentHeight = 2132;

void main() {
  // EVERY ASSERTION IN HERE IS ABOUT GEOMETRY, so it is made in the real
  // faces. Flutter's default test font is a square-ish stand-in that measures
  // "Execution overview" about 15% wider than Schibsted Grotesk does — wide
  // enough to wrap it at 360dp and report a defect this sheet does not have.
  // `agent_harness.dart` says out loud that a file which calls this should be
  // a file whose assertions are about fitting on a phone. This is that file.
  setUpAll(loadAgentFonts);

  Finder key(String k) => find.byKey(ValueKey<String>(k));

  Future<void> pumpMenu(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double textScale = 1.0,
    SkinMode skin = SkinMode.night,
    Locale locale = const Locale('en'),
    String at = '/here',
  }) async {
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
          tokenStoreProvider.overrideWithValue(FakeTokenStore()),
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
            routerConfig: GoRouter(
              initialLocation: at,
              routes: <RouteBase>[
                for (final path in <String>['/here', '/territories'])
                  GoRoute(
                    path: path,
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
  }

  Future<void> openGroup(WidgetTester tester, NavGroup group) async {
    await tester.tap(key('menu-fold-${group.name}'));
    await tester.pumpAndSettle();
  }

  /// The scrollable's real content extent — "how long is this sheet".
  ({double content, double viewport, double scroll}) extentOf(
    WidgetTester tester,
  ) {
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).last)
        .position;
    return (
      content: position.viewportDimension + position.maxScrollExtent,
      viewport: position.viewportDimension,
      scroll: position.maxScrollExtent,
    );
  }

  group('how long the sheet is', () {
    testWidgets('at rest it is five rows, not twenty-six', (tester) async {
      await pumpMenu(tester);

      // The three group rows plus the two housekeeping rows. Nothing else is
      // a row: the way out is a button, and the 24 destinations are not built
      // at all while their groups are shut, which is what makes this a fact
      // about the widget tree and not a claim about what you can see.
      final rows = tester.widgetList<SoftRow>(find.byType(SoftRow)).toList();
      expect(
        rows.length,
        5,
        reason:
            'rows at rest: ${rows.map((r) => r.title).toList()}\n'
            'it was $beforeRowCount before the fold',
      );
      for (final destination in managerDestinations) {
        expect(
          key('menu-${destination.route}'),
          findsNothing,
          reason: '${destination.route} is built while its group is shut',
        );
      }
    });

    testWidgets('at rest on a 390×844 phone it does not scroll at all', (
      tester,
    ) async {
      await pumpMenu(tester);
      final e = extentOf(tester);
      printOnFailure(
        'REST 390×844: content=${e.content} viewport=${e.viewport} '
        'scroll=${e.scroll} (was $beforeContentHeight content)',
      );

      expect(
        e.scroll,
        0,
        reason:
            'the whole menu fits the window at rest: content=${e.content} '
            'viewport=${e.viewport}',
      );
      // A fifth of what it was, and the fold is the whole of the difference.
      expect(e.content, lessThan(beforeContentHeight / 3));
    });

    testWidgets('the longest group open is still a third of the old scroll', (
      tester,
    ) async {
      await pumpMenu(tester);
      // Operate is the big one: nine destinations.
      await openGroup(tester, NavGroup.operate);
      final e = extentOf(tester);
      printOnFailure(
        'OPERATE OPEN 390×844: content=${e.content} scroll=${e.scroll}',
      );
      expect(destinationsIn(NavGroup.operate).length, 9);
      expect(e.content, lessThan(beforeContentHeight / 2));
    });

    testWidgets('it holds at 360×640 and at 1.3× text', (tester) async {
      for (final scale in <double>[1.0, 1.3]) {
        await pumpMenu(tester, size: const Size(360, 640), textScale: scale);
        final rest = extentOf(tester);
        await openGroup(tester, NavGroup.operate);
        final open = extentOf(tester);
        printOnFailure(
          'REST 360×640 @$scale×: content=${rest.content} '
          'viewport=${rest.viewport} scroll=${rest.scroll} — '
          'OPERATE OPEN: content=${open.content} scroll=${open.scroll}',
        );
        expect(tester.takeException(), isNull);
        // The small phone is tighter than the 390 one and may scroll a little
        // at rest; what must not come back is the old order of magnitude.
        expect(rest.content, lessThan(beforeContentHeight / 3));
      }
    });
  });

  group('the 44dp floor', () {
    for (final scale in <double>[1.0, 1.3]) {
      testWidgets('every destination row clears it at $scale×', (
        tester,
      ) async {
        await pumpMenu(tester, size: const Size(360, 640), textScale: scale);
        final floor = TiqSkin.night(
          density: TiqDensity.console,
        ).space.tapTarget;
        expect(floor, 44, reason: 'the floor this test is named after');

        final heights = <String, double>{};
        for (final group in NavGroup.values) {
          await openGroup(tester, group);
          for (final destination in destinationsIn(group)) {
            final size = tester.getSize(key('menu-${destination.route}'));
            heights[destination.route] = size.height;
            expect(
              size.height,
              greaterThanOrEqualTo(floor),
              reason:
                  '${destination.route} is ${size.height}dp — under the '
                  'WCAG 2.5.5 floor. "Smaller" does not outrank it.',
            );
          }
          await openGroup(tester, group);
        }
        printOnFailure('ROW HEIGHTS @$scale×: $heights');
      });

      testWidgets('every group row clears it at $scale×', (tester) async {
        await pumpMenu(tester, size: const Size(360, 640), textScale: scale);
        for (final group in NavGroup.values) {
          final size = tester.getSize(key('menu-fold-${group.name}'));
          expect(size.height, greaterThanOrEqualTo(44));
          printOnFailure('${group.name} group row: ${size.height}dp');
        }
      });
    }
  });

  group('nothing wraps at the smaller size', () {
    for (final scale in <double>[1.0, 1.3]) {
      testWidgets('every destination label is one line at $scale×', (
        tester,
      ) async {
        // The narrow phone, because this is a width question and 360 is the
        // width the brief names.
        await pumpMenu(tester, size: const Size(360, 640), textScale: scale);
        final l10n = lookupAppLocalizations(const Locale('en'));

        final lines = <String, int>{};
        for (final group in NavGroup.values) {
          await openGroup(tester, group);
          for (final destination in destinationsIn(group)) {
            final label = destination.labelIn(l10n);
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(
                of: key('menu-${destination.route}'),
                matching: find.text(label),
              ),
            );
            // One line at unlimited width is the height of one line; the
            // laid-out height divided by it is how many lines it took. A
            // cleaner question than counting glyphs, and it is the same
            // measurement a reader makes with their eye.
            final oneLine = paragraph.getMaxIntrinsicHeight(double.infinity);
            final count = (paragraph.size.height / oneLine).round();
            lines[label] = count;
            expect(
              count,
              1,
              reason:
                  '"$label" wraps to $count lines at $scale× on a 360dp '
                  'phone (${paragraph.size.height}dp tall, one line is '
                  '${oneLine}dp). It is the label the brief names: Execution '
                  'overview wrapped at 390dp BEFORE this change, and the '
                  'point of the smaller scale is that it stops.',
            );
            // And it is not ellipsised either, which a line count cannot see.
            expect(
              paragraph.didExceedMaxLines,
              isFalse,
              reason: '"$label" is clipped at $scale×',
            );
          }
          await openGroup(tester, group);
        }
        printOnFailure('LINE COUNTS @$scale×: $lines');
      });
    }
  });

  group('the lead block', () {
    testWidgets('stays above the groups and does not fold', (tester) async {
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
            child: MaterialApp(
              supportedLocales: appSupportedLocales,
              localizationsDelegates: appLocalizationsDelegates,
              theme: AppTheme.torchlight(skin),
              home: const MenuSheetBody(
                lead: <Widget>[
                  SoftRow(
                    key: ValueKey<String>('floor-destination-work'),
                    density: SoftRowDensity.compact,
                    title: 'Work',
                    subtitle: '3 things need a decision',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Visible without being asked for — it is The Floor's two live slots and
      // it is the one block in here that is never folded.
      expect(key('floor-destination-work'), findsOneWidget);
      expect(find.text('3 things need a decision'), findsOneWidget);

      // Above the first group row, not inside it.
      expect(
        tester.getTopLeft(key('floor-destination-work')).dy,
        lessThan(tester.getTopLeft(key('menu-fold-operate')).dy),
      );
      // And the groups are still shut under it.
      expect(key('menu-/tasks'), findsNothing);
    });
  });
}
