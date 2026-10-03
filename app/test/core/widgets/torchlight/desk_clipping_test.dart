import 'package:flutter/rendering.dart'
    show RenderAbstractViewport, RenderViewport, axisDirectionToAxis;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/bleed.dart';
import 'package:tradeiq_app/core/widgets/torchlight/console_desk.dart';
import 'package:tradeiq_app/features/alerts/presentation/alerts_screen.dart';
import 'package:tradeiq_app/features/trends/presentation/trends_screen.dart';
import 'package:tradeiq_app/features/webhooks/presentation/webhooks_screen.dart';

import 'console_desk_harness.dart';

/// ── NOTHING IS CUT, AT ANY SUPPORTED WIDTH ─────────────────────────────
///
/// > *"On `/orders` at ~2000 logical px the owner's screenshot shows row
/// > amounts cut mid-glyph (`R 2,350.7…`, `R 30,723.4…`)… Nothing may be
/// > clipped at any width. A row that cannot fit wraps, ellipsises
/// > deliberately, or the column gets the width it needs — it does not get
/// > silently cut."*
///
/// The eyeball cannot hold that promise and a golden cannot either: a golden
/// fails when a pixel moves, which is most changes, and it says nothing about
/// *why*. So this is the invariant, stated and measured on the real frames.
///
/// ## WHAT IT ACTUALLY CHECKS, AND WHY IT IS NOT "FIND THE WORD"
///
/// Flutter cuts text in two different ways and only one of them is loud.
///
/// 1. **Overflow.** A `RenderBox` whose child is bigger than its constraints
///    paints the yellow-and-black barber pole in debug and reports it to
///    `FlutterError`. `tester.takeException()` catches that, and every pump
///    here asserts it is null — which is what `2.0x: the structure survives
///    and nothing overflows` already does on the phone, at desk widths.
///
/// 2. **Silent clipping, which is the defect the owner photographed.** A
///    `ListView` clips to its viewport; a child laid out *wider than* that
///    viewport is simply trimmed, with no overflow, no exception and no
///    marking. `TorchBleed` did exactly this — before the fix the row was
///    864dp inside a 784dp viewport — and nothing in the suite noticed for a
///    fortnight.
///
/// The second needs its own measurement, and the honest one is geometric:
/// **walk every `RenderBox` under each scroll viewport and assert its painted
/// rectangle is inside that viewport's.** A bleed that gives back exactly what
/// the frame spent lands on the boundary and passes; a bleed that gives back
/// the window's gutter inside a pane sticks out and fails, naming the widget
/// and the overhang in dp.
///
/// It is deliberately about **boxes rather than glyphs**: a `RenderParagraph`
/// inside a row that is itself outside the viewport is the thing a reader
/// sees cut, and finding it by its box finds it before anyone has to read the
/// text. Text that chooses to ellipsise is *not* a failure — it is one of the
/// three outcomes the brief allows — and an ellipsis never leaves its box, so
/// this check passes it and fails the one that does not.
///
/// ## The widths
///
/// Every approved desk width, the two phones, the threshold itself and one
/// pixel either side of it, and 2000 — the owner's own window, where the
/// defect was photographed.
void main() {
  final night = TiqSkin.night();
  final day = TiqSkin.day();

  setUpAll(loadDeskFonts);

  const widths = <Size>[
    Size(1212, 900), // the threshold exactly
    Size(1211, 900), // one pixel under it: the phone arm
    Size(1280, 900),
    Size(1366, 768),
    Size(1440, 900),
    Size(1920, 1080),
    Size(2000, 1100), // the owner's window
    Size(2560, 1440),
    Size(390, 844),
    Size(360, 640),
  ];

  for (final (skinName, skin) in <(String, TiqSkin)>[
    ('night', night),
    ('day', day),
  ]) {
    for (final size in widths) {
      final at = '${size.width.toInt()}×${size.height.toInt()} $skinName';

      testWidgets('Exceptions: nothing is cut at $at', (tester) async {
        await pumpDesk(
          tester,
          const AlertsScreen(),
          size: size,
          skin: skin,
          path: '/alerts',
          overrides: deskAlertOverrides(),
          users: deskPeople(),
        );
        expect(tester.takeException(), isNull);
        expectNothingClipped(tester, at: 'Exceptions at $at');
      });

      testWidgets('Webhooks: nothing is cut at $at', (tester) async {
        await pumpDesk(
          tester,
          const WebhooksScreen(),
          size: size,
          skin: skin,
          path: '/webhooks',
          overrides: deskWebhookOverrides(),
        );
        expect(tester.takeException(), isNull);
        expectNothingClipped(tester, at: 'Webhooks at $at');
      });

      testWidgets('Trends: nothing is cut at $at', (tester) async {
        await pumpDesk(
          tester,
          const TrendsScreen(),
          size: size,
          skin: skin,
          path: '/trends',
          overrides: deskTrendOverrides(),
        );
        expect(tester.takeException(), isNull);
        expectNothingClipped(tester, at: 'Trends at $at');
      });
    }
  }

  // ── AND THE ONE THAT WOULD HAVE CAUGHT IT ────────────────────────────
  //
  // A guard is only worth having if it fails on the defect it is named for.
  // This reproduces the old arrangement directly — a bleed that gives back
  // more than the frame spent — and asserts the walk reports it, so the check
  // cannot quietly become a check of nothing.
  testWidgets('the walk fails on a row laid out wider than its pane', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 400,
            height: 300,
            child: ListView(
              children: const <Widget>[
                // 80dp wider than the viewport, centred: 40 out of each edge.
                // This is the real widget with the real number — a frame that
                // spent nothing handing back the window's `2 × gutterWide`,
                // which is precisely what every console screen used to do
                // inside a pane.
                TorchBleed(extra: 80, child: SizedBox(height: 100)),
              ],
            ),
          ),
        ),
      ),
    );
    expect(
      () => expectNothingClipped(tester, at: 'the control'),
      throwsA(isA<TestFailure>()),
    );
  });

  test('the derivation this file guards', () {
    for (final skin in <TiqSkin>[night, day]) {
      // ignore: avoid_print
      print(
        'CLIPPING GUARD: paneGutter ${ConsoleDesk.paneGutter}, detail pane '
        '${ConsoleDesk.detailWidth(skin)}, threshold '
        '${ConsoleDesk.deskMinWidth(skin)}. A bleed gives back 2 × the gutter '
        'the enclosing frame published, so a row lands exactly on its pane\'s '
        'edges and never past them.',
      );
    }
  });
}

