import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/motion_budget.dart';
import 'package:tradeiq_app/core/design/tiq_number.dart';
import 'package:tradeiq_app/core/design/torch_scope.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/figure/chart/chart.dart';
import 'package:tradeiq_app/core/widgets/torchlight/figure/meter.dart';
import 'package:tradeiq_app/core/widgets/torchlight/figure/sparkline.dart';
import 'package:tradeiq_app/core/widgets/torchlight/mark/severity_mark.dart';
import 'package:tradeiq_app/features/assistant/data/chat_controller.dart';
import 'package:tradeiq_app/features/assistant/view_specs/ranked_bars_card.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

import '../../../features/agent_harness.dart' show loadAgentFonts;

/// EVERY FIGURE IN THE KIT, RENDERED, SO SOMEBODY CAN LOOK AT IT.
///
/// The owner's complaint about the charts was about *drawing quality* —
/// "rectangular and cartoonish" — and no assertion in `chart_test.dart`
/// measures that. This file produces the images the judgement is made on: the
/// trend chart with a comparison and a target, the same with a gap, the
/// sparkline, the meter at three values and the ranked bars, in Night and Day,
/// at 390×844, with **Onest and JetBrains Mono loaded** so the axis labels are
/// the typeface the app ships rather than the test font.
///
/// ## Why it does not run in CI
///
/// Exactly the reason `floor_look_test.dart` gives: CI rasterises anti-aliased
/// Onest on `ubuntu-latest` and this repository is developed on macOS, so a
/// pixel comparison fails on the day it lands and is skipped within a week.
/// These are artefacts to *look at*; the pins are the assertions in
/// `chart_test.dart` and `figures_test.dart`, which run everywhere.
///
/// Regenerate them with:
///
/// ```sh
/// CHART_LOOK=1 flutter test \
///   test/core/widgets/torchlight/figure_look_test.dart --update-goldens
/// ```
void main() {
  final looking = Platform.environment['CHART_LOOK'] == '1';

  setUpAll(loadAgentFonts);

  for (final (name, skin) in <(String, TiqSkin)>[
    ('night', TiqSkin.night()),
    ('day', TiqSkin.day()),
  ]) {
    testWidgets('$name: the trend chart, a comparison and a target', (
      tester,
    ) async {
      await _pump(tester, skin: skin, child: _trend(gapped: false));
      await _shoot(tester, 'goldens/figure_trend_$name.png');
    }, skip: !looking);

    testWidgets('$name: the trend chart with a week nobody measured', (
      tester,
    ) async {
      await _pump(tester, skin: skin, child: _trend(gapped: true));
      await _shoot(tester, 'goldens/figure_trend_gap_$name.png');
    }, skip: !looking);

    testWidgets('$name: sparklines', (tester) async {
      await _pump(tester, skin: skin, child: const _Sparklines());
      await _shoot(tester, 'goldens/figure_sparkline_$name.png');
    }, skip: !looking);

    testWidgets('$name: the meter at three values', (tester) async {
      await _pump(tester, skin: skin, child: const _Meters());
      await _shoot(tester, 'goldens/figure_meter_$name.png');
    }, skip: !looking);

    testWidgets('$name: the ranked bars', (tester) async {
      await _pump(tester, skin: skin, child: const _Ranked());
      await _shoot(tester, 'goldens/figure_ranked_$name.png');
    }, skip: !looking);
  }
}

// ── The fixtures ──────────────────────────────────────────────────────

const List<ChartReading> _run = <ChartReading>[
  ChartReading(label: 'W30', longLabel: '2026-W30', value: 64),
  ChartReading(label: 'W31', longLabel: '2026-W31', value: 61),
  ChartReading(label: 'W32', longLabel: '2026-W32', value: 68),
  ChartReading(label: 'W33', longLabel: '2026-W33', value: 66),
  ChartReading(label: 'W34', longLabel: '2026-W34', value: 74),
  ChartReading(label: 'W35', longLabel: '2026-W35', value: 71),
  ChartReading(label: 'W36', longLabel: '2026-W36', value: 79),
  ChartReading(label: 'W37', longLabel: '2026-W37', value: 83),
];

const List<ChartReading> _gapped = <ChartReading>[
  ChartReading(label: 'W30', longLabel: '2026-W30', value: 64),
  ChartReading(label: 'W31', longLabel: '2026-W31', value: 61),
  ChartReading(label: 'W32', longLabel: '2026-W32', value: 68),
  ChartReading(label: 'W33', longLabel: '2026-W33', value: null),
  ChartReading(label: 'W34', longLabel: '2026-W34', value: null),
  ChartReading(label: 'W35', longLabel: '2026-W35', value: 71),
  ChartReading(label: 'W36', longLabel: '2026-W36', value: 79),
  ChartReading(label: 'W37', longLabel: '2026-W37', value: 83),
];

