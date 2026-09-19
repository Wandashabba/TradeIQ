import 'dart:async';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../../core/design/figure_slot.dart';
import '../../../core/design/motion_budget.dart';
import '../../../core/design/tiq_number.dart';
import '../../../core/design/torch_scope.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/secondary_button.dart';
import '../../../core/widgets/torchlight/button/torch_button.dart';
import '../../../core/widgets/torchlight/button/torch_press.dart';
import '../../../core/widgets/torchlight/mark/tiq_mark.dart';
import '../../../l10n/l10n.dart';
import '../data/chat_controller.dart';
import 'answer_motion.dart';
import 'ask_light.dart';

/// Tool name → the step, in the manager's words.
///
/// `getShareOfShelf` is our vocabulary; "Share of shelf" is theirs. A tool this
/// build has never heard of falls back to its pillar ([stepLabel]), and never
/// to its function name.
const Map<String, String> toolStepLabels = {
  'getSalesPerformance': 'Sell-in',
  'getRateOfSale': 'Sell-in',
  'getSkuMovement': 'SKU movement',
  'getStockLevels': 'Stock on shelf',
  'getStockOnShelf': 'Stock on shelf',
  'getShareOfShelf': 'Share of shelf',
  'getVisibilityCompliance': 'Visibility compliance',
  'getCompetitorActivity': 'Competitor activity',
  'getVisitHistory': 'Visit history',
  'getFraudFlags': 'Flagged visits',
  'getAgentScorecard': 'Agent scorecard',
  'getMetricTrend': 'Trend over time',
  'getTerritoryRanking': 'Territory ranking',
  'getPriceCompliance': 'Shelf prices vs RRP',
  // Outside data: prices read from retailers' public websites (gated off by
  // default on the backend). Named so it is never confused with our own.
  'getCompetitorShelfPrices': 'Competitor shelf prices',
  'getCampaignPerformance': 'Campaign results',
  'getSellInForecast': 'Sell-in forecast',
  'getContestStandings': 'Contest standings',
  'getTaskSummary': 'Tasks',
  'getAlerts': 'Alerts',
  'findTerritories': 'Finding the territory',
  'webSearch': 'Searching the web',
  'getCalendarContext': 'Holidays & paydays',
  'getWeatherContext': 'Weather',
  'getEconomicContext': 'Economy',
};

String stepLabel(ToolActivity tool) =>
    toolStepLabels[tool.name] ??
    switch (tool.pillar) {
      'sales' => 'Checking sales',
      'stock' => 'Checking stock',
      'visibility' => 'Checking visibility',
      'competition' => 'Checking competitors',
      'execution' => 'Checking field execution',
      'web' => 'Searching the web',
      'context' => 'Checking outside context',
      _ => 'Looking that up',
    };

/// How long a turn's lookups took, in seconds. Null when the clock did not
/// run — a duration is never shown as `0.0s`.
Duration? stepsElapsed(List<ToolActivity> tools) {
  final starts = tools.map((t) => t.startedAt).whereType<DateTime>();
  final ends = tools.map((t) => t.endedAt).whereType<DateTime>();
  if (starts.isEmpty || ends.isEmpty) return null;
  final first = starts.reduce((a, b) => a.isBefore(b) ? a : b);
  final last = ends.reduce((a, b) => a.isAfter(b) ? a : b);
  return last.isBefore(first) ? null : last.difference(first);
}

/// "Checked 5 sources · 1 unavailable · 2.1s".
String stepsSummary(
  AppLocalizations l10n,
  TiqNumber number,
  List<ToolActivity> tools,
) {
  final ok = tools.where((t) => t.ok == true).length;
  final failed = tools.where((t) => t.ok == false).length;
  // Every tool failed: that IS the explanation for a thin answer, so it is
  // said rather than counted.
  final parts = <String>[
    if (ok == 0 && failed > 0) l10n.askStepsNoneAnswered else
      l10n.askStepsChecked(ok),
    if (failed > 0 && ok > 0) l10n.askStepsUnavailableCount(failed),
  ];
  final elapsed = stepsElapsed(tools);
  if (elapsed != null) {
    parts.add(l10n.askSeconds(number.format(
      elapsed.inMilliseconds / 1000,
      decimals: 1,
    )));
  }
  return parts.join(' · ');
}

/// What a step is doing.
enum StepState {
  /// Not started. A hollow ring.
  queued,

  /// Executing. The one live pulse this surface permits — and the only amber
  /// in the rail, ever.
  running,

  /// Finished, with its measured duration.
  done,

  /// The source did not answer. A filled triangle and the word — the rail
  /// never turns red, because one dead source is not a dead answer.
  failed,

  /// Still open when the stream ended. A bar, and the words.
  unfinished,
}

