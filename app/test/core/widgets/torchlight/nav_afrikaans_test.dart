import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';

import 'torch_harness.dart';

/// AFRIKAANS IN THE NAV BAR.
///
/// The bar is the one place in the app where a label cannot wrap, cannot
/// shrink and cannot ellipsise: four destinations share 252dp at 360dp once the
/// insets and the circle are drawn, which is 63dp each. So it measures.
///
/// These are the app's own strings, taken from `lib/l10n/app_af.arb`:
///
/// | en | af |
/// |---|---|
/// | Today | Vandag |
/// | Your work | Jou werk |
/// | Map | Kaart |
/// | Me | Ek |
///
/// The rule under test is **all or nothing**. A bar with three labels and one
/// glyph is a bar that has taught the reader two different things about what a
/// slot is, and the one it dropped is always the longest word — which is to say
/// always the same language.
const afrikaansSlots = <TorchNavSlot>[
  TorchNavSlot(
    icon: Icons.today_outlined,
    activeIcon: Icons.today,
    label: 'Vandag',
  ),
  TorchNavSlot(
    icon: Icons.inventory_2_outlined,
    activeIcon: Icons.inventory_2,
    label: 'Jou werk',
  ),
  TorchNavSlot(icon: Icons.map_outlined, activeIcon: Icons.map, label: 'Kaart'),
  TorchNavSlot(
    icon: Icons.person_outline,
    activeIcon: Icons.person,
    label: 'Ek',
  ),
];

/// The same four destinations with labels short enough to fit. Not a
/// translation — a control, so the test can tell "the bar never shows labels"
/// from "the bar measured these and dropped them".
const shortSlots = <TorchNavSlot>[
  TorchNavSlot(icon: Icons.today_outlined, activeIcon: Icons.today, label: 'A'),
  TorchNavSlot(
    icon: Icons.inventory_2_outlined,
    activeIcon: Icons.inventory_2,
    label: 'B',
  ),
  TorchNavSlot(icon: Icons.map_outlined, activeIcon: Icons.map, label: 'C'),
  TorchNavSlot(
    icon: Icons.person_outline,
    activeIcon: Icons.person,
    label: 'D',
  ),
];

Future<void> pumpBar(
  WidgetTester tester, {
  required List<TorchNavSlot> slots,
  double width = 360,
  double textScale = 1.0,
  Locale locale = const Locale('af'),
}) => pumpTorch(
  tester,
  skin: TiqSkin.night(density: TiqDensity.field),
  size: Size(width, 720),
  textScale: textScale,
  locale: locale,
  navRenders: true,
  tabbedRoute: true,
  child: Align(
    alignment: Alignment.bottomCenter,
    child: Padding(
      // The real inset, and the real space the 64dp circle takes beside it.
      padding: const EdgeInsets.fromLTRB(16, 0, 16 + 64 + 12, 20),
      child: TorchNavPill(slots: slots, activeIndex: 0, onSelect: (_) {}),
    ),
  ),
);

void main() {
  test('the measurement discriminates — it is not a constant', () {
    // Guards the whole file: if the bar simply never drew labels, every
    // assertion below would pass for the wrong reason.
    expect(shortSlots.length, afrikaansSlots.length);
  });

  testWidgets('a label that fits its slot is drawn', (tester) async {
    await pumpBar(tester, slots: shortSlots);
    for (final slot in shortSlots) {
      expect(find.text(slot.label), findsOneWidget);
    }
  });

  testWidgets('Afrikaans at 360dp drops every label, not the long one', (
    tester,
  ) async {
    await pumpBar(tester, slots: afrikaansSlots);
    for (final slot in afrikaansSlots) {
      expect(
        find.text(slot.label),
        findsNothing,
        reason:
            '"${slot.label}" went with the rest. Icon-only is a property of '
            'the bar, never of a slot.',
      );
    }
    expect(find.byType(TorchGlyph), findsNWidgets(4));
  });

  testWidgets('one long label takes the other three with it', (tester) async {
    await pumpBar(
      tester,
      slots: <TorchNavSlot>[
        ...shortSlots.take(3),
        // "Kompetisies" is the failure case the ruling names by name.
        const TorchNavSlot(
          icon: Icons.person_outline,
          activeIcon: Icons.person,
          label: 'Kompetisies',
        ),
      ],
    );
    expect(find.text('A'), findsNothing);
    expect(find.text('B'), findsNothing);
    expect(find.text('C'), findsNothing);
    expect(find.text('Kompetisies'), findsNothing);
    expect(
      find.byType(TorchGlyph),
      findsNWidgets(4),
      reason: 'never a mixed bar, and never a two-row grid',
    );
  });

  testWidgets('a wider screen gives the same labels back', (tester) async {
    await pumpBar(tester, slots: afrikaansSlots, width: 720);
    for (final slot in afrikaansSlots) {
      expect(
        find.text(slot.label),
        findsOneWidget,
        reason:
            'the decision is measured against the slot it actually has, so a '
            'tablet keeps the words a phone could not fit',
      );
    }
  });

  testWidgets('icon-only keeps every word a screen reader needs', (
    tester,
  ) async {
    await pumpBar(tester, slots: afrikaansSlots);
    final handle = tester.ensureSemantics();
    for (var i = 0; i < afrikaansSlots.length; i++) {
      expect(
        find.bySemanticsLabel('${afrikaansSlots[i].label}, tab ${i + 1} of 4'),
        findsOneWidget,
        reason:
            'dropping a label is a layout decision and never an accessibility '
            'one — the word is still there, it is simply not painted',
      );
    }
    expect(
      tester.getSemantics(find.bySemanticsLabel('Vandag, tab 1 of 4')),
      isSemantics(isSelected: true),
    );
    handle.dispose();
  });

  testWidgets('Afrikaans at 1.3× is the case that made this a rule', (
    tester,
  ) async {
    // The ruling's own arithmetic: at the 1.3× common on cheap Androids,
    // every label in the bar overflows at once.
    await pumpBar(tester, slots: afrikaansSlots, textScale: 1.3);
    for (final slot in afrikaansSlots) {
      expect(find.text(slot.label), findsNothing);
    }
  });
}
