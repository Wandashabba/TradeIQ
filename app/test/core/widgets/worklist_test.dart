import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_colors.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/agent_motion.dart' show Motion;
import 'package:tradeiq_app/core/widgets/console.dart';
import 'package:tradeiq_app/core/widgets/worklist.dart';

import '../theme/tiq_colors_test.dart' show contrastRatio;

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

/// Pumps [child] under a real app theme (light unless [theme] is given),
/// optionally with the OS reduce-motion flag on.
Widget _themed(Widget child, {ThemeData? theme, bool reduceMotion = false}) =>
    MaterialApp(
      theme: theme ?? AppTheme.light(),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: Scaffold(body: ListView(children: [child])),
        ),
      ),
    );

WorklistRow _row({
  String title = 'Price deviation',
  StatusLevel level = StatusLevel.critical,
  String? statusLabel = 'Open',
  bool resolved = false,
  VoidCallback? onTap,
  List<Widget> actions = const [],
  Widget? thumb,
}) => WorklistRow(
  title: title,
  meta: const Text('Outlet 7 · rule fired'),
  level: level,
  statusLabel: statusLabel,
  when: '2h ago',
  resolved: resolved,
  onTap: onTap,
  actions: actions,
  thumb: thumb,
);

/// The row's card ground: the DecoratedBox carrying the panel-radius
/// BoxDecoration. Fails loudly when the row has no card decoration at all.
Finder _cardBox({int index = 0}) => find.descendant(
  of: find.byType(WorklistRow).at(index),
  matching: find.byWidgetPredicate(
    (w) =>
        w is DecoratedBox &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).borderRadius ==
            BorderRadius.circular(AppColors.radiusPanel),
  ),
);

BoxDecoration _cardDecoration(WidgetTester tester, {int index = 0}) {
  final box = tester.widget<DecoratedBox>(_cardBox(index: index).first);
  return box.decoration as BoxDecoration;
}

/// Any rendered surface inside the row currently painted [color] — how the
/// hover/press wash is observed without keying the implementation.
Finder _washedSurface(Color color) => find.descendant(
  of: find.byType(WorklistRow),
  matching: find.byWidgetPredicate(
    (w) =>
        (w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == color) ||
        (w is ColoredBox && w.color == color),
  ),
);

/// A realistic offline failure: the DioException whose toString is the
/// multi-line dump — SocketException, hostname and all — that used to reach
/// every console screen through AsyncSection's `$err` interpolation.
DioException _offline() => DioException(
  requestOptions: RequestOptions(path: '/alerts'),
  type: DioExceptionType.connectionError,
  error: 'SocketException: Failed host lookup: api.tradeiq.internal',
);

