import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/widgets/torchlight/input.dart';
import 'package:tradeiq_app/core/widgets/torchlight/mark/tiq_mark.dart';

import '../../../../features/agent_harness.dart' show loadAgentFonts;
import 'phase2_harness.dart';

/// SELECTION IS PAINT, NOT LAYOUT.
///
/// > *"Theres also an issue of pressing moving from filters, 7days and all the
/// > other filters"* — the owner, on the dashboard's filter rail, characterised
/// > as *"Jumpy or janky movement — the selection or the chips visibly jump,
/// > flicker or slide badly when you move between filters."*
///
/// The cause was arithmetic, not motion. A selected chip built a 14dp tick disc
/// and a 6dp gap that an unselected chip did not build, and stepped its label
/// from w500 to w700, which measures wider. Measured below, before the fix:
/// **21.92–24.41dp at 1.0× and 26.70–29.93dp at 1.3×**. So tapping a different
/// range shrank the old chip by that much and grew the new one by it **in the
/// same frame**, reflowing every chip after them while the fill was still
/// cross-fading.
///
/// These tests are the fence: a chip's box is the same size selected and
/// unselected, and a rail does not move when the selection moves along it.
///
/// IT LOADS THE REAL FONTS, and that is not decoration — it is what makes the
/// weight half of this measurable at all. `flutter_test`'s own face has one
/// advance width per glyph at every weight, so under it w500 and w700 measure
/// **identically** and a test written without the real face would report the
/// mark's 20dp and silently pass the weight step whatever it did. Measured on
/// Schibsted Grotesk at `label`'s 13dp, "Last 7 days" is 67.58dp at w500 and
/// 70.25dp at w700 — so the real jump on a real phone was 22.67dp, not the 20
/// a fontless harness can see. `entry_width_test.dart` loads them for the same
/// reason, in the same words.
void main() {
  setUpAll(loadAgentFonts);

  /// The painted pill, which is the chip's own box — the `ConstrainedBox`
  /// above it takes the row's height and the `Center` takes the parent's width.
  Finder pillIn(Finder chip) =>
      find.descendant(of: chip, matching: find.byType(AnimatedContainer));

  /// One chip, loose-constrained at the left edge so the pill measures its own
  /// intrinsic width rather than the viewport's.
  Future<Size> pillOf(
    WidgetTester tester, {
    required String skinName,
    required String label,
    required bool selected,
    int? count,
    MarkShape? glyph,
    double textScale = 1.0,
  }) async {
    await pumpPhase2(
      tester,
      skin: phase2SkinNamed(skinName),
      textScale: textScale,
      child: Align(
        alignment: Alignment.topLeft,
        child: TorchFilterChip(
          label: label,
          selected: selected,
          count: count,
          glyph: glyph,
          onSelected: () {},
        ),
      ),
    );
    return tester.getSize(pillIn(find.byType(TorchFilterChip)));
  }

  /// The real faces, and the two scales the ledger measures at.
  const List<double> scales = <double>[1.0, 1.3];

  /// The cases that exist in `lib/`, plus the two that do not yet: a chip with
  /// a `glyph` (the parameter is offered and nothing passes it, so the only
  /// place it can be held to the rule is here) and a chip with a count, which
  /// Tasks passes on every chip in its rail.
  const List<({String label, int? count, MarkShape? glyph})> cases =
      <({String label, int? count, MarkShape? glyph})>[
        (label: 'Last 7 days', count: null, glyph: null),
        (label: 'Last 30 days', count: null, glyph: null),
        (label: 'This quarter', count: null, glyph: null),
        (label: 'All territories', count: null, glyph: null),
        (label: 'Needs a decision', count: 5, glyph: null),
        (label: 'Overdue', count: 12, glyph: null),
        (label: 'Flagged', count: null, glyph: MarkShape.flagBrokenRing),
      ];

  group('the filter chip\'s box', () {
    testWidgets('is the same width selected and unselected', (tester) async {
      final table = StringBuffer()
        ..writeln('face           scale  chip                 unsel    sel');
      final failures = <String>[];

      for (final skinName in phase2SkinNames) {
        for (final scale in scales) {
          for (final c in cases) {
            final off = await pillOf(
              tester,
              skinName: skinName,
              label: c.label,
              count: c.count,
              glyph: c.glyph,
              selected: false,
              textScale: scale,
            );
            final on = await pillOf(
              tester,
              skinName: skinName,
              label: c.label,
              count: c.count,
              glyph: c.glyph,
              selected: true,
              textScale: scale,
            );
            table.writeln(
              '${skinName.padRight(14)} '
              '${scale.toStringAsFixed(1).padRight(6)} '
              '${c.label.padRight(20)} '
              '${off.width.toStringAsFixed(2).padLeft(7)} '
              '${on.width.toStringAsFixed(2).padLeft(7)}',
            );
            if ((off.width - on.width).abs() > 0.01) {
              failures.add(
                '$skinName @${scale}x "${c.label}": '
                '${off.width.toStringAsFixed(2)} unselected vs '
                '${on.width.toStringAsFixed(2)} selected '
                '(${(on.width - off.width).toStringAsFixed(2)}dp)',
              );
            }
            if ((off.height - on.height).abs() > 0.01) {
              failures.add(
                '$skinName @${scale}x "${c.label}" HEIGHT: '
                '${off.height.toStringAsFixed(2)} vs '
                '${on.height.toStringAsFixed(2)}',
              );
            }
          }
        }
      }

      // The measured table is the proof this test exists to produce, and a
      // PASSING run has to be able to show it — `printOnFailure` would only
      // ever show the broken one.
      debugPrint(table.toString());
      expect(
        failures,
        isEmpty,
        reason:
            'Selection changes paint, never layout. A chip that measures '
            'differently selected reflows every chip after it in the rail, '
            'and that reflow is what the owner saw as jumpiness:\n'
            '${failures.join('\n')}',
      );
    });
  });

  group('the filter rail', () {
    /// Every chip's rect in a rail, keyed by label.
    Future<Map<String, Rect>> railRects(
      WidgetTester tester, {
      required String skinName,
      required int selectedIndex,
      double textScale = 1.0,
      Size size = const Size(360, 720),
    }) async {
      const labels = <String>[
        'Today',
        'Last 7 days',
        'Last 30 days',
        'This quarter',
        'All territories',
      ];
      await pumpPhase2(
        tester,
        skin: phase2SkinNamed(skinName),
        textScale: textScale,
        size: size,
        child: Align(
          alignment: Alignment.topLeft,
          child: TorchFilterRail(
            semanticsLabel: 'Filters',
            chips: <Widget>[
              for (final (i, label) in labels.indexed)
                TorchFilterChip(
                  key: ValueKey<String>('rail-$label'),
                  label: label,
                  selected: i == selectedIndex,
                  onSelected: () {},
                ),
            ],
          ),
        ),
      );
      // Only the chips the rail actually built. A `ListView` is lazy, so which
      // chips exist is itself a function of the widths — and a chip that
      // appears or disappears because the selection moved is the same bug one
      // step further on, which is why the key sets are compared as well as the
      // rects.
      return <String, Rect>{
        for (final label in labels)
          if (pillIn(
            find.byKey(ValueKey<String>('rail-$label')),
          ).evaluate().isNotEmpty)
            label: tester.getRect(
              pillIn(find.byKey(ValueKey<String>('rail-$label'))),
            ),
      };
    }

    testWidgets('does not move when the selection moves along it', (
      tester,
    ) async {
      // Phone and desk. The rail is a horizontal scroller at both, so the
      // narrow case is also the one where a width change can push a chip out
      // of the viewport entirely.
      const sizes = <Size>[Size(390, 844), Size(1440, 900)];
      for (final skinName in phase2SkinNames) {
        for (final scale in scales) {
          for (final size in sizes) {
            final first = await railRects(
              tester,
              skinName: skinName,
              selectedIndex: 0,
              textScale: scale,
              size: size,
            );
            final middle = await railRects(
              tester,
              skinName: skinName,
              selectedIndex: 2,
              textScale: scale,
              size: size,
            );
            final where = '$skinName @${scale}x ${size.width.toInt()}dp';
            expect(
              middle.keys.toList(),
              first.keys.toList(),
              reason:
                  '$where: moving the selection changed WHICH chips the rail '
                  'built, which means the widths moved far enough to push a '
                  'chip past the viewport edge.',
            );
            for (final label in first.keys) {
              expect(
                middle[label],
                first[label],
                reason:
                    '$where: "$label" moved when the selection moved from the '
                    'first chip to the third. The rail is a row of controls a '
                    'manager works; a chip that is not under the thumb must '
                    'not slide out from under it.',
              );
            }
          }
        }
      }
    });
  });
}
