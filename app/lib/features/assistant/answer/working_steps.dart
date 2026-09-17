import 'package:flutter/material.dart';

import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/lumen_palette.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/glass.dart';
import '../data/chat_controller.dart';
import 'answer_motion.dart';

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
  'webSearch': 'Searching the web',
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
      _ => 'Looking that up',
    };

/// `0.6s`.
String formatSeconds(Duration d) =>
    '${(d.inMilliseconds / 1000).toStringAsFixed(1)}s';

/// The header once the answer is done: "Checked 5 sources · 2.4s".
String stepsSummary(List<ToolActivity> tools) {
  final ok = tools.where((t) => t.ok == true).length;
  final failed = tools.where((t) => t.ok == false).length;
  final parts = ['Checked $ok ${ok == 1 ? 'source' : 'sources'}'];
  if (failed > 0) parts.add('$failed unavailable');

  final starts = tools.map((t) => t.startedAt).whereType<DateTime>();
  final ends = tools.map((t) => t.endedAt).whereType<DateTime>();
  if (starts.isNotEmpty && ends.isNotEmpty) {
    final first = starts.reduce((a, b) => a.isBefore(b) ? a : b);
    final last = ends.reduce((a, b) => a.isAfter(b) ? a : b);
    if (!last.isBefore(first)) parts.add(formatSeconds(last.difference(first)));
  }
  return parts.join(' · ');
}

/// The live checklist of what the assistant is looking up.
///
/// It replaces a loose row of chips because a pause is only reassuring when
/// you can see what is being waited on: each step spins while it runs, ticks
/// with its own measured time when it lands, and says so plainly when a source
/// was unavailable. When the turn ends it stays, summarised — the answer's
/// provenance, one glance above it.
class WorkingSteps extends StatelessWidget {
  const WorkingSteps({
    super.key,
    required this.tools,
    required this.streaming,
    this.animate = false,
  });

  final List<ToolActivity> tools;
  final bool streaming;

  /// Whether steps slide in as they arrive (a live turn) or are simply there.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final glass = colors.glass;
    final lumen = context.lumen;
    final muted = glass ? lumen.inkMuted : colors.ink3;
    final ink = glass ? lumen.ink : colors.ink1;

    final header = Text(
      streaming ? 'Working on it…' : stepsSummary(tools),
      key: const ValueKey('working-steps-summary'),
      style: LumenGlass.figure(size: 12, color: muted, weight: FontWeight.w500)
          .copyWith(height: 1.2),
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(liveRegion: true, child: header),
        const SizedBox(height: 7),
        for (var i = 0; i < tools.length; i++)
          Arrive(
            key: ValueKey('step-$i'),
            enabled: animate,
            offset: 6,
            duration: const Duration(milliseconds: 280),
            child: Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 5),
              child: _Step(
                tool: tools[i],
                streaming: streaming,
                ink: ink,
                muted: muted,
              ),
            ),
          ),
      ],
    );

    const padding = EdgeInsets.fromLTRB(12, 10, 12, 10);
    if (glass) {
      return GlassPane(
        kind: GlassKind.tile,
        blur: false,
        shadow: false,
        radius: LumenGlass.radiusControl,
        padding: padding,
        child: body,
      );
    }
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface1,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(colors.radiusCard),
      ),
      child: body,
    );
  }
}

enum StepState { pending, done, failed, unfinished }

class _Step extends StatelessWidget {
  const _Step({
    required this.tool,
    required this.streaming,
    required this.ink,
    required this.muted,
  });

  final ToolActivity tool;
  final bool streaming;
  final Color ink;
  final Color muted;

  StepState get state => switch (tool.ok) {
        true => StepState.done,
        false => StepState.failed,
        // A turn that ended with this step still open — a dropped stream —
        // must not spin forever.
        null => streaming ? StepState.pending : StepState.unfinished,
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final glass = colors.glass;
    final lumen = context.lumen;
    final good = colors.good;
    final critical = glass ? lumen.critical : colors.critText;
    final state = this.state;
    final duration = tool.duration;

    final Widget mark = switch (state) {
      StepState.pending => CircularProgressIndicator(
          strokeWidth: 2,
          color: glass ? lumen.accentSolid : colors.brand,
          backgroundColor: glass ? lumen.track : colors.grid,
        ),
      StepState.done => Container(
          decoration: BoxDecoration(
            color: good.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check, size: 10, color: good),
        ),
      StepState.failed => Container(
          decoration: BoxDecoration(
            color: critical.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.close, size: 10, color: critical),
        ),
      StepState.unfinished => Icon(Icons.remove, size: 12, color: muted),
    };

    final label = stepLabel(tool);
    final text = switch (state) {
      StepState.failed => '$label — unavailable',
      StepState.unfinished => '$label — did not finish',
      _ => label,
    };

    return Row(
      key: ValueKey('step-${state.name}'),
      children: [
        SizedBox(width: 14, height: 14, child: mark),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.3,
              color: state == StepState.pending ? ink : muted,
            ),
          ),
        ),
        if (duration != null && state != StepState.pending) ...[
          const SizedBox(width: 8),
          Text(
            formatSeconds(duration),
            style: LumenGlass.figure(
              size: 11,
              color: muted,
              weight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