/// THE WORKING-STEPS RAIL.
///
/// To make a pause legible — what is being looked up, right now, in the
/// manager's own words — and afterwards to stand as the answer's provenance.
///
/// ## The one live pulse, and when it goes out
///
/// The running dot is `TorchClaim.livePulse`, rung 6, and it means **presence
/// and never progress**. The moment the last tool ends the amber goes out,
/// even though the turn is not finished and the header changes to "Writing the
/// answer" — because a breathing amber means *something is happening right
/// now*, and a model composing a sentence is not a lookup. That is this
/// surface's strictest amber decision and it is worth the extra state.
///
/// Every dot state carries a distinct **silhouette** (ring, disc, triangle,
/// bar) and a word, so neither colour nor motion is ever the only signal.
/// Under reduce-motion, in Day and in Veld the running dot is a `lifted` disc
/// plus the word "Live" — through the same code path, so the two cannot rot
/// apart.
class WorkingSteps extends StatefulWidget {
  const WorkingSteps({
    super.key,
    required this.tools,
    required this.streaming,
    this.animate = false,
    this.writing = false,
    this.lastEventAt,
    this.now = DateTime.now,
    this.onStop,
  });

  final List<ToolActivity> tools;
  final bool streaming;

  /// Whether steps slide in as they arrive (a live turn).
  final bool animate;

  /// Every tool has finished and no token has arrived yet. The rail says so,
  /// and the amber is already out.
  final bool writing;

  /// When the client last heard anything about this turn. The stall
  /// thresholds are measured from here — wall clock, on this phone — because
  /// what a manager waited is what the rail should describe.
  final DateTime? lastEventAt;

  /// The clock the thresholds read. A seam so a test can stand at 31s.
  final DateTime Function() now;

  /// Stop, offered beneath the rail once a step has been silent for
  /// [verySlow]. Keeps everything already written.
  final VoidCallback? onStop;

  /// Past this the middle of the rail collapses to one row.
  static const int shownSteps = 8;

  /// No event for this long while a step runs: "This one is taking a while."
  static const Duration slow = Duration(seconds: 12);

  /// No event for this long: Stop is offered beneath the rail.
  static const Duration verySlow = Duration(seconds: 30);

  @override
  State<WorkingSteps> createState() => _WorkingStepsState();
}

/// How long the live turn has been silent, as the rail describes it.
enum StallLevel {
  /// Under 12s. Nothing extra — a normal wait is not news.
  none,

  /// 12–30s. One line under the running step.
  slow,

  /// Over 30s. The line, and Stop beneath the rail.
  verySlow;

  static StallLevel of(Duration silent) => silent >= WorkingSteps.verySlow
      ? StallLevel.verySlow
      : (silent >= WorkingSteps.slow ? StallLevel.slow : StallLevel.none);
}

class _WorkingStepsState extends State<WorkingSteps> {
  /// One one-shot timer, armed for the next threshold only. Never periodic:
  /// a rail that ticked every second would rebuild a transcript every second
  /// to say nothing had changed.
  Timer? _next;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(WorkingSteps old) {
    super.didUpdateWidget(old);
    if (old.lastEventAt != widget.lastEventAt ||
        old.streaming != widget.streaming) {
      _arm();
    }
  }

  @override
  void dispose() {
    _next?.cancel();
    super.dispose();
  }

  Duration get _silent {
    final last = widget.lastEventAt;
    if (last == null) return Duration.zero;
    final silent = widget.now().difference(last);
    return silent.isNegative ? Duration.zero : silent;
  }

