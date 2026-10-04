/// THE DENSITY TABLE — every repeated agent element beside the manager's.
///
/// This file exists because the question *"is the agent side bigger than the
/// manager side, and by how much"* was being answered by looking at it. Three
/// separate readings were offered and two of them were wrong: that agent store
/// rows "run roughly 85dp" against a manager row of "44–48", and that agent
/// headlines "reach the display role where the manager uses `titleL`". The
/// first is right about the pitch and wrong about which number it is; the
/// second is not a density difference at all. Both are recorded in the table
/// below as measured rather than as claimed.
///
/// It measures two different kinds of thing and keeps them apart on purpose.
///
/// **Declared geometry** is a pure function of the skin — `TorchAppHeader`'s
/// floor, a stat tile's inset, a chip's visual height. Those are resolved here
/// for both densities with no widget pumped, because a number that can be
/// asserted without a frame should be.
///
/// **Composed geometry** is what a row actually measures on a real screen at a
/// real width, which is the only way to settle a pitch: a 64dp row floor with
/// a two-line text column and a 12dp gap after it is not 64dp of screen, and
/// the floor is the one number a reader of the source sees.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';
import 'package:tradeiq_app/core/widgets/torchlight/figure/chart/chart_series.dart';
import 'package:tradeiq_app/core/widgets/torchlight/figure/meter.dart';
import 'package:tradeiq_app/core/widgets/torchlight/figure/stat_tile.dart';
import 'package:tradeiq_app/core/widgets/torchlight/mark/tiq_chip.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';

/// One row of the table: what the element is, the console's number, the
/// agent's, and whether they now agree.
typedef Measured = ({String element, String property, Object console, Object field});

String _render(List<Measured> rows) {
  final b = StringBuffer()
    ..writeln()
    ..writeln('| element | property | manager (console) | agent (field) | same |')
    ..writeln('|---|---|---|---|---|');
  for (final r in rows) {
    final same = r.console.toString() == r.field.toString();
    b.writeln(
      '| ${r.element} | ${r.property} | ${r.console} | ${r.field} | '
      '${same ? 'yes' : '**no**'} |',
    );
  }
  return b.toString();
}

void main() {
  final console = TiqSkin.day(density: TiqDensity.console);
  final field = TiqSkin.day(density: TiqDensity.field);

  group('the declared table', () {
    test('every density-branching element is measured and printed', () {
      final rows = <Measured>[
        (
          element: 'TorchAppHeader',
          property: 'minHeight',
          console: TorchAppHeader.minHeightFor(console),
          field: TorchAppHeader.minHeightFor(field),
        ),
        (
          element: 'StatTile',
          property: 'inset',
          console: StatTile.insetFor(console),
          field: StatTile.insetFor(field),
        ),
        (
          element: 'StatTile',
          property: 'minHeight',
          console: StatTile.minHeightFor(console),
          field: StatTile.minHeightFor(field),
        ),
        (
          element: 'TiqChip',
          property: 'visualHeight',
          console: TiqChip.visualHeight(console),
          field: TiqChip.visualHeight(field),
        ),
        (
          element: 'Meter',
          property: 'trackHeight',
          console: Meter.trackHeight(console),
          field: Meter.trackHeight(field),
        ),
        (
          element: 'trend chart',
          property: 'plotHeight @360dp',
          console: trendChartHeightFor(console, 360),
          field: trendChartHeightFor(field, 360),
        ),
        // The spacing scale, for the record: it is already one scale, so these
        // rows are the control group. If one of them ever reads "no", the
        // premise of this whole file has changed.
        (
          element: 'TiqSpace',
          property: 'gutter',
          console: console.space.gutter,
          field: field.space.gutter,
        ),
        (
          element: 'TiqSpace',
          property: 'rowMinHeight',
          console: console.space.rowMinHeight,
          field: field.space.rowMinHeight,
        ),
        (
          element: 'TiqSpace',
          property: 'blockGap',
          console: console.space.blockGap,
          field: field.space.blockGap,
        ),
        (
          element: 'TiqSpace',
          property: 'tapTarget',
          console: console.space.tapTarget,
          field: field.space.tapTarget,
        ),
        (
          element: 'TiqType',
          property: 'titleL.size',
          console: console.text.titleL.size,
          field: field.text.titleL.size,
        ),
        (
          element: 'TiqType',
          property: 'body.size',
          console: console.text.body.size,
          field: field.text.body.size,
        ),
        (
          element: 'TiqRadii',
          property: 'card',
          console: console.radii.card,
          field: field.radii.card,
        ),
        (
          element: 'TiqRadii',
          property: 'panel',
          console: console.radii.panel,
          field: field.radii.panel,
        ),
      ];

      // ignore: avoid_print
      print('AGENT/MANAGER DECLARED GEOMETRY${_render(rows)}');

      // THE ASSERTION. Every density-branching element now resolves to the
      // same number on both surfaces. This is the whole of the change this
      // file exists to hold: a reader who re-splits one of them fails here
      // with the element named, rather than discovering it in a screenshot
      // three releases later.
      for (final r in rows) {
        expect(
          r.field.toString(),
          r.console.toString(),
          reason:
              '${r.element}.${r.property} differs by density. The agent and '
              'the manager share one spacing scale and one type scale; a '
              'geometry branch on TiqDensity is a call-site choice and needs '
              'an argument in the source, not a number.',
        );
      }
    });
  });

  group('the soft row ladder', () {
    test('the three row densities are the same on both surfaces', () {
      final rows = <Measured>[
        for (final d in SoftRowDensity.values) ...<Measured>[
          (
            element: 'SoftRow.${d.name}',
            property: 'minHeight',
            console: SoftRowSpec.resolve(skin: console, density: d).minHeight,
            field: SoftRowSpec.resolve(skin: field, density: d).minHeight,
          ),
          (
            element: 'SoftRow.${d.name}',
            property: 'pitch (minHeight+gapAfter)',
            console: SoftRowSpec.resolve(skin: console, density: d).minHeight +
                SoftRowSpec.resolve(skin: console, density: d).gapAfter,
            field: SoftRowSpec.resolve(skin: field, density: d).minHeight +
                SoftRowSpec.resolve(skin: field, density: d).gapAfter,
          ),
        ],
      ];

      // ignore: avoid_print
      print('SOFT ROW LADDER${_render(rows)}');

      // The ladder never branched on density — 56/64/80 at both — so this is
      // a control group too, and it is the reason the row work in this change
      // is a change of **which rung a screen asks for** and not a change to
      // the rungs. Moving a rung would move the manager side, which is the
      // one thing that may not happen.
      for (final r in rows) {
        expect(r.field.toString(), r.console.toString());
      }
    });

    test('every rung clears the 44dp tap floor on both surfaces', () {
      for (final skin in <TiqSkin>[console, field]) {
        for (final d in SoftRowDensity.values) {
          final spec = SoftRowSpec.resolve(skin: skin, density: d);
          expect(
            spec.meetsTargetFloor(skin),
            isTrue,
            reason:
                'SoftRow.${d.name} at ${skin.density.name} is '
                '${spec.minHeight}dp, under the ${skin.space.tapTarget}dp '
                'floor. An agent works one-handed outdoors; the floor does '
                'not move.',
          );
        }
      }
    });
  });
}
