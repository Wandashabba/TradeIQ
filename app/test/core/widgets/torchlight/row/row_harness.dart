import 'package:flutter/material.dart' show Theme, ThemeData, ThemeExtension;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/motion_budget.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';

/// Pump a row on its skin's own ground, with nothing else on the screen.
///
/// Deliberately no `MaterialApp`: a row is not a `ListTile`, it takes no
/// `Material` ancestor, draws no ink splash and reads nothing from
/// `ThemeData` except the [TiqSkin] extension. A test that needed a
/// `MaterialApp` to render one would be hiding a dependency the component is
/// not supposed to have.
Future<void> pumpRow(
  WidgetTester tester, {
  required TiqSkin skin,
  required Widget child,
  double textScale = 1.0,
  Size size = const Size(360, 720),
  bool still = false,
  double rowWidth = 360,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  Widget tree = Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: rowWidth, child: child),
  );
  if (still) {
    tree = MotionBudgetScope(budget: MotionBudget.frozen, child: tree);
  }

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        devicePixelRatio: 1.0,
        textScaler: TextScaler.linear(textScale),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Theme(
          data: ThemeData(extensions: <ThemeExtension<dynamic>>[skin]),
          child: ColoredBox(color: skin.palette.ground, child: tree),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// The five skin × density pairings a row actually ships in, in the ruling's
/// sequence: Night first, then Day, Veld last.
///
/// `Veld × Console` is absent because it cannot be constructed —
/// `TiqSkin.veld()` takes no density argument, which is the type system
/// carrying a design rule.
const List<(String, TiqDensity?)> rowSkinMatrix = <(String, TiqDensity?)>[
  ('night-console', TiqDensity.console),
  ('night-field', TiqDensity.field),
  ('day-field', TiqDensity.field),
  ('day-console', TiqDensity.console),
  ('veld', null),
];

TiqSkin skinFor(String name) => switch (name) {
  'night-console' => TiqSkin.night(density: TiqDensity.console),
  'night-field' => TiqSkin.night(density: TiqDensity.field),
  'day-field' => TiqSkin.day(density: TiqDensity.field),
  'day-console' => TiqSkin.day(density: TiqDensity.console),
  'veld' => TiqSkin.veld(),
  _ => throw ArgumentError('Unknown skin $name'),
};

/// Forty characters of Afrikaans, which is the p90 width case the pseudo-
/// localisation pass measures against: "Voorraadtelling onvolledig vandag"
/// plus a store. Every label in the system has to wrap it rather than clip it.
const String afrikaansLabel = 'Voorraadtelling onvolledig by winkel 12';

/// A name that middle-truncates rather than end-truncates, and the one it must
/// stay distinguishable from.
const String longName = 'Nomsa Dlamini-Mkhize';
const String similarName = 'Nomsa Dlamini-Ndlovu';