  void _arm() {
    _next?.cancel();
    _next = null;
    if (!widget.streaming || widget.lastEventAt == null) return;
    final silent = _silent;
    final Duration? wait = silent < WorkingSteps.slow
        ? WorkingSteps.slow - silent
        : (silent < WorkingSteps.verySlow
              ? WorkingSteps.verySlow - silent
              : null);
    if (wait == null) return;
    _next = Timer(wait, () {
      if (!mounted) return;
      setState(() {});
      _arm();
    });
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final p = skin.palette;
    final tools = widget.tools;
    final streaming = widget.streaming;
    final writing = widget.writing;
    final running = tools.indexWhere((t) => t.ok == null && streaming);
    final stall = streaming ? StallLevel.of(_silent) : StallLevel.none;

    // First 2 and last 5, with one row between them saying how many are
    // hidden. Never a scroll region inside a transcript.
    final visible = <int>[];
    var hidden = 0;
    if (tools.length <= WorkingSteps.shownSteps) {
      visible.addAll(List<int>.generate(tools.length, (i) => i));
    } else {
      visible.addAll(<int>[0, 1]);
      hidden = tools.length - 7;
      visible.addAll(
        List<int>.generate(5, (i) => tools.length - 5 + i),
      );
    }

    // Before the first tool — the model is reading the question. The old
    // build showed three dots here; a blank gap under the question bubble
    // reads as a dropped send.
    final header = tools.isEmpty && streaming
        ? l10n.askStepsStarting
        : (writing ? l10n.askStepsWriting : l10n.askStepsLookingUp);

    final stallLine = stall == StallLevel.none
        ? null
        : Padding(
            key: const ValueKey<String>('working-steps-stalled'),
            padding: EdgeInsets.only(
              left: _StepRow.labelInset(context),
              top: TiqSpace.s1,
            ),
            child: Text(
              l10n.askStepsStillWorking,
              style: skin.text.meta.style(color: p.ink3),
            ),
          );

    return Semantics(
      liveRegion: streaming,
      label: streaming && running != -1
          ? (stall == StallLevel.none
                ? l10n.askStepProgress(
                    running + 1,
                    tools.length,
                    stepLabel(tools[running]),
                  )
                : l10n.askStepsStillWorkingOn(stepLabel(tools[running])))
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(
                  header,
                  key: const ValueKey<String>('working-steps-header'),
                  style: skin.text.label.style(color: p.ink2),
                ),
              ),
              if (tools.isEmpty && streaming) ...<Widget>[
                const SizedBox(width: TiqSpace.s2),
                // Oatmeal, never amber: nothing is being looked up yet, and
                // a breathing amber would say something is.
                ExcludeSemantics(
                  child: TorchBusyDots(color: p.ink2, size: 4, gap: 6),
                ),
              ],
            ],
          ),
          if (tools.isEmpty && stallLine != null) stallLine,
          if (tools.isNotEmpty)
            SizedBox(height: skin.space.intraBlock - TiqSpace.s1 * 2),
          for (var v = 0; v < visible.length; v++) ...<Widget>[
            if (v == 2 && hidden > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: TiqSpace.s1),
                child: Padding(
                  padding: EdgeInsets.only(left: _StepRow.labelInset(context)),
                  child: Text(
                    l10n.askStepsMore(hidden),
                    style: skin.text.meta.style(color: p.ink3),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.only(top: v == 0 ? 0 : TiqSpace.s1),
              child: Arrive(
                key: ValueKey<String>('step-${visible[v]}'),
                enabled: widget.animate,
                offset: 6,
                duration: const Duration(milliseconds: 280),
                child: _StepRow(
                  tool: tools[visible[v]],
                  running: streaming && visible[v] == running && !writing,
                ),
              ),
            ),
            // Indented under the step that has gone quiet — or under the
            // last one, when the silence is the model composing.
            if (stallLine != null &&
                visible[v] == (running == -1 ? tools.length - 1 : running))
              stallLine,
          ],
          if (stall == StallLevel.verySlow && widget.onStop != null) ...<Widget>[
            const SizedBox(height: TiqSpace.s3),
            TorchSecondaryButton(
              key: const ValueKey<String>('working-steps-stop'),
              label: l10n.askStopShort,
              semanticLabel: l10n.askStop,
              onPressed: widget.onStop,
            ),
          ],
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.tool, required this.running});

  final ToolActivity tool;
  final bool running;

  /// Where a step's label starts. The rail's dots sit on x = 8, so the text
  /// clears them at 28 — and grows with the text, because at 2.0× the dot is
  /// a 16dp mark.
  static double labelInset(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(28).clamp(28.0, 48.0);

  StepState get state => switch (tool.ok) {
    true => StepState.done,
    false => StepState.failed,
    null => running ? StepState.running : StepState.queued,
  };

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final p = skin.palette;
    final state = this.state;
    final still = MotionBudget.of(context).still;
    final lit = TorchScope.lit(context, AskLight.pulseClaimId) && !still;
    final label = stepLabel(tool);
    final duration = tool.duration;

    final text = switch (state) {
      StepState.failed => l10n.askStepsUnavailable(label),
      StepState.unfinished => l10n.askStepsDidNotFinish(label),
      // The word is the channel that always has to be there: it is what a
      // reduce-motion reader, a Day skin and a screen reader all get.
      StepState.running => '$label · ${l10n.askStepsLive}',
      _ => label,
    };

    final dot = _StepDot(state: state, lit: lit);

    return Semantics(
      label: duration == null
          ? text
          : '$text, ${l10n.askSeconds(TiqNumber.of(context).format(
              duration.inMilliseconds / 1000,
              decimals: 1,
            ))}',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: labelInset(context),
            child: Align(alignment: AlignmentDirectional.centerStart, child: dot),
          ),
          Expanded(
            child: Text(
              text,
              style: skin.text.label.style(
                color: state == StepState.running ? p.ink1 : p.ink2,
              ),
            ),
          ),
          if (duration != null && state != StepState.running) ...<Widget>[
            const SizedBox(width: TiqSpace.s2),
            FigureSlot(
              value: duration.inMilliseconds / 1000,
              role: skin.text.monoIdent,
              decimals: 1,
              unit: TiqUnit.worded('s', tight: true),
              color: p.ink3,
            ),
          ],
        ],
      ),
    );
  }
}

