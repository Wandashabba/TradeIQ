import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_contrast.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/figure/sparkline.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';

import 'mark_harness.dart';
import 'torch_harness.dart';

/// WHEN A FIGURE MAY BE COLOURED, AND WHEN IT MAY NOT.
///
/// The owner's rule, 28 September 2026: *"Apply colour where a number means
/// something… Where there is no target there is no judgement, so it stays ink
/// — do not colour a number just to brighten the screen."* This is that rule
/// as a test, because a rule that lives only in a doc comment is a rule the
/// next screen will not follow.
///
/// ## THE GROUND GOT A VOTE — 29 September 2026
///
/// Everything above still holds and none of it was weakened. What changed is
/// that the answer is now per skin: the owner looked at The Floor in the dark
/// theme and asked for *"the numbers lumunuous white and not red"*, so on
/// Night a row figure stays `ink1` and the mark beside it carries the verdict.
/// Day is untouched.
///
/// Several tests below used to loop `allSkins` and assert one answer for both.
/// They asserted the old decision — that a figure's ground does not matter —
/// and they are split rather than relaxed: each now states what Day does AND
/// what Night does, so neither half can rot into the other.
void main() {
  group('standingInk — colour only where there is a judgement', () {
    test('a figure with no standing is plain ink in every skin', () {
      for (final skin in allSkins) {
        expect(
          standingInk(skin, null),
          isNull,
          reason:
              '${skin.mode.name}: a figure with nothing to be measured '
              'against carries no verdict, so it carries no colour. Null is '
              'what FigureSlot needs to fall back to its own state.',
        );
      }
    });

    test('held and live are not verdicts and never colour a figure', () {
      for (final skin in allSkins) {
        expect(standingInk(skin, StatusLevel.held), isNull);
        expect(standingInk(skin, StatusLevel.live), isNull);
      }
    });

    // THE ONE THAT PROTECTS unify §4. An em dash stays an em dash: a figure
    // that could not be measured is never dressed in a verdict, however
    // confidently the standing was computed from whatever value was to hand.
    test('no state but a plain measurement is ever coloured', () {
      for (final skin in allSkins) {
        for (final state in <FigureState>[
          FigureState.missing,
          FigureState.notMeasured,
          FigureState.lowSample,
          FigureState.provisional,
        ]) {
          for (final level in StatusLevel.values) {
            expect(
              standingInk(skin, level, state: state),
              isNull,
              reason:
                  '${skin.mode.name}: a ${state.name} figure was given the '
                  '${level.name} verdict. A figure that cannot be judged is '
                  'never coloured — not the em dash, not the thin sample, not '
                  'the provisional score.',
            );
          }
        }
        // ...and a measured figure with a verdict DOES take the colour —
        // where its ground allows one. On Night only a headline does; see the
        // split below.
        expect(
          standingInk(skin, StatusLevel.critical, rank: FigureRank.headline),
          skin.palette.bad,
          reason: 'A measured headline with a verdict does take the colour.',
        );
      }
    });

    // THE GRADE SPLIT, WHICH IS A CONTRAST RULE AND NOT A TASTE ONE.
    //
    // Asked of the figures that ARE coloured on each ground: every level on
    // Day, and the headline on Night. The question the grade split answers —
    // `bad` or `badSolid` — is the same on both.
    test('a figure takes the word grade, never the mark grade', () {
      for (final skin in allSkins) {
        final rank = skin.standingColoursFigures
            ? FigureRank.row
            : FigureRank.headline;
        for (final level in <StatusLevel>[
          StatusLevel.critical,
          if (skin.standingColoursFigures) StatusLevel.watch,
        ]) {
          expect(
            standingInk(skin, level, rank: rank),
            skin.palette.bad,
            reason:
                '${skin.mode.name}: ${level.name} must set a figure in `bad`, '
                'not `badSolid`. badSolid is a fill — on Night surface it is '
                '${contrastRatio(skin.palette.badSolid, skin.palette.surface).toStringAsFixed(2)}'
                ':1, and a word on a card needs 4.5:1. The commitment level '
                'is carried by the mark beside the figure, which is a fill '
                'against an outline.',
          );
        }
        if (skin.standingColoursFigures) {
          expect(standingInk(skin, StatusLevel.onTarget), skin.palette.good);
        }
      }
    });

    // ── THE SPLIT ITSELF, 29 September 2026 ────────────────────────────
    //
    // The reversal is on `severityInk`'s doc comment with both quotes and
    // both dates. This is the arithmetic half: what each ground actually
    // returns, so neither can drift into the other unnoticed.
    group('the ground decides whether a figure may be crimson', () {
      test('Night: a row figure is luminous at every band', () {
        final night = TiqSkin.night();
        for (final level in StatusLevel.values) {
          expect(
            standingInk(night, level),
            isNull,
            reason:
                'A ${level.name} row figure took colour on Night. Null is '
                'what FigureSlot needs to fall back to ink1 — the bone the '
                'artifact sets every `.srow .val` in. The verdict belongs to '
                'the dot beside it.',
          );
        }
      });

      test('Night: a headline keeps crimson, but only at critical', () {
        final night = TiqSkin.night();
        expect(
          standingInk(night, StatusLevel.critical, rank: FigureRank.headline),
          night.palette.bad,
          reason:
              'The one coloured figure the artifact draws is a critical '
              "headline — Ask's -43,6%, beside a bone 481 615.",
        );
        for (final level in <StatusLevel>[
          StatusLevel.watch,
          StatusLevel.onTarget,
          StatusLevel.held,
          StatusLevel.live,
        ]) {
          expect(
            standingInk(night, level, rank: FigureRank.headline),
            isNull,
            reason:
                'A ${level.name} headline took colour on Night. Only a '
                'genuinely critical headline does; a watch-band headline says '
                'so in its target words.',
          );
        }
      });

      test('Day did not move — the owner said "this is on the dark theme"', () {
        final day = TiqSkin.day();
        for (final rank in FigureRank.values) {
          expect(
            standingInk(day, StatusLevel.critical, rank: rank),
            day.palette.bad,
          );
          expect(
            standingInk(day, StatusLevel.watch, rank: rank),
            day.palette.bad,
          );
          expect(
            standingInk(day, StatusLevel.onTarget, rank: rank),
            day.palette.good,
          );
        }
      });

      test('the law is a skin value, not a mode check', () {
        // If this ever becomes `skin.mode == SkinMode.night` at a call site,
        // the next skin has to be added in N places instead of one. The whole
        // reason `amberIsInk` has this shape.
        expect(TiqSkin.night().standingColoursFigures, isFalse);
        expect(TiqSkin.day().standingColoursFigures, isTrue);
        final forced = TiqSkin.night().copyWith(standingColoursFigures: true);
        expect(
          standingInk(forced, StatusLevel.watch),
          forced.palette.bad,
          reason:
              'standingInk reads the value and nothing else. A skin that says '
              'it colours figures colours them, whatever its mode is called.',
        );
      });

      // AND THE STATE STILL OUTRANKS ALL OF IT. A figure that cannot be judged
      // is not coloured on either ground at either rank — unify section 4 was
      // not part of the reversal.
      test('an unjudgeable figure is plain ink on both grounds, both ranks', () {
        for (final skin in allSkins) {
          for (final rank in FigureRank.values) {
            expect(
              standingInk(
                skin,
                StatusLevel.critical,
                state: FigureState.lowSample,
                rank: rank,
              ),
              isNull,
            );
          }
        }
      });
    });

    test('the word grade clears 4.5:1 on every fill a figure sits on', () {
      for (final skin in allSkins) {
        final p = skin.palette;
        // The role's own floor is the whole requirement: no skin declares
        // one of its own since Veld was removed (28 September 2026).
        const floor = 4.5;
        for (final MapEntry(key: name, value: ink) in <String, Color>{
          'good': p.good,
          'bad': p.bad,
        }.entries) {
          for (final MapEntry(key: on, value: fill) in <String, Color>{
            'ground': p.ground,
            'well': p.well,
            'surface': p.surface,
            'raised': p.raised,
          }.entries) {
            final ratio = contrastRatio(ink, fill);
            expect(
              ratio,
              greaterThanOrEqualTo(floor),
              reason:
                  '${skin.mode.name} $name on $on is '
                  '${ratio.toStringAsFixed(2)}:1, under $floor:1. A severity '
                  'that carries a word has to be readable as one.',
            );
          }
        }
      }
    });
  });

  group('againstStandard', () {
    test('on it, near it, or breaching it', () {
      expect(againstStandard(95, 95), StatusLevel.onTarget);
      expect(againstStandard(96, 95), StatusLevel.onTarget);
      expect(againstStandard(94.9, 95), StatusLevel.watch);
      expect(againstStandard(85, 95), StatusLevel.watch);
      expect(againstStandard(84.9, 95), StatusLevel.critical);
    });

    test('on target draws no mark, and still carries the green', () {
      // A verdict is only ever crimson as a MARK in this system — there is no
      // green triangle. The figure's ink is a different channel and green is
      // exactly what it is for.
      expect(severityFor(StatusLevel.onTarget), isNull);
      expect(severityFor(StatusLevel.watch), SeverityMarkKind.watch);
      expect(severityFor(StatusLevel.critical), SeverityMarkKind.critical);
      // The green is Day's, since 29 September 2026. On Night an on-target
      // figure is luminous bone like every other row figure, and "on the
      // standard" is the word on its meta line.
      expect(
        standingInk(TiqSkin.day(), StatusLevel.onTarget),
        TiqSkin.day().palette.good,
      );
      expect(standingInk(TiqSkin.night(), StatusLevel.onTarget), isNull);
    });
  });

  group('severityInk — the row figure and the ground it sits on', () {
    // THIS GROUP WAS NAMED "a row figure matches its row" AND ASSERTED IT FOR
    // BOTH SKINS. That was the 28 September decision and it was reversed on
    // Night the next day; see the quotes on `severityInk` itself. The old
    // assertions are kept for Day, where the rule never changed.
    test('Day: a verdict colours, an absence does not', () {
      final skin = TiqSkin.day();
      expect(severityInk(skin, SeverityMarkKind.critical), skin.palette.bad);
      expect(severityInk(skin, SeverityMarkKind.watch), skin.palette.bad);
      expect(severityInk(skin, SeverityMarkKind.onTarget), skin.palette.good);
      expect(severityInk(skin, SeverityMarkKind.held), isNull);
      expect(severityInk(skin, SeverityMarkKind.notMeasured), isNull);
      expect(severityInk(skin, null), isNull);
    });

    test('Night: nothing at row rank, and only critical at headline', () {
      final skin = TiqSkin.night();
      for (final kind in SeverityMarkKind.values) {
        expect(
          severityInk(skin, kind),
          isNull,
          reason: 'A ${kind.name} row figure took colour on Night.',
        );
      }
      expect(
        severityInk(skin, SeverityMarkKind.critical, rank: FigureRank.headline),
        skin.palette.bad,
      );
      expect(
        severityInk(skin, SeverityMarkKind.watch, rank: FigureRank.headline),
        isNull,
      );
    });

    test('an absence is never a verdict on either ground', () {
      // `held` is Oatmeal and `notMeasured` is an absence. Neither was ever a
      // verdict and the reversal did not make either one.
      for (final skin in allSkins) {
        for (final rank in FigureRank.values) {
          expect(severityInk(skin, SeverityMarkKind.held, rank: rank), isNull);
          expect(
            severityInk(skin, SeverityMarkKind.notMeasured, rank: rank),
            isNull,
          );
          expect(severityInk(skin, null, rank: rank), isNull);
        }
      }
    });
  });

  group('the sparkline carries its own standing', () {
    for (final (name, kind, want) in <(String, SeverityMarkKind?, String)>[
      ('verdictless', null, 'chartNeutral'),
      ('on target', SeverityMarkKind.onTarget, 'good'),
      ('watch', SeverityMarkKind.watch, 'bad'),
      ('critical', SeverityMarkKind.critical, 'bad'),
      // Not verdicts: a held or unscored series keeps the neutral it has
      // always had rather than being dressed as good news or bad.
      ('held', SeverityMarkKind.held, 'chartNeutral'),
      ('not measured', SeverityMarkKind.notMeasured, 'chartNeutral'),
    ]) {
      testWidgets('a $name run strokes in $want', (tester) async {
        for (final skin in <TiqSkin>[TiqSkin.night(), TiqSkin.day()]) {
          await pumpTorch(
            tester,
            skin: skin,
            child: Sparkline(
              points: const <double>[71, 68, 72, 66, 64, 61],
              severity: kind,
            ),
          );
          final painter =
              tester
                      .widget<CustomPaint>(
                        find.descendant(
                          of: find.byType(Sparkline),
                          matching: find.byType(CustomPaint),
                        ),
                      )
                      .painter!
                  as SparklinePainter;
          final expected = switch (want) {
            'good' => skin.palette.good,
            'bad' => skin.palette.bad,
            _ => skin.palette.chartNeutral,
          };
          expect(
            painter.line,
            expected,
            reason:
                '${skin.mode.name}: a $name sparkline drew the wrong stroke. '
                'A grey scribble is what the owner read on Palladian — it '
                'says there is a shape and nothing about whether the shape is '
                'good news.',
          );
          // The stroke is a 1.5dp graphic and takes the WORD grade, never the
          // mark grade: Night badSolid is 3.21:1 on `raised`.
          expect(painter.line, isNot(skin.palette.badSolid));
        }
      });
    }

    testWidgets('the last dot still carries the commitment level', (
      tester,
    ) async {
      final skin = TiqSkin.day();
      for (final (kind, want) in <(SeverityMarkKind, Color)>[
        (SeverityMarkKind.critical, skin.palette.badSolid),
        (SeverityMarkKind.watch, skin.palette.bad),
        (SeverityMarkKind.onTarget, skin.palette.good),
      ]) {
        await pumpTorch(
          tester,
          skin: skin,
          child: Sparkline(
            points: const <double>[71, 68, 72],
            severity: kind,
          ),
        );
        final painter =
            tester
                    .widget<CustomPaint>(
                      find.descendant(
                        of: find.byType(Sparkline),
                        matching: find.byType(CustomPaint),
                      ),
                    )
                    .painter!
                as SparklinePainter;
        expect(
          painter.dot,
          want,
          reason:
              'The dot is a 5dp disc — a mark — so it keeps the mark grade '
              'and the two commitment levels the severity set has. Only the '
              'hairline stroke steps down to the word grade.',
        );
      }
    });
  });

  group('the decision row figure, on each ground', () {
    for (final (name, severity, wants) in <(String, SoftRowSeverity, bool)>[
      ('critical', SoftRowSeverity.critical, true),
      ('watch', SoftRowSeverity.watch, true),
      ('none', SoftRowSeverity.none, false),
    ]) {
      testWidgets('a $name row on Day', (tester) async {
        final skin = TiqSkin.day();
        await pumpTorch(
          tester,
          skin: skin,
          child: DecisionRow(
            title: 'SaveMor Glenwood',
            reason: 'Kalahari Cola 2L out of stock',
            severity: severity,
            severityLabel: severity == SoftRowSeverity.none ? null : name,
            value: 56.9,
            unit: TiqUnit.worded('h', tight: true),
          ),
        );
        final ink = _figureInk(tester, '56.9');
        expect(
          ink,
          wants ? skin.palette.bad : skin.palette.ink1,
          reason:
              'A $name row drew its figure in the wrong ink. The number is '
              'the proof of the severity the dot is claiming; in neutral ink '
              'beside a crimson dot it reads as two things.',
        );
      });
    }

    // Colour is never the only signal, and this is the test that says so for
    // this row: the severity word is in the semantics whether or not the
    // figure is coloured.
    testWidgets('the word survives the colour', (tester) async {
      await pumpTorch(
        tester,
        skin: TiqSkin.day(),
        child: const DecisionRow(
          title: 'SaveMor Glenwood',
          reason: 'Kalahari Cola 2L out of stock',
          severity: SoftRowSeverity.critical,
          severityLabel: 'Critical',
          value: 56.9,
          valueSemanticsLabel: 'Open for 57 hours',
        ),
      );
      final node = tester.getSemantics(find.byType(DecisionRow));
      expect(node.label, contains('Critical'));
      expect(node.label, contains('Open for 57 hours'));
    });

    // An em dash is an em dash. The row has a severity and the figure still
    // refuses the verdict, because the figure is not there to carry one.
    testWidgets('a missing figure is never coloured', (tester) async {
      final skin = TiqSkin.day();
      await pumpTorch(
        tester,
        skin: skin,
        child: const DecisionRow(
          title: 'SaveMor Glenwood',
          reason: 'Kalahari Cola 2L out of stock',
          severity: SoftRowSeverity.critical,
          severityLabel: 'Critical',
          value: null,
          figureState: FigureState.missing,
          valueSemanticsLabel: 'No time recorded for this finding',
        ),
      );
      expect(_figureInk(tester, emDash), skin.palette.ink3);
    });
  });
}

/// The colour of the run that prints [text] in the pumped tree.
Color _figureInk(WidgetTester tester, String text) {
  for (final widget in tester.widgetList<RichText>(find.byType(RichText))) {
    final span = widget.text;
    if (!span.toPlainText().contains(text)) continue;
    Color? found;
    span.visitChildren((InlineSpan child) {
      if (child is TextSpan &&
          (child.text ?? '').contains(text) &&
          child.style?.color != null) {
        found = child.style!.color;
        return false;
      }
      return true;
    });
    if (found != null) return found!;
    final colour = span.style?.color;
    if (colour != null) return colour;
  }
  fail('No run printing "$text" was found in the tree.');
}
