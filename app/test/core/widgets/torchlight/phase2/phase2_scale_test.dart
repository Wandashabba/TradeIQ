import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/input.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';

import 'phase2_harness.dart';

/// 2.0× TEXT, AND AFRIKAANS, ON EVERY PHASE 2 COMPONENT.
///
/// Two passes over the same case list, because they fail differently. The
/// text-scale pass catches a pinned height; the Afrikaans pass catches a
/// pinned *width* — and Afrikaans is not a pseudo-locale here, it is the
/// language a large share of this product's agents actually work in.
/// "Beskikbaarheid op rak" is 22 characters where "On-shelf availability" is
/// 21, and "Uit voorraad" wraps where "Out of stock" does not.
///
/// The assertion is deliberately blunt: **nothing overflows**. A `RenderFlex`
/// overflow raises through `FlutterError.onError`, which `takeException`
/// collects, so a component that pins a row or a track fails here by name
/// rather than by a stripe of yellow in a screenshot nobody took.
///
/// The narrowest phone this product supports is 320dp. Every case runs at that
/// width as well as at 360, because the 40dp between them is where a
/// `[−][+]` pair stops fitting beside a four-digit mono figure.
void main() {
  // THE WIDTH IS THE INSTRUMENT; THE HEIGHT IS ROOM TO GROW.
  //
  // Every real screen puts these components inside something that scrolls, so
  // a block that is genuinely taller than a phone is not a bug — it is a
  // paragraph at 2.0×. What IS a bug is a **pin**: a height that refuses to
  // grow, a row that cannot wrap, a track with a fixed box around growing
  // text. Those still overflow inside a 2000dp column, and they are what this
  // catches. The narrowest phone this product supports is 320dp, and the 40dp
  // between 320 and 360 is where a `[−][+]` pair stops fitting beside a
  // four-digit mono figure.
  final sizes = <Size>[const Size(320, 2000), const Size(360, 2000)];

  group('nothing overflows at 2.0× text', () {
    for (final skin in <TiqSkin>[
      TiqSkin.night(density: TiqDensity.field),
      TiqSkin.day(),
      TiqSkin.veld(),
    ]) {
      testWidgets(skin.mode.name, (tester) async {
        for (final size in sizes) {
          for (final entry in phase2Cases()) {
            await pumpPhase2(
              tester,
              skin: skin,
              child: entry.value,
              size: size,
              textScale: 2.0,
            );
            expect(
              tester.takeException(),
              isNull,
              reason:
                  '${entry.key} [${skin.mode.name}, ${size.width.toInt()}dp, '
                  '2.0×] overflowed. Every label wraps to two lines at every '
                  'size and nothing in this system is pinned; a tile grid '
                  'collapses on a LayoutBuilder width, never on a text-scale '
                  'guess.',
            );
          }
        }
      });
    }
  });

  group('nothing overflows in Afrikaans', () {
    for (final skin in <TiqSkin>[
      TiqSkin.night(density: TiqDensity.field),
      TiqSkin.day(),
      TiqSkin.veld(),
    ]) {
      testWidgets(skin.mode.name, (tester) async {
        for (final scale in <double>[1.0, 2.0]) {
          for (final entry in phase2Cases(locale: 'af')) {
            await pumpPhase2(
              tester,
              skin: skin,
              child: entry.value,
              size: const Size(320, 2000),
              textScale: scale,
              locale: const Locale('af'),
            );
            expect(
              tester.takeException(),
              isNull,
              reason:
                  '${entry.key} [${skin.mode.name}, af, $scale×] overflowed.',
            );
          }
        }
      });
    }
  });

  testWidgets('the count stepper drops its pair beneath the trough rather '
      'than squeezing it', (tester) async {
    // At 320dp and 2.0× a 113dp pair beside a four-digit mono figure leaves
    // the trough under the 120dp floor, so the layout collapses — measured on
    // the real width, never guessed from the scaler.
    await pumpPhase2(
      tester,
      skin: TiqSkin.night(density: TiqDensity.field),
      child: SizedBox(
        width: 180,
        child: CountStepper(label: 'Units', value: 1234, onChanged: (_) {}),
      ),
      textScale: 2.0,
    );
    expect(tester.takeException(), isNull);
    final stepper = tester.getRect(find.byType(CountStepper));
    // Stacked, so the control is taller than one 56dp tile row plus its label.
    expect(
      stepper.height,
      greaterThan(56 * 2),
      reason:
          'The pair should have dropped beneath the trough. A squeezed trough '
          'that cannot hold its own figure is the failure this collapse '
          'exists to prevent.',
    );
  });

  testWidgets('the empty-state headline steps down by line count', (
    tester,
  ) async {
    final skin = TiqSkin.night(density: TiqDensity.field);
    // One short line stays at 40.
    expect(
      EmptyState.displaySizeFor(
        headline: 'No route today',
        role: skin.text.display,
        maxWidth: 320,
        scaler: TextScaler.noScaling,
        direction: TextDirection.ltr,
      ),
      40,
    );
    // A long Afrikaans headline in a 280dp column takes more lines and steps
    // down. The rule has a floor of 26 and no fourth step.
    final long = EmptyState.displaySizeFor(
      headline:
          'Geen winkels binne 2 km nie — soek op naam of skandeer ’n '
          'rakstrepieskode',
      role: skin.text.display,
      maxWidth: 280,
      scaler: TextScaler.noScaling,
      direction: TextDirection.ltr,
    );
    expect(long, lessThan(40));
    expect(long, greaterThanOrEqualTo(26));
    expect(EmptyState.displaySteps, <double>[40, 32, 26]);
  });

  testWidgets('a choice group collapses to a column on measured width, not on '
      'a text-scale threshold', (tester) async {
    final skin = TiqSkin.night(density: TiqDensity.field);
    // Three short labels fit side by side when there is room for them. The
    // width is generous on purpose: the test binding renders every glyph at a
    // full em, so a threshold pinned to a phone width here would be measuring
    // the test font rather than the rule.
    expect(
      ChoiceRow.layoutFor(
        skin: skin,
        labels: <String>['Yes', 'No', "Can't tell"],
        maxWidth: 720,
        scaler: TextScaler.noScaling,
        direction: TextDirection.ltr,
      ),
      ChoiceLayout.row,
    );
    // The same three at 2.0×, in the same column, do not — and the rule that
    // says so is a measurement, not a scale-factor threshold.
    expect(
      ChoiceRow.layoutFor(
        skin: skin,
        labels: <String>['Yes', 'No', "Can't tell"],
        maxWidth: 720,
        scaler: const TextScaler.linear(2.0),
        direction: TextDirection.ltr,
      ),
      ChoiceLayout.column,
    );
    // And Veld is always a column, whatever the arithmetic says: three
    // side-by-side 56dp targets in the sun is a mis-tap.
    expect(
      ChoiceRow.layoutFor(
        skin: TiqSkin.veld(),
        labels: <String>['Ja', 'Nee'],
        maxWidth: 1000,
        scaler: TextScaler.noScaling,
        direction: TextDirection.ltr,
      ),
      ChoiceLayout.column,
    );
  });
}