const List<ChartReading> _average = <ChartReading>[
  ChartReading(label: 'W30', value: 70),
  ChartReading(label: 'W31', value: 70),
  ChartReading(label: 'W32', value: 71),
  ChartReading(label: 'W33', value: 72),
  ChartReading(label: 'W34', value: 72),
  ChartReading(label: 'W35', value: 73),
  ChartReading(label: 'W36', value: 73),
  ChartReading(label: 'W37', value: 74),
];

Widget _trend({required bool gapped}) => TrendChart(
  series: <ChartSeries>[
    ChartSeries(name: 'Gauteng North', readings: gapped ? _gapped : _run),
    const ChartSeries(
      name: 'Client average',
      role: ChartSeriesRole.comparison,
      readings: _average,
    ),
  ],
  unit: TiqUnit.percent,
  semanticsLabel: 'Execution score, eight weeks',
  notMeasuredWord: 'Not measured',
  dashedWord: 'dashed',
  threshold: const ChartThreshold(value: 75, label: 'Target 75'),
  gapNote: gapped ? '2 weeks not measured' : null,
  scrubHint: 'Drag across the chart to read a week.',
);

class _Sparklines extends StatelessWidget {
  const _Sparklines();

  @override
  Widget build(BuildContext context) {
    const runs = <(String, List<double>, SeverityMarkKind?)>[
      ('Rising', <double>[41, 44, 43, 48, 52, 51, 58, 63], null),
      ('Falling', <double>[78, 74, 76, 69, 65, 61, 58, 52], SeverityMarkKind.critical),
      ('Flat', <double>[60, 60, 60, 60, 60, 60, 60, 60], null),
      ('Noisy', <double>[30, 62, 38, 71, 44, 66, 40, 58], SeverityMarkKind.watch),
    ];
    final skin = context.skin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final (label, values, severity) in runs)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 60,
                  child: Text(
                    label,
                    style: skin.text.body.style(color: skin.palette.ink2),
                  ),
                ),
                Sparkline(points: values, severity: severity),
                const SizedBox(width: 16),
                // And again at four times the slot, so the stroke and the
                // endpoint can actually be inspected.
                SizedBox(
                  width: 160,
                  height: 50,
                  child: FittedBox(
                    fit: BoxFit.fill,
                    child: SizedBox(
                      width: Sparkline.slot.width,
                      height: Sparkline.slot.height,
                      child: Sparkline(points: values, severity: severity),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Meters extends StatelessWidget {
  const _Meters();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final (label, value, state) in <(String, double?, MeterState)>[
          ('On-shelf availability 34', 34, MeterState.filled),
          ('On-shelf availability 61', 61, MeterState.filled),
          ('On-shelf availability 92', 92, MeterState.filled),
          ('Thin sample 55', 55, MeterState.lowSample),
          ('Nobody sent a value', null, MeterState.missing),
        ]) ...<Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              label,
              style: skin.text.meta.style(color: skin.palette.ink3),
            ),
          ),
          Meter(value: value, target: 80, state: state),
          const SizedBox(height: 26),
        ],
      ],
    );
  }
}

class _Ranked extends StatelessWidget {
  const _Ranked();

  @override
  Widget build(BuildContext context) => RankedBarsCard(
    artifact: const ChatArtifact(
      id: 'a1',
      type: 'ranked_bars',
      params: <String, Object?>{},
      data: <String, Object>{
        'title': 'Change by territory',
        'comparedTo': "vs Aug '25",
        'unit': 'pct',
        'items': <Map<String, Object>>[
          <String, Object>{'label': 'Soweto', 'value': -31},
          <String, Object>{'label': 'Tembisa', 'value': -9},
          <String, Object>{'label': 'Sandton', 'value': 4},
          <String, Object>{'label': 'Pretoria East', 'value': 7},
          <String, Object>{'label': 'Flat', 'value': 0},
        ],
      },
    ),
  );
}

// ── The rig ───────────────────────────────────────────────────────────

const Key _boundary = ValueKey<String>('amber-golden-boundary');

Future<void> _pump(
  WidgetTester tester, {
  required TiqSkin skin,
  required Widget child,
}) async {
  const size = Size(390, 844);
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.torchlight(skin),
      locale: const Locale('en'),
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: MotionBudgetScope(
            budget: MotionBudget.frozen,
            child: RepaintBoundary(
              key: _boundary,
              child: ColoredBox(
                color: skin.palette.ground,
                child: SizedBox.fromSize(
                  size: size,
                  child: TorchScope(
                    skin: skin,
                    phase: 'look',
                    claims: const <TorchClaim>[],
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _shoot(WidgetTester tester, String path) async {
  await expectLater(find.byKey(_boundary), matchesGoldenFile(path));
}
