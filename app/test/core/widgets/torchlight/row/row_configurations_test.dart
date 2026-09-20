import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/tiq_number.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';

import 'row_harness.dart';

/// The four configurations, one test per state.
///
/// Each of these asserts the same two things in a different vocabulary: that
/// the state is legible **without colour** — a silhouette, a word, or both —
/// and that the row is still a [SoftRow] underneath rather than a second
/// implementation of one.
void main() {
  group('OutboxRow (#382)', () {
    Widget row(OutboxState state, {int? bytes = 1468006}) => OutboxRow(
      state: state,
      title: 'Shelf photo · Kasi Corner Spaza',
      stateWord: _word(state),
      sentence: _sentence(state),
      ageLine: 'queued 14:03',
      payloadBytes: bytes,
      stuckLabel: 'Needs you',
      onTap: () {},
    );

    testWidgets('every state has its own silhouette', (tester) async {
      final marks = <RowMark>{};
      for (final state in OutboxState.values) {
        await pumpRow(tester, skin: TiqSkin.night(), child: row(state));
        marks.add(tester.widget<RowMarkTile>(find.byType(RowMarkTile)).mark);
      }
      expect(
        marks.length,
        OutboxState.values.length,
        reason:
            'Two states sharing a silhouette leaves colour as the only '
            'difference between them, which is the one thing the system does '
            'not allow.',
      );
    });

    testWidgets('every state has its own word, and the word leads the '
        'announcement', (tester) async {
      final handle = tester.ensureSemantics();
      for (final state in OutboxState.values) {
        await pumpRow(tester, skin: TiqSkin.night(), child: row(state));
        final label = tester.getSemantics(find.byType(SoftRow)).label;
        expect(
          label,
          startsWith(state == OutboxState.stuck ? 'Needs you' : _word(state)),
          reason: '${state.name}: the state has to be said first.',
        );
        expect(label, contains('1.4 MB'));
      }
      handle.dispose();
    });

    testWidgets('sending is Oatmeal dots and never an amber pulse', (
      tester,
    ) async {
      final skin = TiqSkin.night();
      await pumpRow(tester, skin: skin, child: row(OutboxState.sending));
      expect(
        tester.widget<RowMarkTile>(find.byType(RowMarkTile)).mark,
        RowMark.dots,
      );
      expect(
        tester.widget<RowMarkTile>(find.byType(RowMarkTile)).tone.inkOf(skin),
        skin.palette.ink2,
        reason:
            'unify §1.1: a pulse means presence. An upload is progress, and '
            'progress is a report.',
      );
      // Leave the repeating controller running long enough to prove it does
      // not settle, then let the tester dispose it.
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    });

    testWidgets('under reduce-motion the dots stop and the words carry it', (
      tester,
    ) async {
      await pumpRow(
        tester,
        skin: TiqSkin.night(),
        still: true,
        child: row(OutboxState.sending),
      );
      // No boundary, because nothing repaints: the still path is a resting
      // frame, not a paused animation. `pumpAndSettle` returning at all is the
      // proof that no ticker was started.
      expect(find.byType(RepaintBoundary), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('Sending now'), findsOneWidget);
      expect(find.text('Sending'), findsOneWidget);
    });

    testWidgets('only stuck carries a severity bar', (tester) async {
      for (final state in OutboxState.values) {
        await pumpRow(tester, skin: TiqSkin.night(), child: row(state));
        expect(
          tester.widget<SoftRow>(find.byType(SoftRow)).severity,
          state == OutboxState.stuck
              ? SoftRowSeverity.critical
              : SoftRowSeverity.none,
        );
      }
    });

    testWidgets('waiting-for-its-visit is not tappable, because tapping it '
        'can do nothing', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpRow(
        tester,
        skin: TiqSkin.night(),
        child: row(OutboxState.waitingForVisit),
      );
      expect(isButtonNode(tester.getSemantics(find.byType(SoftRow))), isFalse);
      handle.dispose();
    });

    testWidgets('an unknown size renders nothing rather than a zero', (
      tester,
    ) async {
      await pumpRow(
        tester,
        skin: TiqSkin.night(),
        child: row(OutboxState.queued, bytes: null),
      );
      expect(find.textContaining('MB'), findsNothing);
      expect(find.textContaining('kB'), findsNothing);
      expect(find.text('queued 14:03'), findsOneWidget);
    });

    test('the decoded size is reported in the unit a decision is made in', () {
      expect(PayloadSize.of(1468006).unit, 'MB');
      expect(PayloadSize.of(1468006).value, closeTo(1.4, 0.05));
      expect(PayloadSize.of(400).unit, 'kB');
      expect(
        PayloadSize.of(400).value,
        1,
        reason:
            'nobody decides anything on 400 bytes, and "0,0 MB" beside a '
            'photo reads as a bug',
      );
      expect(PayloadSize.of(-1).value, 0);
    });

    testWidgets('a 40-character Afrikaans title and state word do not '
        'overflow at 2.0×', (tester) async {
      for (final name in rowSkinMatrix.map((e) => e.$1)) {
        await pumpRow(
          tester,
          skin: skinFor(name),
          textScale: 2.0,
          child: OutboxRow(
            state: OutboxState.retrying,
            title: afrikaansLabel,
            stateWord: 'Probeer weer',
            sentence: 'Probeer weer om 14:20',
            ageLine: 'in die ry gesit 14:03',
            payloadBytes: 1468006,
            onTap: () {},
          ),
        );
        expect(tester.takeException(), isNull, reason: name);
      }
    });
  });

  group('HeldWorkRow (#391)', () {
    testWidgets('held is Truffle, and Truffle is never a severity', (
      tester,
    ) async {
      final skin = TiqSkin.night();
      await pumpRow(
        tester,
        skin: skin,
        child: HeldWorkRow(
          state: HeldWorkState.held,
          title: '4 visits held on this phone',
          stateWord: 'Held',
          meta: 'oldest 2 h 14 m · last sent 11:48',
          onTap: () {},
        ),
      );
      final tile = tester.widget<RowMarkTile>(find.byType(RowMarkTile));
      expect(tile.mark, RowMark.square);
      expect(tile.tone.inkOf(skin), skin.palette.comparison);
      expect(
        tester.widget<SoftRow>(find.byType(SoftRow)).severity,
        SoftRowSeverity.none,
        reason:
            'Load-shedding is not a fault. An amber — or crimson — queue chip '
            'here is the single most important non-amber decision in the '
            'system.',
      );
    });

    testWidgets('stuck is watch, not critical: the work is late, not lost', (
      tester,
    ) async {
      await pumpRow(
        tester,
        skin: TiqSkin.night(),
        child: HeldWorkRow(
          state: HeldWorkState.stuck,
          title: '4 visits held since yesterday 09:12',
          stateWord: 'Stuck',
          stuckLabel: 'Watch',
          onTap: () {},
        ),
      );
      expect(
        tester.widget<SoftRow>(find.byType(SoftRow)).severity,
        SoftRowSeverity.watch,
      );
    });

    testWidgets('unknown is not tappable and says why', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpRow(
        tester,
        skin: TiqSkin.night(),
        child: HeldWorkRow(
          state: HeldWorkState.unknown,
          title: 'Held work unknown',
          stateWord: "This agent's app is on an older version",
          onTap: () {},
        ),
      );
      expect(isButtonNode(tester.getSemantics(find.byType(SoftRow))), isFalse);
      expect(
        find.text("This agent's app is on an older version"),
        findsOneWidget,
        reason: 'a dead row with no explanation is a phone call to a manager',
      );
      handle.dispose();
    });

    testWidgets('it is the console density', (tester) async {
      await pumpRow(
        tester,
        skin: TiqSkin.night(density: TiqDensity.console),
        child: HeldWorkRow(
          state: HeldWorkState.held,
          title: '4 visits held on this phone',
          stateWord: 'Held',
          onTap: () {},
        ),
      );
      expect(
        tester.widget<SoftRow>(find.byType(SoftRow)).density,
        SoftRowDensity.compact,
      );
    });
  });

  group('DecisionRow', () {
    testWidgets('severity, title, reason, figure — in that order, in words', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpRow(
        tester,
        skin: TiqSkin.night(density: TiqDensity.console),
        child: DecisionRow(
          title: 'Shoprite Klipspruit Mall',
          reason: 'Availability fell 14 points in three visits',
          severity: SoftRowSeverity.critical,
          severityLabel: 'Critical',
          value: 71,
          unit: TiqUnit.percent,
          onTap: () {},
        ),
      );
      expect(
        tester.getSemantics(find.byType(SoftRow)).label,
        'Critical. Shoprite Klipspruit Mall. Availability fell 14 points in '
        'three visits',
      );
      handle.dispose();
    });

    testWidgets('the outlet name middle-truncates', (tester) async {
      await pumpRow(
        tester,
        skin: TiqSkin.night(),
        rowWidth: 200,
        child: DecisionRow(
          title: 'Shoprite Klipspruit Mall',
          reason: 'Availability fell',
          value: 71,
          onTap: () {},
        ),
      );
      expect(
        tester.widget<SoftRow>(find.byType(SoftRow)).titleTruncation,
        SoftRowTruncation.middle,
      );
    });

    testWidgets('no figure renders an em dash, not a blank', (tester) async {
      await pumpRow(
        tester,
        skin: TiqSkin.night(),
        child: DecisionRow(
          title: 'Shoprite Klipspruit Mall',
          reason: 'Never scored',
          figureState: FigureState.missing,
          valueSemanticsLabel: 'No visits in this window',
          onTap: () {},
        ),
      );
      expect(find.textContaining('—'), findsWidgets);
    });

    testWidgets('no sparkline omits the slot rather than inventing a shape', (
      tester,
    ) async {
      await pumpRow(
        tester,
        skin: TiqSkin.night(),
        child: DecisionRow(
          title: 'Shoprite Klipspruit Mall',
          reason: 'Availability fell',
          value: 71,
          onTap: () {},
        ),
      );
      expect(find.byKey(const ValueKey<String>('sparkline')), findsNothing);
    });

    testWidgets('the sparkline drops first at 2.0×, then in Veld', (
      tester,
    ) async {
      const sparkline = SizedBox(key: ValueKey<String>('sparkline'));
      Widget row() => const DecisionRow(
        title: 'Shoprite Klipspruit Mall',
        reason: 'Availability fell',
        value: 71,
        sparkline: sparkline,
      );

      await pumpRow(tester, skin: TiqSkin.night(), child: row());
      expect(find.byKey(const ValueKey<String>('sparkline')), findsOneWidget);

      await pumpRow(
        tester,
        skin: TiqSkin.night(),
        textScale: 2.0,
        child: row(),
      );
      expect(find.byKey(const ValueKey<String>('sparkline')), findsNothing);

      await pumpRow(tester, skin: TiqSkin.veld(), child: row());
      expect(
        find.byKey(const ValueKey<String>('sparkline')),
        findsNothing,
        reason: 'a 64x20 grey zigzag is under 9:1 by construction',
      );
    });
  });

  group('PersonRow (#399/#400)', () {
    testWidgets('name, role, outlet — one sentence, no id', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpRow(
        tester,
        skin: TiqSkin.night(),
        child: PersonRow(
          name: 'Thandi Mokoena',
          role: 'Field agent',
          outlet: 'Kasi Corner Spaza',
          identifier: 'a4f2c118-9e1d-4b77-8f30-2c19bb0e7a51',
          identifierLabel: 'Reference',
          onTap: () {},
        ),
      );
      expect(
        tester.getSemantics(find.byType(SoftRow)).label,
        'Thandi Mokoena, Field agent, Kasi Corner Spaza',
      );
      expect(
        find.textContaining('a4f2c118'),
        findsNothing,
        reason: 'an id is never rendered beside a name',
      );
      handle.dispose();
    });

    testWidgets('no photograph — initials on the well, and a barred ring when '
        'even those are unknown', (tester) async {
      await pumpRow(
        tester,
        skin: TiqSkin.night(),
        child: const PersonRow(name: 'Thandi Mokoena', role: 'Field agent'),
      );
      expect(find.text('TM'), findsOneWidget);
      expect(find.byType(Image), findsNothing);

      await pumpRow(
        tester,
        skin: TiqSkin.night(),
        child: const PersonRow(role: 'Field agent', outlet: 'Kasi Corner'),
      );
      expect(
        tester.widget<RowMarkTile>(find.byType(RowMarkTile)).mark,
        RowMark.barredRing,
      );
    });

    testWidgets(
      'with no name the role leads and the id drops to a third line',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpRow(
          tester,
          skin: TiqSkin.night(),
          child: const PersonRow(
            unknownLabel: 'Unknown agent',
            identifier: 'a4f2c118',
            identifierLabel: 'Reference',
          ),
        );
        expect(find.text('Unknown agent'), findsOneWidget);
        expect(find.text('a4f2c118'), findsOneWidget);
        expect(
          tester.getSemantics(find.byType(SoftRow)).label,
          'Unknown agent, Reference a 4 f 2 c 1 1 8',
          reason:
              'a reference is repeated down a phone line, character by '
              'character',
        );
        handle.dispose();
      },
    );

    testWidgets('a deactivated person is ink-mute, chevron-less and not '
        'tappable', (tester) async {
      final handle = tester.ensureSemantics();
      final skin = TiqSkin.night();
      await pumpRow(
        tester,
        skin: skin,
        child: PersonRow(
          name: 'Thandi Mokoena',
          role: 'Field agent',
          trailingWord: 'No longer active',
          deactivated: true,
          onTap: () {},
        ),
      );
      expect(find.byType(SoftRowChevron), findsNothing);
      expect(isButtonNode(tester.getSemantics(find.byType(SoftRow))), isFalse);
      expect(
        tester.widget<Text>(find.text('Thandi Mokoena')).style!.color,
        skin.palette.inkMute,
      );
      handle.dispose();
    });

    testWidgets('a long name wraps and keeps its discriminating half', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      for (final name in <String>[longName, similarName]) {
        await pumpRow(
          tester,
          skin: TiqSkin.night(),
          rowWidth: 200,
          textScale: 2.0,
          child: PersonRow(
            name: name,
            role: 'Field agent',
            outlet: 'Kasi Corner Spaza',
            onTap: () {},
          ),
        );
        expect(tester.takeException(), isNull);
        expect(
          tester.getSemantics(find.byType(SoftRow)).label,
          startsWith(name),
          reason: 'whatever is painted, the full name is what is announced',
        );
      }
      handle.dispose();
    });

    test('a row with nothing at all is a build-time error', () {
      // `const PersonRow()` does not even compile — the assert fires during
      // constant evaluation — which is the strongest version of this rule
      // available. The runtime form is here for the non-const call sites.
      String? nothing;
      expect(
        () => PersonRow(
          name: nothing,
          role: nothing,
          outlet: nothing,
          unknownLabel: nothing,
        ),
        throwsAssertionError,
      );
    });

    testWidgets('long-press is the one legitimate way to reach the id', (
      tester,
    ) async {
      var copies = 0;
      await pumpRow(
        tester,
        skin: TiqSkin.night(),
        child: PersonRow(
          name: 'Thandi Mokoena',
          role: 'Field agent',
          onTap: () {},
          onLongPress: () => copies++,
        ),
      );
      await tester.longPress(find.byType(SoftRow));
      await tester.pump();
      expect(copies, 1);
    });
  });
}

String _word(OutboxState state) => switch (state) {
  OutboxState.queued => 'Waiting',
  OutboxState.sending => 'Sending',
  OutboxState.retrying => 'Retrying',
  OutboxState.sent => 'Sent',
  OutboxState.stuck => 'Needs you',
  OutboxState.waitingForVisit => 'Waiting its turn',
};

String _sentence(OutboxState state) => switch (state) {
  OutboxState.queued => 'Waiting for signal',
  OutboxState.sending => 'Sending now',
  OutboxState.retrying => 'Retrying at 14:20',
  OutboxState.sent => 'Sent 08:04',
  OutboxState.stuck => 'The server said no (422)',
  OutboxState.waitingForVisit => 'Waits for the visit above it',
};

/// `SemanticsNode.hasFlag` is deprecated; the button flag now lives on the
/// node's flag collection.
bool isButtonNode(SemanticsNode node) => node.flagsCollection.isButton;
