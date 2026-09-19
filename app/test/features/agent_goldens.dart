import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  }
  if (zones.evaluate().isNotEmpty) {
    final r = tester.getRect(zones.first);
    add('zone.height', r.height.round());
  }

  // The skin cycle is on every screen — on a tab root as the header's one
  // trailing icon button, elsewhere at the leading end of the thumb zone.
  add(
    'skin.cycle',
    find.byType(TorchSkinCycle).evaluate().isEmpty ? 'header' : 'thumb-zone',
  );

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
  // this is a fact about the composed frame at rest. A Veld hub with a taller
  // header and a taller thumb zone genuinely shows fewer rungs than a Night
  // one, and that is the kind of thing this file is for. The names and the
  // order of the whole ladder are `audit_shell_client_questions_test`'s job.
  add('rows.onscreen', find.byType(SoftRow).evaluate().length);

  // The census, on the real pixels of this exact frame.
  final census = await amberCensus(tester);
  add('amber.objects', census.objectCount);

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
