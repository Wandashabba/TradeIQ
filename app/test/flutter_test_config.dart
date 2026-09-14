import 'dart:async';

import 'package:tradeiq_app/core/widgets/glass.dart';

/// Runs before every test file in this package.
///
/// Lumen Glass has four ambient loops — the button sweep, the dark-pane
/// bloom, the held-capture pulse and the retry spin — and each one repeats
/// for as long as its widget is on screen. A forever-repeating animation
/// means `pumpAndSettle` never settles, so every screen test would hang.
/// Tests assert the resting frame instead; the loops themselves are covered
/// by `test/core/widgets/glass_test.dart`, which switches them back on.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AmbientMotion.enabled = false;
  await testMain();
}
