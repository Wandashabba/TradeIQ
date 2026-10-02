import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/entry_skin.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/display_headline.dart';
import 'package:tradeiq_app/core/widgets/torchlight/plate/plate.dart';
import 'package:tradeiq_app/features/auth/presentation/entry_plate.dart';

import '../agent_harness.dart' show loadAgentFonts;

/// THE HARNESS BEHIND THE TABLE ON [EntryPlate.tallest], AND ITS PROOF.
///
/// `EntryPlate.tallest` records a known, deferred defect: the plate's height is
/// a flat 250 that never heard about the text scale, so at 1.3× and above the
/// headline on the plate renders smaller than the field labels under it. The
/// note carries a measured table — the minimum plate height at which the
/// headline stops being shrunk, at four text scales and five widths — and the
/// table is what a future `proportion` parameter would be built from.
///
/// **That table was measured in Onest and its own last line said to re-measure
/// the whole thing if the prose face changed.** It changed twice on 1 October
/// 2026: Schibsted Grotesk replaced Onest, and then the prose scale came down
/// 13/14, which moved the display ladder from 40/32/26 to 37/30/24. This file
/// is how the table was re-derived, committed so the next person does not have
/// to invent the method again — and so the numbers in that doc comment are
/// checked by CI rather than trusted.
///
/// ## The method, and why it is not a screenshot
///
/// [TiqPlate] puts the hero cluster in a `FittedBox(scaleDown)` inside a
/// `Positioned(top: textZoneTop, bottom: TiqSpace.s4)`. `textZoneTop` is
/// `0.48 × H` at 240dp of plate and above and `0.42 × H` below it, so the box
/// the cluster is fitted into is:
///
///     0.52 × H − 16     (H ≥ 240)
///     0.58 × H − 16     (H < 240)
///
/// A `FittedBox` **transforms** its child; it does not re-lay it out. So the
/// child's own `RenderBox.size` is its natural height at that width and scale,
/// while `tester.getRect` returns the painted rect. The headline is unshrunk
/// exactly when the cluster's natural height fits the box, which inverts to
///
///     H ≥ (natural + 16) / fraction
///
/// — one render per cell instead of a sweep. `derive` does that, and
/// `the derivation agrees with a direct sweep` checks it the slow way at 1.0×,
/// which is the one row the plate can actually reach: 211 derived against
/// 210.4 observed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAgentFonts);

  const headline = 'Sign in to get to work.';
  const supporting = 'Use your work email and password.';

  /// The widths in the table: the two phones, the owner's browser window, a
  /// large phone, and a desktop viewport where the plate is the reading width.
  const widths = <double>[360, 390, 395, 430, 1280];

  /// The re-derived table, as committed on [EntryPlate.tallest].
  ///
  /// Keyed scale → width → minimum plate height. If a cell here fails, the
  /// doc comment is wrong and the failure prints the number to put in it.
  // `String` keys, not `double`: a const map may not key on a type that
  // overrides `==`, which `double` does.
  const expected = <String, Map<String, int>>{
    '1.0': <String, int>{
      '360': 211,
      '390': 211,
      '395': 211,
      '430': 211,
      '1280': 147,
    },
    '1.3': <String, int>{
      '360': 289,
      '390': 289,
      '395': 289,
      '430': 289,
      '1280': 176,
    },
    '1.6': <String, int>{
      '360': 362,
      '390': 362,
      '395': 362,
      '430': 343,
      '1280': 206,
    },
    '2.0': <String, int>{
      '360': 393,
      '390': 554,
      '395': 554,
      '430': 439,
      '1280': 274,
    },
  };

  Future<void> pump(
    WidgetTester tester, {
    required double width,
    required double viewportHeight,
    required double scale,
  }) async {
    final viewport = Size(width, viewportHeight);
    tester.view
      ..physicalSize = viewport
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final skin = entrySkinFor(SkinMode.night);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: viewport,
          devicePixelRatio: 1.0,
          textScaler: TextScaler.linear(scale),
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Theme(
            data: ThemeData(extensions: <ThemeExtension<dynamic>>[skin]),
            child: ColoredBox(
              color: skin.palette.ground,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: skin.space.gutter,
                    ),
                    child: const EntryPlate(
                      headline: headline,
                      supporting: supporting,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// The cluster's natural height, the headline's natural and painted heights,
  /// and the plate's resolved height, off the current frame.
  ({double cluster, double headNatural, double headPainted, double plate})
  read(WidgetTester tester) {
    final fitted = find.descendant(
      of: find.byType(TiqPlate),
      matching: find.byType(FittedBox),
    );
    RenderBox? child;
    tester
        .renderObject<RenderObject>(fitted.first)
        .visitChildren((c) => child = c as RenderBox);
    final head = find.byType(TorchDisplayHeadline).first;
    return (
      cluster: child!.size.height,
      headNatural: tester.renderObject<RenderBox>(head).size.height,
      headPainted: tester.getRect(head).height,
      plate: tester.getRect(find.byType(TiqPlate)).height,
    );
  }

  /// `(natural + 16) / fraction`, with the fraction chosen by the branch the
  /// resulting height actually lands in.
  int derive(double cluster) {
    final tall = (cluster + 16) / 0.52;
    final short = (cluster + 16) / 0.58;
    return (short < 240 ? short : tall).ceil();
  }

  group('the minimum plate height the headline needs', () {
    for (final scaleKey in expected.keys) {
      final scale = double.parse(scaleKey);
      for (final width in widths) {
        final widthKey = width.toStringAsFixed(0);
        testWidgets('${scaleKey}x at ${widthKey}dp wide', (tester) async {
          // A viewport tall enough that the plate sits at its 250 ceiling, so
          // the cluster is laid out at the width it really gets on screen.
          await pump(
            tester,
            width: width,
            viewportHeight: 3000,
            scale: scale,
          );
          final needed = derive(read(tester).cluster);
          expect(
            needed,
            expected[scaleKey]![widthKey],
            reason:
                'The table on EntryPlate.tallest says ${scaleKey}x at '
                '${widthKey}dp wide needs '
                '${expected[scaleKey]![widthKey]}dp of plate; it now needs '
                '$needed. Put $needed in the doc comment — and read the two '
                'paragraphs under it before concluding this is a regression, '
                'because a rung of the display fitting ladder moving under a '
                'cell can make the number go UP when the type gets smaller.',
          );
        });
      }
    }

    testWidgets('the derivation agrees with a direct sweep at 1.0x', (
      tester,
    ) async {
      // The one row the plate can actually reach, and therefore the only one
      // the formula can be checked against rather than trusted.
      for (final width in <double>[360, 390]) {
        var crossover = -1.0;
        for (var vh = 420.0; vh <= 1400.0; vh += 1) {
          await pump(tester, width: width, viewportHeight: vh, scale: 1.0);
          final r = read(tester);
          if (r.headPainted >= r.headNatural - 0.05) {
            crossover = r.plate;
            break;
          }
        }
        final key = width.toStringAsFixed(0);
        expect(
          crossover,
          closeTo(expected['1.0']![key]!.toDouble(), 1.0),
          reason:
              'At ${key}dp wide the headline stops shrinking at a '
              '${crossover.toStringAsFixed(1)}dp plate, which should be within '
              '1dp of the derived ${expected['1.0']![key]}. If these two '
              'disagree the box arithmetic in the doc above is wrong, not the '
              'table.',
        );
      }
    });

    testWidgets('1.0x fits inside tallest, and nothing above it does', (
      tester,
    ) async {
      // The shape of the recorded defect, as an assertion rather than a
      // paragraph: normal type fits the plate the owner approved and every
      // larger setting does not, on the phone the complaint came from.
      expect(
        expected['1.0']!['390'],
        lessThan(EntryPlate.tallest),
        reason:
            'Normal type no longer fits the 250dp plate. That is not the '
            'recorded defect, it is a new one.',
      );
      for (final scaleKey in <String>['1.3', '1.6', '2.0']) {
        expect(
          expected[scaleKey]!['390'],
          greaterThan(EntryPlate.tallest),
          reason:
              '${scaleKey}x now fits inside tallest at 390 wide. If that is '
              'real, the defect on EntryPlate.tallest is partly fixed and the '
              'note should say so.',
        );
      }
    });
  });
}