void main() {
  group('AsyncSection', () {
    testWidgets('an error renders human copy, never the raw exception', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AsyncSection<List<int>>(
            value: AsyncValue.error(_offline(), StackTrace.current),
            label: 'alerts',
            onRetry: () {},
            builder: (_) => const SizedBox.shrink(),
          ),
        ),
      );

      // The prefix the ~20 screen tests key on, followed by the shared
      // helper's copy — one sentence an agent can act on.
      expect(
        find.text(
          'Failed to load alerts. Could not reach the server. '
          'Check your connection and try again.',
        ),
        findsOneWidget,
      );
      // And none of the dump. Offline is the expected state in this app, not
      // an incident to report in stack-trace form.
      expect(find.textContaining('DioException'), findsNothing);
      expect(find.textContaining('SocketException'), findsNothing);
      expect(find.textContaining('api.tradeiq.internal'), findsNothing);
    });

    testWidgets('the error state always offers a retry', (tester) async {
      // A dead-end error state is a bug: the whole point of naming the
      // failure is to offer the way back.
      var retried = false;
      await tester.pumpWidget(
        _wrap(
          AsyncSection<List<int>>(
            value: AsyncValue.error(_offline(), StackTrace.current),
            label: 'alerts',
            onRetry: () => retried = true,
            builder: (_) => const SizedBox.shrink(),
          ),
        ),
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Retry'));
      expect(retried, isTrue);
    });

    testWidgets('data still flows through to the builder', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AsyncSection<String>(
            value: const AsyncValue.data('loaded'),
            label: 'alerts',
            onRetry: () {},
            builder: (data) => Text(data),
          ),
        ),
      );

      expect(find.text('loaded'), findsOneWidget);
      expect(find.textContaining('Failed to load'), findsNothing);
    });
  });

  group('WorklistRow card', () {
    testWidgets(
      'renders as a card: surface1 ground, line hairline, panel radius — '
      'and NO shadow of its own',
      (tester) async {
        await tester.pumpWidget(_themed(_row()));

        final deco = _cardDecoration(tester);
        expect(deco.color, TiqColors.light.surface1);
        expect(deco.border, Border.all(color: TiqColors.light.line));
        expect(deco.borderRadius, BorderRadius.circular(AppColors.radiusPanel));
        // Deliberate deviation from the naive "Stripe shadow on every card":
        // every consumer renders these rows INSIDE a PanelCard, which already
        // carries the one static Stripe shadow. A second shadow per row would
        // stack shadow-in-shadow, so the row card is the flat-in-panel variant.
        expect(deco.boxShadow, isNull);
      },
    );

    testWidgets('severity edge bar is clipped inside the card radius', (
      tester,
    ) async {
      await tester.pumpWidget(_themed(_row(level: StatusLevel.critical)));

      // The 3px edge bar carries the level colour…
      final edge = find.descendant(
        of: find.byType(WorklistRow),
        matching: find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == TiqColors.light.crit,
        ),
      );
      expect(edge, findsOneWidget);

      // …and sits under a rounded clip, so the square bar can never poke out
      // of the card's rounded corners.
      final clip = find.ancestor(
        of: edge,
        matching: find.byWidgetPredicate(
          (w) => w is ClipRRect && w.borderRadius != BorderRadius.zero,
        ),
      );
      expect(clip, findsWidgets);
      // The clip itself lives inside the card decoration.
      expect(
        find.ancestor(of: clip.first, matching: _cardBox()),
        findsOneWidget,
      );
    });

    testWidgets('adjacent cards sit with an 8px gap', (tester) async {
      await tester.pumpWidget(
        _themed(
          Column(
            children: [
              _row(),
              _row(title: 'Second'),
            ],
          ),
        ),
      );

      final first = tester.getRect(_cardBox(index: 0).first);
      final second = tester.getRect(_cardBox(index: 1).first);
      expect(second.top - first.bottom, 8);
    });

    testWidgets('hover washes surface2, press washes surface3 — inside the '
        'card clip', (tester) async {
      await tester.pumpWidget(_themed(_row(onTap: () {})));

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();

      await gesture.moveTo(tester.getCenter(find.byType(WorklistRow)));
      await tester.pumpAndSettle();
      final hoverWash = _washedSurface(TiqColors.light.surface2);
      expect(hoverWash, findsWidgets);
      // The wash paints inside the rounded clip: feedback cannot leak past
      // the card's corners.
      expect(
        find.ancestor(
          of: hoverWash.first,
          matching: find.byWidgetPredicate(
            (w) => w is ClipRRect && w.borderRadius != BorderRadius.zero,
          ),
        ),
        findsWidgets,
      );
      await gesture.moveTo(Offset.zero);
      await tester.pumpAndSettle();

      final press = await tester.startGesture(
        tester.getCenter(find.byType(WorklistRow)),
      );
      // Two pumps: the scrollable's tap-deferral, then the 150ms wash.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      expect(_washedSurface(TiqColors.light.surface3), findsWidgets);
      await press.up();
      await tester.pumpAndSettle();
    });

    testWidgets('resolved dims the row, greys the edge, hollows the chip', (
      tester,
    ) async {
      await tester.pumpWidget(_themed(_row(resolved: true)));

      final dim = tester.widget<Opacity>(
        find.ancestor(of: _cardBox(), matching: find.byType(Opacity)).first,
      );
      expect(dim.opacity, 0.6);

      expect(
        find.descendant(
          of: find.byType(WorklistRow),
          matching: find.byWidgetPredicate(
            (w) => w is ColoredBox && w.color == TiqColors.light.lineStrong,
          ),
        ),
        findsOneWidget,
      );

      final chip = tester.widget<StatusChip>(find.byType(StatusChip));
      expect(chip.level, StatusLevel.neutral);
    });

    testWidgets('onTap and actions still fire', (tester) async {
      var tapped = false;
      var acted = false;
      await tester.pumpWidget(
        _themed(
          _row(
            onTap: () => tapped = true,
            actions: [
              RowAction(label: 'Assign', onPressed: () => acted = true),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Price deviation'));
      expect(tapped, isTrue);
      await tester.tap(find.text('Assign'));
      expect(acted, isTrue);
    });

    testWidgets('thumb renders leading at 44×44 under a rounded-8 clip', (
      tester,
    ) async {
      await tester.pumpWidget(
        _themed(_row(thumb: const ColoredBox(color: Colors.teal))),
      );

      final clipFinder = find.byKey(const ValueKey('worklist-thumb'));
      expect(clipFinder, findsOneWidget);
      final clip = tester.widget<ClipRRect>(clipFinder);
      expect(clip.borderRadius, BorderRadius.circular(8));
      expect(tester.getSize(clipFinder), const Size(44, 44));
      // It leads the content: left of the title.
      expect(
        tester.getCenter(clipFinder).dx <
            tester.getCenter(find.text('Price deviation')).dx,
        isTrue,
      );
    });

    testWidgets('no thumb, no extra chrome', (tester) async {
      await tester.pumpWidget(_themed(_row()));
      expect(find.byKey(const ValueKey('worklist-thumb')), findsNothing);
    });

    testWidgets('dark theme: card wears dark tokens, text clears 4.5:1 on the '
        'card ground', (tester) async {
      await tester.pumpWidget(_themed(_row(), theme: AppTheme.dark()));

      final deco = _cardDecoration(tester);
      expect(deco.color, TiqColors.dark.surface1);
      expect(deco.border, Border.all(color: TiqColors.dark.line));
      final ground = deco.color!;

      final title = tester
          .widget<Text>(find.text('Price deviation'))
          .style!
          .color!;
      expect(contrastRatio(title, ground), greaterThanOrEqualTo(4.5));

      final metaElement = tester.element(find.text('Outlet 7 · rule fired'));
      final meta = DefaultTextStyle.of(metaElement).style.color!;
      expect(contrastRatio(meta, ground), greaterThanOrEqualTo(4.5));
    });
  });

  group('WorklistCascade', () {
    testWidgets('staggers each row by Motion.stagger * index', (tester) async {
      await tester.pumpWidget(
        _themed(
          Column(
            children: [
              for (var i = 0; i < 3; i++)
                WorklistCascade(index: i, child: Text('row $i')),
            ],
          ),
        ),
      );

      final entrances = tester
          .widgetList<OneShotEntrance>(find.byType(OneShotEntrance))
          .toList();
      expect(entrances, hasLength(3));
      for (var i = 0; i < 3; i++) {
        expect(entrances[i].delay, Motion.stagger * i);
      }

      // Behavioural: rows are invisible on the very first frame, visible once
      // the cascade has run out.
      expect(
        tester
            .widgetList<Opacity>(find.byType(Opacity))
            .where((o) => o.opacity < 1),
        hasLength(3),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<Opacity>(find.byType(Opacity))
            .where((o) => o.opacity < 1),
        isEmpty,
      );
    });

    testWidgets('caps the cascade at 12 rows — row 13+ is instant', (
      tester,
    ) async {
      await tester.pumpWidget(
        _themed(
          Column(
            children: [
              for (var i = 0; i < 14; i++)
                WorklistCascade(index: i, child: Text('row $i')),
            ],
          ),
        ),
      );

      // Only the first 12 animate at all…
      expect(find.byType(OneShotEntrance), findsNWidgets(12));
      // …and rows 12/13 are fully visible on the FIRST frame.
      for (final i in [12, 13]) {
        expect(
          find.ancestor(
            of: find.text('row $i'),
            matching: find.byType(OneShotEntrance),
          ),
          findsNothing,
        );
      }
      await tester.pumpAndSettle();
    });

    testWidgets('does not replay when the list rebuilds', (tester) async {
      late StateSetter rebuild;
      await tester.pumpWidget(
        _themed(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return Column(
                children: [
                  for (var i = 0; i < 3; i++)
                    WorklistCascade(index: i, child: Text('row $i')),
                ],
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      rebuild(() {});
      await tester.pump();
      // One frame after the rebuild every row is still at full opacity — the
      // entrance is one-shot, not a loop keyed to builds.
      expect(
        tester
            .widgetList<Opacity>(find.byType(Opacity))
            .where((o) => o.opacity < 1),
        isEmpty,
      );
    });

    testWidgets('reduce motion: rows are static on the first frame', (
      tester,
    ) async {
      await tester.pumpWidget(
        _themed(
          Column(
            children: [
              for (var i = 0; i < 3; i++)
                WorklistCascade(index: i, child: Text('row $i')),
            ],
          ),
          reduceMotion: true,
        ),
      );

      // First frame, no pumps: everything already visible, nothing animating.
      for (var i = 0; i < 3; i++) {
        expect(find.text('row $i'), findsOneWidget);
      }
      expect(
        tester
            .widgetList<Opacity>(find.byType(Opacity))
            .where((o) => o.opacity < 1),
        isEmpty,
      );
      // And nothing pending for pumpAndSettle to chew on.
      await tester.pumpAndSettle();
    });

    testWidgets('enabled:false renders the row bare and instantly', (
      tester,
    ) async {
      await tester.pumpWidget(
        _themed(
          WorklistCascade(index: 0, enabled: false, child: const Text('row')),
        ),
      );
      expect(find.text('row'), findsOneWidget);
      expect(
        tester
            .widgetList<Opacity>(find.byType(Opacity))
            .where((o) => o.opacity < 1),
        isEmpty,
      );
    });

    testWidgets('composes with WorklistRow in a rebuilding list', (
      tester,
    ) async {
      late StateSetter rebuild;
      await tester.pumpWidget(
        _themed(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return Column(
                children: [
                  for (var i = 0; i < 2; i++)
                    WorklistCascade(
                      index: i,
                      child: _row(title: 'Task $i'),
                    ),
                ],
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Task 0'), findsOneWidget);

      rebuild(() {});
      await tester.pump();
      expect(
        tester
            .widgetList<Opacity>(find.byType(Opacity))
            .where((o) => o.opacity < 1),
        isEmpty,
      );
    });
  });
}
