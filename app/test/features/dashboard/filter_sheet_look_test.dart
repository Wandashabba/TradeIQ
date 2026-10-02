import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/features/dashboard/data/dashboard_repository.dart';
import 'package:tradeiq_app/features/dashboard/presentation/dashboard_filters.dart';

import '../agent_harness.dart';
import 'floor_harness.dart';
import 'seeded_territories.dart';

/// THE SCOPE SHEET, RENDERED, SO SOMEBODY CAN LOOK AT IT.
///
/// Numbers do not tell you that a stripped label reads wrong. The whole
/// grouping rule turns on strings — `Gauteng North (Tshwane)` has to read
/// `North (Tshwane)` and `Eastern Cape – Buffalo City` has to read `Buffalo
/// City` and not `– Buffalo City` — and the first version of the
/// word-boundary trim produced `Cape – Buffalo City` on a run of tests that
/// were otherwise green. These images are how that was found.
///
/// Three states, because they are the three the redesign changed: **collapsed**
/// (what opens), **open** (a group expanded) and **chosen** (a child
/// selected, which is also what reopening on the current scope looks like).
/// Two phone widths, both skins, and the open state again at **1.3×** —
/// this sheet is a list and a list is where text scale bites.
///
/// It does not run in CI, for the reason `floor_look_test.dart` gives: CI
/// rasterises anti-aliased Schibsted Grotesk on `ubuntu-latest` and this
/// repository is developed on macOS, so a pixel comparison fails on the day it
/// lands. The pins are the measurements in `filter_groups_test.dart`, which
/// run everywhere. These are an artefact to look at.
///
/// ```sh
/// SCOPE_LOOK=1 SCOPE_LOOK_DIR=/somewhere/ flutter test \
///   test/features/dashboard/filter_sheet_look_test.dart --update-goldens
/// ```
void main() {
  final looking = Platform.environment['SCOPE_LOOK'] == '1';
  final dir = Platform.environment['SCOPE_LOOK_DIR'] ?? 'goldens/';

  setUpAll(loadAgentFonts);
  setUp(TorchSheets.resetForTest);

  /// Open the sheet on The Floor, in [state].
  ///
  /// `chosen` goes the long way round on purpose — pick the child, let the
  /// sheet close and apply, then reopen — because reopening on the group that
  /// holds the current scope is itself one of the things being looked at.
  Future<void> open(
    WidgetTester tester, {
    required Size size,
    required TiqSkin skin,
    required String state,
    double textScale = 1.0,
  }) async {
    await pumpFloorRoute(
      tester,
      size: size,
      skin: skin,
      textScale: textScale,
      current: kpis(osa: 61, execution: 72),
      previous: kpis(osa: 64, execution: 70),
      byTerritory: <String, DashboardKpis>{
        't-gp-tsh': kpis(osa: 44, execution: 51),
      },
      territories: seededTerritories,
    );
    await tester.tap(find.byKey(const ValueKey<String>('floor-scope-chip')));
    await tester.pumpAndSettle();
    if (state == 'collapsed') return;

    // The Eastern Cape is the group with no parent territory, so its heading
    // and all of its children come out of the name rule rather than off a
    // record. It is the one most likely to read wrong, so it gets its own
    // picture.
    final key = state == 'ec' ? 'territory-group-EC' : 'territory-group-GP';
    final gp = find.byKey(ValueKey<String>(key));
    await tester.ensureVisible(gp);
    await tester.pumpAndSettle();
    await tester.tap(gp);
    await tester.pumpAndSettle();
    if (state == 'open' || state == 'ec') return;

    final child = find.byKey(
      const ValueKey<String>('territory-option-t-gp-tsh'),
    );
    await tester.ensureVisible(child);
    await tester.pumpAndSettle();
    await tester.tap(child);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('floor-scope-chip')));
    await tester.pumpAndSettle();
  }

  /// What the sheet measures, printed beside the picture so the report and the
  /// render cannot disagree.
  void measure(WidgetTester tester, String name, Size size) {
    final skin = TiqSkin.night();
    final sheet = tester.getRect(find.byType(TorchSheet));
    final ceiling = size.height * TorchSheetSpec.maxHeightFractionValue;
    final chips = <String>[];
    for (final range in DashboardRange.values) {
      final finder = find.byKey(ValueKey<String>('scope-range-${range.name}'));
      if (finder.evaluate().isEmpty) {
        chips.add('${range.name}=NOT BUILT');
        continue;
      }
      final r = tester.getRect(finder);
      chips.add(
        '${range.name}=${r.left.toStringAsFixed(0)}..'
        '${r.right.toStringAsFixed(0)}@y${r.top.toStringAsFixed(0)}'
        '${r.right > size.width ? ' OFFSCREEN' : ''}',
      );
    }

    final first = find.byKey(const ValueKey<String>('territory-option-all'));
    final eyebrow = find.byType(Eyebrow);
    final rows = <String>[];
    for (final key in <String>[
      'territory-option-all',
      'territory-group-GP',
      'territory-option-t-gp',
      'territory-option-t-gp-eku',
      'territory-option-t-fs',
    ]) {
      final finder = find.byKey(ValueKey<String>(key));
      if (finder.evaluate().isEmpty) continue;
      final r = tester.getRect(finder);
      rows.add(
        '$key h=${r.height.toStringAsFixed(1)} '
        'l=${r.left.toStringAsFixed(1)} y=${r.top.toStringAsFixed(1)}',
      );
    }

    // ignore: avoid_print
    print(
      <String>[
        '',
        '=== $name ===',
        'sheet top=${sheet.top.toStringAsFixed(1)} '
            'h=${sheet.height.toStringAsFixed(1)} '
            'ceiling=${ceiling.toStringAsFixed(1)} '
            '${sheet.height >= ceiling - 0.5 ? 'AT CEILING (scrolls)' : 'fits'}',
        // THE HEADER'S COST, measured from the sheet's own top to the bottom
        // of the one-line header. Not to the first chip: once the sheet is at
        // its ceiling it scrolls, and a scrolled chip's `top` is a measurement
        // of the scroll offset rather than of the header.
        'header bottom = '
            '${(tester.getRect(find.byType(ScopeSheetHeader)).bottom - sheet.top).toStringAsFixed(1)}'
            '  (grabber zone + one line)',
        'gutter=${skin.space.gutter}  tapTarget=${skin.space.tapTarget}',
        if (eyebrow.evaluate().isNotEmpty)
          'eyebrow l=${tester.getRect(eyebrow.first).left.toStringAsFixed(1)}',
        if (first.evaluate().isNotEmpty)
          'first row l=${tester.getRect(first).left.toStringAsFixed(1)}',
        ...chips.map((c) => '  chip $c'),
        ...rows.map((r) => '  row $r'),
      ].join('\n'),
    );
  }

  for (final (sizeName, size) in <(String, Size)>[
    ('390x844', Size(390, 844)),
    ('360x640', Size(360, 640)),
  ]) {
    for (final (skinName, skin) in <(String, TiqSkin)>[
      ('night', _night),
      ('day', _day),
    ]) {
      for (final state in <String>['collapsed', 'open', 'ec', 'chosen']) {
        final name = '$sizeName-$state-$skinName';
        testWidgets('scope sheet $name', (tester) async {
          await open(tester, size: size, skin: skin, state: state);
          measure(tester, name, size);
          await expectLater(
            find.byKey(const ValueKey<String>('amber-golden-boundary')),
            matchesGoldenFile('${dir}scope_$name.png'),
          );
        }, skip: !looking);
      }

      // 1.3x, on the state with the most rows in it.
      final scaled = '$sizeName-open-1.3x-$skinName';
      testWidgets('scope sheet $scaled', (tester) async {
        await open(
          tester,
          size: size,
          skin: skin,
          state: 'open',
          textScale: 1.3,
        );
        measure(tester, scaled, size);
        await expectLater(
          find.byKey(const ValueKey<String>('amber-golden-boundary')),
          matchesGoldenFile('${dir}scope_$scaled.png'),
        );
      }, skip: !looking);
    }
  }
}

final TiqSkin _night = TiqSkin.night();
final TiqSkin _day = TiqSkin.day();