/// The dot: four silhouettes, and one of them can be lit.
class _StepDot extends StatefulWidget {
  const _StepDot({required this.state, required this.lit});

  final StepState state;
  final bool lit;

  @override
  State<_StepDot> createState() => _StepDotState();
}

class _StepDotState extends State<_StepDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final moving =
        widget.state == StepState.running && !MotionBudget.of(context).still;
    if (moving && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!moving && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void didUpdateWidget(_StepDot old) {
    super.didUpdateWidget(old);
    didChangeDependencies();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final size = MarkScale.glyph(context, 8);

    switch (widget.state) {
      case StepState.queued:
        return _Ring(size: size, colour: p.edgeControl, skin: skin);
      case StepState.done:
        return _Disc(size: size, colour: p.ink2);
      case StepState.failed:
        return TiqMark(
          shape: MarkShape.criticalTriangle,
          color: p.badSolid,
          size: MarkScale.glyph(context, 9),
        );
      case StepState.unfinished:
        return SizedBox(
          width: MarkScale.glyph(context, 10),
          height: 2,
          child: ColoredBox(color: p.ink3),
        );
      case StepState.running:
        final colour = AskLight.pulse(skin, lit: widget.lit);
        final bloom = AskLight.pulseBloom(skin, lit: widget.lit);
        // Its own RepaintBoundary: a 3200ms bloom must not dirty the
        // transcript's rows behind it.
        return RepaintBoundary(
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              // 1.00 → 1.12 and back, once per 3200ms.
              final t = 1 - (2 * _pulse.value - 1).abs();
              final scale = 1 + 0.12 * t;
              return SizedBox(
                width: size * 2.5,
                height: size * 2.5,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    if (bloom != null)
                      Opacity(
                        opacity: 0.35 + 0.20 * t,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: bloom,
                          ),
                          child: SizedBox.square(dimension: size * 2.5),
                        ),
                      ),
                    Transform.scale(
                      scale: scale,
                      child: _Disc(size: size, colour: colour),
                    ),
                  ],
                ),
              );
            },
          ),
        );
    }
  }
}

class _Disc extends StatelessWidget {
  const _Disc({required this.size, required this.colour});

  final double size;
  final Color colour;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: DecoratedBox(
      decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
    ),
  );
}

class _Ring extends StatelessWidget {
  const _Ring({required this.size, required this.colour, required this.skin});

  final double size;
  final Color colour;
  final TiqSkin skin;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: colour, width: skin.depth.borderWidth),
      ),
    ),
  );
}

/// What the rail becomes once the answer has landed: one quiet row saying what
/// the answer was built from.
///
/// **Amber: none.** A finished lookup is not live, and this row is the proof
/// that the surface's amber has moved on.
class StepsSummaryRow extends StatefulWidget {
  const StepsSummaryRow({super.key, required this.tools});

  final List<ToolActivity> tools;

  @override
  State<StepsSummaryRow> createState() => _StepsSummaryRowState();
}

class _StepsSummaryRowState extends State<StepsSummaryRow> {
  late bool _open = _allFailed;

  /// Every tool failed: expanded by default, because that is the explanation
  /// for a thin answer and it should not need a tap.
  bool get _allFailed =>
      widget.tools.isNotEmpty && widget.tools.every((t) => t.ok == false);

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final p = skin.palette;
    final summary = stepsSummary(l10n, TiqNumber.of(context), widget.tools);
    final failures = widget.tools.where((t) => t.ok == false).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          button: true,
          expanded: _open,
          label: l10n.askStepsSemantic(
            summary,
            _open ? l10n.askStepsHide : l10n.askStepsShow,
          ),
          excludeSemantics: true,
          child: TorchPressable(
            onPressed: () => setState(() => _open = !_open),
            builder: (context, pressed) => Container(
              constraints: BoxConstraints(minHeight: skin.space.tapTarget),
              alignment: AlignmentDirectional.centerStart,
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: _StepRow.labelInset(context),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: failures > 0
                          ? TiqMark(
                              shape: MarkShape.criticalTriangle,
                              color: p.badSolid,
                              size: MarkScale.glyph(context, 9),
                            )
                          : _Disc(
                              size: MarkScale.glyph(context, 8),
                              colour: p.ink2,
                            ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      summary,
                      key: const ValueKey<String>('working-steps-summary'),
                      style: skin.text.label.style(color: p.ink2),
                    ),
                  ),
                  Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    size: MarkScale.glyph(context, 16),
                    color: p.ink3,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_open) ...<Widget>[
          SizedBox(height: skin.space.intraBlock),
          WorkingSteps(tools: widget.tools, streaming: false),
        ],
      ],
    );
  }
}
