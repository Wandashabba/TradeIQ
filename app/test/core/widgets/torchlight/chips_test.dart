import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';

import 'mark_harness.dart';

void main() {
  group('Status chip — hue plus silhouette plus word in one token', () {
    test('five levels, five words, four distinct severity silhouettes', () {
      final skin = TiqSkin.night();
      final words = <String>{};
      final shapes = <MarkShape>{};
      for (final level in StatusLevel.values) {
        final token = StatusLevelToken.of(skin, level);
        words.add(token.word);
        shapes.add(token.shape);
      }
      expect(words, hasLength(5));
      expect(shapes, hasLength(5));
    });

    test('there is no unknown level', () {
      // A grey "Unknown" chip is a claim that the system looked. Where a level
      // has not been computed, no chip renders and an em dash carries the
      // figure with "not scored" beside it.
      expect(StatusLevel.values.map((l) => l.name), isNot(contains('unknown')));
      expect(StatusLevel.values, hasLength(5));
    });

    test(
      'severity is one hue at two commitment levels: outline, then solid',
      () {
        final skin = TiqSkin.night();
        final critical = StatusLevelToken.of(skin, StatusLevel.critical);
        final watch = StatusLevelToken.of(skin, StatusLevel.watch);
        expect(
          critical.fill,
          skin.palette.badSolid,
          reason: 'Solid = Critical.',
        );
        expect(watch.fill, isNull, reason: 'Outline = Watch.');
        expect(watch.border, skin.palette.bad);
        expect(
          critical.shape,
          isNot(watch.shape),
          reason: 'Each commitment level has its own silhouette as well.',
        );
      },
    );

    test('Held is Oatmeal on the well, never Truffle', () {
      final skin = TiqSkin.night();
      final held = StatusLevelToken.of(skin, StatusLevel.held);
      expect(held.ink, skin.palette.ink2);
      expect(
        held.ink,
        isNot(skin.palette.comparison),
        reason:
            'Truffle is the comparison series — them, unlit — and nothing '
            'else. Giving it a second meaning is exactly the failure the '
            'severity system avoids.',
      );
      expect(held.shape, MarkShape.heldSquare);
    });

    testWidgets('staleness is a word, not a fade', (tester) async {
      await tester.pumpWidget(
        skinned(
          TiqSkin.night(),
          const StatusChip(level: StatusLevel.watch, detail: 'as at 08:15'),
        ),
      );
      expect(find.text('Watch · as at 08:15'), findsOneWidget);
      // Nothing in the chip is rendered through an Opacity: a 0.6 Watch chip
      // computes to 3.29:1 for 11px text, and a contrast walk cannot see it.
      expect(find.byType(Opacity), findsNothing);
    });

    testWidgets('a chip that does nothing is not a button', (tester) async {
      await tester.pumpWidget(
        skinned(TiqSkin.night(), const StatusChip(level: StatusLevel.held)),
      );
      final semantics = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byType(StatusChip),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(
        semantics.properties.button,
        isFalse,
        reason:
            'A chip that does nothing takes no press feedback and announces '
            'no affordance, so it cannot be mistaken for a control.',
      );
      expect(find.byType(GestureDetector), findsNothing);
    });

    testWidgets('every level renders in every skin without clipping at 2.0x', (
      tester,
    ) async {
      for (final skin in allSkins) {
        for (final level in StatusLevel.values) {
          await tester.pumpWidget(
            skinned(
              skin,
              SizedBox(width: 200, child: StatusChip(level: level)),
              textScale: 2.0,
            ),
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '${skin.mode.name}/$level',
          );
        }
      }
    });
  });

  group('Flag chip — six neutral members and exactly one severity', () {
    test('only Sent back carries severity', () {
      final skin = TiqSkin.night();
      final severities = FlagKind.values
          .where((k) => FlagKindToken.of(skin, k).isSeverity)
          .toList();
      expect(
        severities,
        <FlagKind>[FlagKind.sentBack],
        reason:
            'Out of fence is a measurement, unfinished is an arithmetic, no '
            'GPS is a fact about a radio. Only a human rejecting the work is '
            'a verdict.',
      );
    });

    test('the six neutral members are never crimson', () {
      final skin = TiqSkin.night();
      for (final kind in FlagKind.values) {
        if (kind == FlagKind.sentBack) continue;
        final token = FlagKindToken.of(skin, kind);
        expect(
          token.ink,
          isNot(anyOf(skin.palette.bad, skin.palette.badSolid)),
          reason: '${kind.name} is a fact, not a verdict.',
        );
        expect(
          token.border,
          isNot(anyOf(skin.palette.bad, skin.palette.badSolid)),
          reason: '${kind.name} is a fact, not a verdict.',
        );
      }
    });

    test('seven members, seven silhouettes, seven words', () {
      final skin = TiqSkin.night();
      final shapes = <MarkShape>{};
      final words = <String>{};
      for (final kind in FlagKind.values) {
        final token = FlagKindToken.of(skin, kind);
        shapes.add(token.shape);
        words.add(token.word);
      }
      expect(shapes, hasLength(FlagKind.values.length));
      expect(words, hasLength(FlagKind.values.length));
    });

    testWidgets('the neutral six are legible in greyscale by construction', (
      tester,
    ) async {
      // No colour difference between them at all, so the members have to be
      // carried by shape. Render each and prove no two frames are the same
      // grey.
      final skin = TiqSkin.night();
      final frames = <FlagKind, Uint8List>{};
      for (final kind in FlagKind.values) {
        if (kind == FlagKind.sentBack) continue;
        frames[kind] = await paintMark(
          tester,
          skin: skin,
          child: TiqMark(
            shape: FlagKindToken.of(skin, kind).shape,
            color: skin.palette.ink2,
            size: 28,
          ),
          size: const Size(40, 40),
        );
      }
      final kinds = frames.keys.toList();
      for (var i = 0; i < kinds.length; i++) {
        for (var j = i + 1; j < kinds.length; j++) {
          final d = greyscaleDifference(frames[kinds[i]]!, frames[kinds[j]]!);
          expect(
            d,
            greaterThan(0.005),
            reason:
                '${kinds[i].name} and ${kinds[j].name} are the same grey '
                'frame (${(d * 100).toStringAsFixed(2)}% differing). The '
                'family has one treatment and six meanings; the meanings are '
                'the silhouettes.',
          );
        }
      }
    });

    testWidgets('the detail sets in the same run as the word', (tester) async {
      await tester.pumpWidget(
        skinned(
          TiqSkin.night(),
          const FlagChip(kind: FlagKind.outOfFence, detail: '140 m'),
        ),
      );
      expect(find.text('Out of fence · 140 m'), findsOneWidget);
    });

    testWidgets('a cleared flag steps to a declared token and says so', (
      tester,
    ) async {
      await tester.pumpWidget(
        skinned(
          TiqSkin.night(),
          const FlagChip(kind: FlagKind.outOfFence, cleared: true),
        ),
      );
      expect(find.text('Out of fence · Cleared'), findsOneWidget);
      expect(find.byType(Opacity), findsNothing);
      final label = tester.widget<Text>(
        find.descendant(of: find.byType(FlagChip), matching: find.byType(Text)),
      );
      expect(label.style?.color, TiqSkin.night().palette.ink3);
      expect(
        label.style?.decoration,
        isNot(TextDecoration.lineThrough),
        reason:
            'A 1.5px strike at 40% backlight vanishes, and a struck label '
            'reads as an error the agent made.',
      );
    });

    testWidgets('a tappable chip is a button at the full tap target', (
      tester,
    ) async {
      await tester.pumpWidget(
        skinned(
          TiqSkin.night(),
          FlagChip(kind: FlagKind.forReview, onTap: () {}),
        ),
      );
      final semantics = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byType(FlagChip),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(
        semantics.properties.button,
        isTrue,
        reason:
            'A flag the agent cannot interrogate is an accusation. Every one '
            'of them opens its own explanation.',
      );
      expect(
        tester.getSize(find.byType(FlagChip)).height,
        greaterThanOrEqualTo(TiqSkin.night().space.tapTarget),
        reason: 'A 28dp chip centred in a 44dp hit box.',
      );
    });
  });

  group('Severity mark set', () {
    test('five marks, five silhouettes, five words', () {
      final skin = TiqSkin.night();
      final shapes = <MarkShape>{};
      final words = <String>{};
      for (final kind in SeverityMarkKind.values) {
        final token = SeverityMarkToken.of(skin, kind);
        shapes.add(token.shape);
        words.add(token.word);
      }
      expect(shapes, hasLength(5));
      expect(words, hasLength(5));
    });

    test('not-measured is a barred square, never a hatched one', () {
      final skin = TiqSkin.night();
      expect(
        SeverityMarkToken.of(skin, SeverityMarkKind.notMeasured).shape,
        MarkShape.notMeasuredBarredSquare,
        reason:
            'No pattern inside a glyph. A 12dp square of stripes at any '
            'period a phone can draw averages to the flat block the hatch '
            'exists not to be.',
      );
    });

    test('critical and watch are one hue at two commitment levels', () {
      final skin = TiqSkin.night();
      final critical = SeverityMarkToken.of(skin, SeverityMarkKind.critical);
      final watch = SeverityMarkToken.of(skin, SeverityMarkKind.watch);
      expect(critical.ink, skin.palette.badSolid);
      expect(watch.ink, skin.palette.bad);
      expect(critical.shape, isNot(watch.shape));
    });
  });
}
