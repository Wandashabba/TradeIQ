import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';

import 'mark_harness.dart';

void main() {
  group('four states, four silhouettes', () {
    test('every state has a word and a shape of its own', () {
      final skin = TiqSkin.night();
      final shapes = <MarkShape>{};
      final words = <String>{};
      for (final state in SectionState.values) {
        final token = SectionStateToken.of(skin, state);
        shapes.add(token.shape);
        words.add(token.word);
      }
      expect(shapes, hasLength(SectionState.values.length));
      expect(words, hasLength(SectionState.values.length));
    });

    test("can't confirm is excluded from the readiness count", () {
      final skin = TiqSkin.night();
      for (final state in SectionState.values) {
        expect(
          SectionStateToken.of(skin, state).countsTowardReadiness,
          state != SectionState.cantConfirm,
          reason:
              'A section nobody could measure is not a section somebody '
              'skipped. Counting it as one blocks a submit that should go '
              'through.',
        );
      }
    });

    testWidgets('the word renders beside the glyph', (tester) async {
      await tester.pumpWidget(
        skinned(
          TiqSkin.night(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SectionStateGlyph(state: SectionState.cantConfirm),
              Text(
                SectionStateToken.of(
                  TiqSkin.night(),
                  SectionState.cantConfirm,
                ).word,
              ),
            ],
          ),
        ),
      );
      expect(find.text("Can't confirm"), findsOneWidget);
    });
  });

  group("'can't confirm' is distinguishable from 'in progress' IN GREYSCALE", () {
    // This is the test unify §1.5 was decided on. Three of the five surfaces
    // proposed hatching the "can't confirm" tile; a 3dp stripe inside a 28dp
    // tile aliases to a flat grey disc at 40% backlight, which is exactly what
    // "in progress" looks like. A hatched fourth state would pass a colour
    // test and fail this one.
    for (final skin in allSkins) {
      testWidgets('${skin.mode.name}: the two frames differ with hue removed', (
        tester,
      ) async {
        Future<Uint8List> render(SectionState state) => paintMark(
          tester,
          skin: skin,
          child: SectionStateGlyph(state: state),
        );

        final inProgress = await render(SectionState.inProgress);
        final cantConfirm = await render(SectionState.cantConfirm);
        final notStarted = await render(SectionState.notStarted);
        final done = await render(SectionState.done);

        final difference = greyscaleDifference(inProgress, cantConfirm);
        expect(
          difference,
          greaterThan(0.005),
          reason:
              '"In progress" and "can\'t confirm" differ on only '
              '${(difference * 100).toStringAsFixed(2)}% of the frame once '
              'the hue is removed. They are the same silhouette, which is the '
              'failure a hatched fourth state produces on a 6-bit panel at '
              '40% backlight. "Can\'t confirm" is a ring with a 2px diagonal '
              'bar, not a hatch.',
        );

        // …and every other pair, so the ladder has four readings and not two.
        final frames = <String, Uint8List>{
          'not started': notStarted,
          'in progress': inProgress,
          'done': done,
          "can't confirm": cantConfirm,
        };
        final names = frames.keys.toList();
        for (var i = 0; i < names.length; i++) {
          for (var j = i + 1; j < names.length; j++) {
            final d = greyscaleDifference(frames[names[i]]!, frames[names[j]]!);
            expect(
              d,
              greaterThan(0.002),
              reason:
                  '"${names[i]}" and "${names[j]}" are the same grey frame '
                  '(${(d * 100).toStringAsFixed(2)}% differing). Four states '
                  'need four silhouettes.',
            );
          }
        }
      });
    }

    testWidgets('each glyph actually paints something', (tester) async {
      final skin = TiqSkin.night();
      for (final state in SectionState.values) {
        final frame = await paintMark(
          tester,
          skin: skin,
          child: SectionStateGlyph(state: state),
        );
        expect(
          inkedFraction(frame, skin.palette.ground),
          greaterThan(0.01),
          reason:
              '${state.name} painted almost nothing. A silhouette test that '
              'compares two blank frames passes for the wrong reason.',
        );
      }
    });
  });

  group('scale', () {
    testWidgets('the tile is 28dp at 1.0x and 48dp at 2.0x', (tester) async {
      for (final entry in <double, double>{1.0: 28, 2.0: 48}.entries) {
        await tester.pumpWidget(
          skinned(
            TiqSkin.night(),
            const SectionStateGlyph(state: SectionState.done),
            textScale: entry.key,
          ),
        );
        final box = tester.getSize(
          find.descendant(
            of: find.byType(SectionStateGlyph),
            matching: find.byType(Container),
          ),
        );
        expect(
          box.width,
          entry.value,
          reason:
              'A meaning-bearing tile scales with text — 28 to 48, not 28 to '
              '56. A nine-rung ladder that doubled would leave the fold at '
              'exactly the setting that needed it most.',
        );
      }
    });
  });
}
