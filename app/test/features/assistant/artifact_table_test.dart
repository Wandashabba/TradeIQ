import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/assistant/data/artifact_repository.dart';
import 'package:tradeiq_app/features/assistant/view_specs/artifact_table.dart';

ArtifactDetail detail({
  required String type,
  required Map<String, dynamic> data,
  Map<String, dynamic> params = const {},
}) => ArtifactDetail(
  id: 'a1',
  type: type,
  toolName: type == 'trend_chart' ? 'getMetricTrend' : 'getStockLevels',
  params: params,
  data: data,
  canUndo: false,
);

void main() {
  group('trend table', () {
    test('carries value, baseline and both deltas', () async {
      final table = artifactTableFor(detail(
        type: 'trend_chart',
        data: const {
          'metric': 'availability',
          'points': [
            {'period': '2026-08-01', 'value': 93.0},
          ],
          'comparison': {
            'label': 'the month before',
            'points': [
              {'period': '2026-07-01', 'value': 88.0},
            ],
          },
        },
      ))!;

      expect(table.compared, isTrue);
      expect(table.columns, ['Period', 'Value', 'the month before', 'Change']);
      final row = table.rows.single;
      // Dates are formatted once, here, so the report and the screen name the
      // same bucket the same way.
      expect(row.cells[0], '1 Aug');
      expect(row.cells[1], '93%');
      // The comparison cell names its OWN bucket: the two series are aligned by
      // position, not by date, and the reader is entitled to see which row they
      // are being shown.
      expect(row.cells[2], '88% · 1 Jul');
      expect(row.delta, closeTo(5.0, 0.001));
      expect(row.deltaPct, closeTo(5.68, 0.01));
    });

    test('reports no percentage when the baseline was zero', () async {
      // "Up from nothing" has no percentage. Infinity, 0 and 100 would each be
      // a different lie.
      final table = artifactTableFor(detail(
        type: 'trend_chart',
        data: const {
          'points': [
            {'period': '2026-08-01', 'value': 4.0},
          ],
          'comparison': {
            'label': 'last year',
            'points': [
              {'period': '2025-08-01', 'value': 0.0},
            ],
          },
        },
      ))!;

      expect(table.rows.single.delta, 4.0);
      expect(table.rows.single.deltaPct, isNull);
    });

    test('has no comparison columns when nothing was compared', () async {
      final table = artifactTableFor(detail(
        type: 'trend_chart',
        data: const {
          'points': [
            {'period': '2026-08-01', 'value': 4.0},
          ],
        },
      ))!;

      expect(table.compared, isFalse);
      expect(table.columns, ['Period', 'Value']);
      expect(table.rows.single.delta, isNull);
    });

    test('aligns the two series by position when they differ in length', () async {
      // A month with 31 buckets against one with 28 is the normal case, and a
      // bucket with no visits produces no point at all — so nth-against-nth is
      // the only alignment available.
      final table = artifactTableFor(detail(
        type: 'trend_chart',
        data: const {
          'points': [
            {'period': '2026-08-01', 'value': 10.0},
            {'period': '2026-08-02', 'value': 20.0},
            {'period': '2026-08-03', 'value': 30.0},
          ],
          'comparison': {
            'label': 'before',
            'points': [
              {'period': '2026-07-01', 'value': 1.0},
              {'period': '2026-07-02', 'value': 2.0},
            ],
          },
        },
      ))!;

      expect(table.rows, hasLength(3));
      // First against first, last against last, and the middle interpolated to
      // the nearest — never off the end of the shorter series.
      expect(table.rows.first.delta, 9.0);
      expect(table.rows.last.delta, 28.0);
    });

    test('skips a row it cannot read rather than plotting it as zero', () async {
      final table = artifactTableFor(detail(
        type: 'trend_chart',
        data: const {
          'points': [
            {'period': '2026-08-01', 'value': 'not a number'},
            'not even a map',
            {'period': '2026-08-02', 'value': 74.0},
          ],
        },
      ))!;

      expect(table.rows, hasLength(1));
      expect(table.rows.single.cells[1], '74');
    });
  });

  group('pillar table', () {
    test('shows the baseline the inline pill cannot carry', () async {
      // "Up 5.1" and "88.0 → 93.1" answer different questions, and the second
      // is the one that replaces lining two exports up in a spreadsheet.
      final table = artifactTableFor(detail(
        type: 'pillar_metrics',
        data: const {
          'osaPct': 93.1,
          'outOfStockLines': 24,
          'comparison': {
            'label': 'the month before',
            'values': {'osaPct': 88.0, 'outOfStockLines': 30},
            'deltas': {
              'osaPct': {'absolute': 5.1, 'pct': 5.8},
              'outOfStockLines': {'absolute': -6, 'pct': -20},
            },
          },
        },
      ))!;

      expect(table.columns, ['Figure', 'Value', 'the month before', 'Change']);
      expect(table.rows.first.cells, ['On-shelf availability', '93.1%', '88.0%']);
      expect(table.rows.first.delta, 5.1);
      // Integers stay integers: "24 lines", not "24.0 lines".
      expect(table.rows[1].cells[1], '24');
      expect(table.rows[1].delta, -6);
    });

    test('labels a metric it has never heard of instead of hiding it', () async {
      final table = artifactTableFor(detail(
        type: 'pillar_metrics',
        data: const {'newFangledScore': 7},
      ))!;

      expect(table.rows.single.cells.first, 'New fangled score');
    });

    test('ignores values that are not finite numbers', () async {
      // A tool result carries rows and flags too, and a stray boolean rendered
      // as a metric is worse than an absent one.
      final table = artifactTableFor(detail(
        type: 'pillar_metrics',
        data: const {
          'osaPct': 90.0,
          'truncated': false,
          'worstOutlets': [1, 2],
          'label': 'text',
        },
      ))!;

      expect(table.rows, hasLength(1));
      expect(table.rows.single.cells.first, 'On-shelf availability');
    });
  });

  test('a spec with no meaningful table says so, rather than inventing one', () {
    // A table of pin coordinates is not the "table-view twin" the design
    // system means by the term — it is filler.
    expect(artifactTableFor(detail(type: 'outlet_map', data: const {})), isNull);
    expect(
      artifactTableFor(detail(type: 'agent_scorecard', data: const {})),
      isNull,
    );
  });
}
