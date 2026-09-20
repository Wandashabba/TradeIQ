import 'package:flutter/material.dart' show Theme, ThemeData, ThemeExtension;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/motion_budget.dart';
import 'package:tradeiq_app/core/design/tiq_number.dart';
import 'package:tradeiq_app/core/design/torch_scope.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';

import '../../../design/amber_golden.dart';
import 'row_harness.dart';

/// A ROW NEVER EMITS LIGHT.
///
/// This is the rule the amber law lives or dies on. There are sixty screens
/// and every one of them is mostly rows; if a row can be amber then amber is
/// repeated, and "at most two lit objects in the composed frame" becomes a
/// sentence in a document rather than a fact about the product. Every earlier
/// draft of this system reintroduced it somewhere — a pulsing dot on the live
/// person row, an amber queue chip, an amber "sent back" flag — which is why
/// this is a pixel census and not a code review.
///
/// The census is the Phase 0 harness: render the widget, walk every pixel,
/// decide whether it is flame-hued (hue 20°–48°, value ≥ 0.90, saturation
/// ≥ 0.12), find the connected regions and count them. The budget here is not
/// the skin's two or one — it is **zero**. A row has no claim to spend.
void main() {
  /// Every configuration that could plausibly want to be amber, including the
  /// three states earlier drafts actually made amber: a sending queue item, a
  /// critical decision and a live person.
  List<Widget> everyRow() => <Widget>[
    SoftRow(
      title: 'Kasi Corner Spaza',
      subtitle: 'Out of stock since Tuesday',
      severity: SoftRowSeverity.critical,
      severityLabel: 'Critical',
      leading: const RowMarkTile(mark: RowMark.square),
      trailing: const SoftRowChevron(),
      onTap: () {},
    ),
    SoftRow(
      form: SoftRowForm.standalone,
      density: SoftRowDensity.tall,
      title: 'Next up · Shoprite Klipspruit',
      subtitle: '1,2 km away',
      severity: SoftRowSeverity.watch,
      severityLabel: 'Watch',
      trailing: const SoftRowChevron(),
      onTap: () {},
    ),
    for (final state in OutboxState.values)
      OutboxRow(
        state: state,
        title: 'Shelf photo · Kasi Corner Spaza',
        stateWord: 'Sending',
        sentence: 'Sending now',
        ageLine: 'queued 14:03',
        payloadBytes: 1468006,
        stuckLabel: 'Needs you',
        onTap: () {},
      ),
    for (final state in HeldWorkState.values)
      HeldWorkRow(
        state: state,
        title: '4 visits held on this phone',
        stateWord: 'Held',
        meta: 'oldest 2 h 14 m · last sent 11:48',
        stuckLabel: 'Watch',
        onTap: () {},
      ),
    DecisionRow(
      title: 'Shoprite Klipspruit Mall',
      reason: 'Availability fell 14 points in three visits',
      severity: SoftRowSeverity.critical,
      severityLabel: 'Critical',
      value: 71,
      unit: TiqUnit.percent,
      onTap: () {},
    ),
    PersonRow(
      name: 'Thandi Mokoena',
      role: 'Field agent',
      outlet: 'Kasi Corner Spaza',
      trailingWord: 'Live',
      onTap: () {},
    ),
    const PersonRow(
      unknownLabel: 'Unknown agent',
      identifier: 'a4f2c118',
      identifierLabel: 'Reference',
    ),
  ];

  for (final name in rowSkinMatrix.map((e) => e.$1)) {
    final skin = skinFor(name);
    for (final scale in <double>[1.0, 2.0]) {
      testWidgets('$name at ${scale}x paints zero amber objects', (
        tester,
      ) async {
        await pumpAmberRoute(
          tester,
          skin: skin,
          textScale: scale,
          // Tall enough to hold every row at this scale without a clip: a
          // census cannot count a light that was scrolled off.
          size: Size(360, scale >= 2.0 ? 6400 : 3000),
          child: MotionBudgetScope(
            // Frozen, so the census sees a resting frame rather than one dot
            // of a travelling group. The moving frames are covered by the
            // token-classification test below, which proves that the colour
            // the dots are painted in is outside the flame box at every
            // moment they could be drawn.
            budget: MotionBudget.frozen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: everyRow(),
            ),
          ),
        );
        final census = await amberCensus(tester);
        expect(
          census.objectCount,
          0,
          reason:
              '$name at ${scale}x: a row painted ${census.objectCount} amber '
              'object(s).\n\n${census.describe()}\n'
              'A list row is never lit. There are sixty screens and they are '
              'mostly rows; the moment one can be amber, amber is repeated '
              'and the two-object budget stops meaning anything. Sending is '
              'Oatmeal dots, held is an Oatmeal square, severity is crimson '
              'plus a silhouette plus a word, and none of the three is on the '
              'TorchScope ladder.',
        );
      });
    }
  }

  test('every ink a row can paint is outside the flame box', () {
    // The census above renders a resting frame. This closes the gap: no token
    // a row is allowed to reach for is flame-hued at all, so no frame of any
    // animation can be.
    for (final name in rowSkinMatrix.map((e) => e.$1)) {
      final palette = skinFor(name).palette;
      final inks = <String, Color>{
        'ink1': palette.ink1,
        'ink2': palette.ink2,
        'ink3': palette.ink3,
        'inkMute': palette.inkMute,
        'bad': palette.bad,
        'badSolid': palette.badSolid,
        'good': palette.good,
        'comparison': palette.comparison,
        'edgeStructure': palette.edgeStructure,
        'edgeControl': palette.edgeControl,
        'hairline': palette.hairline,
        'well': palette.well,
        'surface': palette.surface,
        'lifted': palette.lifted,
      };
      inks.forEach((token, colour) {
        expect(
          isFlameHued(
            (colour.r * 255).round(),
            (colour.g * 255).round(),
            (colour.b * 255).round(),
          ),
          isFalse,
          reason: '$name: $token is inside the flame box.',
        );
      });
    }
  });

  testWidgets(
    'a row inside a TorchScope with a full budget still paints none',
    (tester) async {
      // The strongest version of the claim: even on a route where amber is
      // available, a row does not take any. It declares no claim, so there is
      // nothing for it to be granted.
      final skin = TiqSkin.night();
      await pumpAmberRoute(
        tester,
        skin: skin,
        child: TorchScopeFixture(skin: skin, child: everyRow().first),
      );
      final census = await amberCensus(tester);
      expect(census.objectCount, 0);
    },
  );
}

/// A Night route with both grants already declared, so a row that quietly lit
/// itself would show up as a third object rather than as a legal one.
class TorchScopeFixture extends StatelessWidget {
  const TorchScopeFixture({super.key, required this.skin, required this.child});

  final TiqSkin skin;
  final Widget child;

  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData(extensions: <ThemeExtension<dynamic>>[skin]),
    child: TorchScope(
      skin: skin,
      phase: 'loaded',
      navRenders: true,
      tabbedRoute: true,
      claims: const <TorchClaim>[TorchClaim.primaryCommit('commit')],
      child: child,
    ),
  );
}