/// Walk every scroll viewport in the tree and assert nothing it paints is
/// outside it. See the file comment.
void expectNothingClipped(WidgetTester tester, {required String at}) {
  final offenders = <String>[];

  for (final element in find.byType(Viewport).evaluate()) {
    final viewport = element.renderObject! as RenderViewport;
    final origin = viewport.localToGlobal(Offset.zero);
    final bounds = origin & viewport.size;
    // THE CROSS AXIS, AND ONLY THE CROSS AXIS. A list is *meant* to run past
    // its viewport on the scroll axis — that is what scrolling is, and the
    // console's filter rails are horizontal lists that deliberately continue
    // off the right edge to say there is more. What a reader sees as *cut* is
    // content past the edge it can never scroll to.
    final vertical = axisDirectionToAxis(viewport.axisDirection) == Axis.vertical;

    void walk(RenderObject node) {
      node.visitChildren((child) {
        // DO NOT DESCEND INTO A NESTED VIEWPORT. The console's filter rails
        // are horizontal lists inside the vertical pane, and a chip four
        // chips along is past the pane's right edge *and clipped by the rail
        // it is in* — which is a rail that scrolls, not a chip that is cut.
        // The rail's own box is still checked against the pane above, and the
        // rail gets its own pass in the loop outside.
        if (child is RenderAbstractViewport) return;
        if (child is RenderBox && child.hasSize && child.attached) {
          final rect = child.localToGlobal(Offset.zero) & child.size;
          final before = vertical
              ? bounds.left - rect.left
              : bounds.top - rect.top;
          final after = vertical
              ? rect.right - bounds.right
              : rect.bottom - bounds.bottom;
          final extent = vertical ? child.size.width : child.size.height;
          if ((before > 0.01 || after > 0.01) && extent > 0) {
            final edges = vertical
                ? ('the left', 'the right')
                : ('the top', 'the bottom');
            offenders.add(
              '${child.runtimeType} at ${rect.left.toStringAsFixed(1)},'
              '${rect.top.toStringAsFixed(1)} '
              '${rect.width.toStringAsFixed(1)}×${rect.height.toStringAsFixed(1)} '
              'in a ${vertical ? "vertical" : "horizontal"} viewport of '
              '${bounds.left.toStringAsFixed(1)},${bounds.top.toStringAsFixed(1)} '
              '${bounds.width.toStringAsFixed(1)}×'
              '${bounds.height.toStringAsFixed(1)} — '
              '${before > 0.01 ? "${before.toStringAsFixed(1)}dp off ${edges.$1}" : ""}'
              '${before > 0.01 && after > 0.01 ? ", " : ""}'
              '${after > 0.01 ? "${after.toStringAsFixed(1)}dp off ${edges.$2}" : ""}',
            );
            return; // one report per subtree, not one per glyph
          }
        }
        walk(child);
      });
    }

    walk(viewport);
  }

  expect(
    offenders,
    isEmpty,
    reason:
        'Content is laid out past the edge of the scroll view that clips it, '
        'so it is cut on screen with no overflow warning — $at:\n'
        '  ${offenders.join("\n  ")}\n'
        'This is the defect the owner photographed on /orders. The cause is '
        'almost always a TorchBleed giving back a gutter the enclosing frame '
        'did not spend; see TorchGutter.',
  );
}
