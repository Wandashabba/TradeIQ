import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/torch_scope.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';

import '../core/design/amber_golden.dart';
import 'agent_harness.dart' show scrollAgentTo;

/// TEXT GOLDENS FOR THE TWO MIGRATED AGENT ROUTES.
///
/// Text, not PNGs, for the reason §9b already gives: CI runs `flutter test`
/// on `ubuntu-latest` while the repo is developed on macOS, and an image
/// golden that disagrees across platforms gets skipped within a week. What
/// the design rules are a set of **declared values** — a gutter, a row
/// height, a border width, how many things are lit — and a text golden names
/// the one that moved.
///
/// The thing a PNG would catch, a screen painting something nobody declared,
/// is caught by the amber census, which walks the real pixels for the
/// property that matters most. The census result is a line in here too.
///
/// Regenerate with `UPDATE_AGENT_GOLDENS=1 flutter test`, and read the diff.

/// One measured fact about a composed frame.
typedef GoldenLine = MapEntry<String, String>;

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// The facts every agent route declares, measured off the pumped frame.
///
/// [bringIntoView], when given, is scrolled to **after** the header has been
/// measured and before the census. Today needs it: its commit action is just
/// past the fold on a 360×640 phone and the census counts the composed frame,
/// but the header is a child of the same one scroll view and scrolling first
/// unmounts it — which is how three header lines went silently missing from
/// the first cut of these goldens.
Future<List<GoldenLine>> measureAgentFrame(
  WidgetTester tester, {
  required TiqSkin skin,
  Finder? bringIntoView,
}) async {
  final lines = <GoldenLine>[];

  void add(String k, Object v) => lines.add(GoldenLine(k, '$v'));

  add('skin', skin.mode.name);
  add('density', skin.density.name);
  add('ground', _hex(skin.palette.ground));
  add('gutter', skin.space.gutter);
  add('border.width', skin.depth.borderWidth);
  add('shadows', skin.depth.shadows.length);
  add('row.min', skin.space.rowMinHeight);
  add('target.min', skin.space.tapTarget);
  add('motion', skin.motion.enabled ? 'on' : 'off');

  // The header, at rest — the top of the scroll view is where it lives.
  final header = find.byType(TorchAppHeader);
  if (header.evaluate().isNotEmpty) {
    final h = tester.widget<TorchAppHeader>(header.first);
    add('header.trailing', h.trailing == null ? 'none' : 'skin-cycle');
    // WHERE the sync chip is, not only that it exists. The shell's anatomy
    // pins it right of the title row; it spent a release in the flag-chip
    // wrap, where it took a 48dp row plus a 16dp gap of its own on every
    // agent screen and nothing measured said so.
    add('header.status', h.status == null ? 'none' : 'title-row');
    add('header.chips', h.flagChips.length);
    add('header.height', tester.getRect(header.first).height.round());
  }

  if (bringIntoView != null) {
    await scrollAgentTo(tester, bringIntoView);
  }

  // The bottom region: a tab root has a nav pill and no thumb zone; every
  // other screen has a thumb zone and no nav. The two are alternatives, not
  // layers, and this is where that shows up as a measured fact.
  final navs = find.byType(TorchNavPill);
  final zones = find.byType(TorchThumbZone);
  add('nav.pill', navs.evaluate().isEmpty ? 'absent' : 'present');
  add('thumb.zone', zones.evaluate().isEmpty ? 'absent' : 'present');
  if (navs.evaluate().isNotEmpty) {
    final r = tester.getRect(navs.first);
    add('nav.height', r.height.round());
    add('nav.docked', r.width.round() == 360 ? 'yes' : 'no');
    // ── SHAPE A, PINNED — 4 October 2026 ────────────────────────────────
    //
    // Three lines, because three things about the bar changed and all three
    // are the kind of thing that comes back by accident when somebody
    // "restores" a style.
    //
    // 1. NO OUTLINE ANYWHERE UNDER THE BAR. The pill carried a 1px
    //    `edgeStructure` border and the active tab's block carried the
    //    radius; a `Border` under this subtree now means one of them is back.
    final bordered = tester
        .widgetList<Widget>(
          find.descendant(of: navs.first, matching: find.byType(DecoratedBox)),
        )
        .whereType<DecoratedBox>()
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.border != null)
        .length;
    final animatedBordered = tester
        .widgetList<AnimatedContainer>(
          find.descendant(
            of: navs.first,
            matching: find.byType(AnimatedContainer),
          ),
        )
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.border != null)
        .length;
    add('nav.outlines', bordered + animatedBordered);
    // 2. NO GRADIENT ANYWHERE UNDER THE BAR. The lit tab was a linear ramp
    //    and the Abyssal form was a two-identical-stop companion; a 24x2dp
    //    edge is flat.
    final gradients = tester
        .widgetList<AnimatedContainer>(
          find.descendant(
            of: navs.first,
            matching: find.byType(AnimatedContainer),
          ),
        )
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.gradient != null)
        .length;
    add('nav.gradients', gradients);
    // 3. WHICH CUE NAMES THE ACTIVE TAB, read off the allocator rather than
    //    off a pixel, because the rule is the thing being pinned: Night
    //    granted gets the amber edge, Day and anything beneath a sheet get
    //    the `well` groove. `getInheritedWidgetOfExactType` does not
    //    register a dependency, which is what makes it legal outside build.
    final scope = tester
        .element(navs.first)
        .getInheritedWidgetOfExactType<TorchScope>();
    final litTab =
        scope?.allocation.isLit(TorchScope.navActiveTabId) ?? false;
    add('nav.tab.cue', litTab ? 'amber-edge' : 'well-groove');
  }
  if (zones.evaluate().isNotEmpty) {
    final r = tester.getRect(zones.first);
    add('zone.height', r.height.round());
  }

  // WHERE THE SKIN CONTROL IS ON THIS SCREEN.
  //
  // It read `isEmpty ? 'header' : 'thumb-zone'` — a tab root's header carried
  // a `TorchIconButton` rather than a `TorchSkinCycle`, so "not found" meant
  // "in the header". That inference stopped being true on 4 October 2026,
  // when the control left the four title rows for Me's `THIS APP` block, and
  // a golden line that quietly keeps saying `header` is worse than no line.
  //
  // So it is measured in three states now, and `none` is a real answer: a tab
  // root has no thumb zone and no trailing control, and the way to the
  // preference is the Me tab.
  add(
    'skin.cycle',
    find.byType(TorchSkinCycle).evaluate().isNotEmpty
        ? 'thumb-zone'
        : (header.evaluate().isNotEmpty &&
                  tester.widget<TorchAppHeader>(header.first).trailing != null
              ? 'header'
              : 'none'),
  );

  // ── THE FADE AND THE BACK SHADE — 4 October 2026 ──────────────────────
  //
  // `body.fade` is the 24dp scrim over the body's own last `TiqSpace.s6`,
  // which shape A needs because the bar no longer has a material for the
  // clip to stop against. `wash` counts the shell's backdrop decorations:
  // two on Night (Dawn's hot breath and its clay) and one on Day, which has
  // no hot breath. Zero on a screen with no wash, which is every agent
  // screen that is not a tab root.
  add(
    'body.fade',
    find.byKey(const ValueKey<String>('torch-band-scrim')).evaluate().isEmpty
        ? 'absent'
        : 'present',
  );
  final shells = find.byType(TorchShell);
  if (shells.evaluate().isNotEmpty) {
    add('wash', tester.widget<TorchShell>(shells.first).backdrop.length);
  }

  // The primary: its height and whether it is armed. A disabled primary is
  // not a dimmed armed one — it declares nothing and it emits nothing.
  final primaries = find.byType(TorchPrimaryButton);
  if (primaries.evaluate().isNotEmpty) {
    final p = tester.widget<TorchPrimaryButton>(primaries.first);
    add('primary.armed', p.onPressed != null ? 'yes' : 'no');
    add('primary.blocked.named', p.blockedReason != null ? 'yes' : 'no');
    add('primary.height', tester.getRect(primaries.first).height.round());
  } else {
    add('primary', 'none');
  }

  // Rows ON SCREEN, not rows declared: the body is one lazy scroll view, so
  // this is a fact about the composed frame at rest. The names and the order
  // of the whole ladder are `audit_shell_client_questions_test`'s job.
  add('rows.onscreen', find.byType(SoftRow).evaluate().length);

  // The census, on the real pixels of this exact frame.
  //
  // THE BOUNDS ARE RECORDED NOW, NOT ONLY THE COUNT — 4 October 2026. Shape A
  // replaced a filled 48dp-tall active tab with a 24x2dp edge, which is a
  // change no count can see: both are one connected region. The audit
  // question "did the amber move" needs the geometry, so the geometry is in
  // the golden. Sorted by position rather than by area, so a region that
  // grows does not reorder the list and make a one-line change read as two.
  final census = await amberCensus(tester);
  add('amber.objects', census.objectCount);
  final bounds = census.regions
      .map(
        (r) =>
            '${r.bounds.width.toInt()}x${r.bounds.height.toInt()}'
            '@${r.bounds.left.toInt()},${r.bounds.top.toInt()}',
      )
      .toList()
    ..sort();
  add('amber.bounds', bounds.isEmpty ? 'none' : bounds.join(' '));

  return lines;
}

/// Compare [lines] against `test/features/goldens/<name>.txt`, or write it.
void expectAgentGolden(List<GoldenLine> lines, String name) {
  final text = <String>[
    '# $name',
    '# Regenerate: UPDATE_AGENT_GOLDENS=1 flutter test',
    '',
    for (final l in lines) '${l.key} = ${l.value}',
    '',
  ].join('\n');

  final file = File('test/features/goldens/$name.txt');
  if (Platform.environment['UPDATE_AGENT_GOLDENS'] == '1') {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(text);
    return;
  }

  expect(
    file.existsSync(),
    isTrue,
    reason:
        'test/features/goldens/$name.txt is missing. Run with '
        'UPDATE_AGENT_GOLDENS=1 to write it, then read the diff before '
        'committing it.',
  );
  expect(
    file.readAsStringSync(),
    text,
    reason:
        'The declared shape of $name moved. Every line in this file is a '
        'value the design document names — a gutter, a row height, a border '
        'width, which bottom region applies, how many objects are lit. If the '
        'change is intended, regenerate with UPDATE_AGENT_GOLDENS=1 and say '
        'in the PR which rule moved and why.',
  );
}
