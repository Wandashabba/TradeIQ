import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../../../core/widgets/worklist.dart';
import '../data/fraud_repository.dart';

/// Accusing someone of faking a visit is the most consequential thing this
/// console does, so the row never leans on colour: the score is printed as a
/// figure, and the signals that produced it are printed underneath as the
/// evidence. A red bar with no reason behind it is not a finding.
class FraudScreen extends ConsumerWidget {
  const FraudScreen({super.key});

  /// 0–100. The bands are the same ones the backend flags on.
  static StatusLevel levelFor(double score) => score >= 70
      ? StatusLevel.critical
      : score >= 50
          ? StatusLevel.warning
          : StatusLevel.neutral;

  /// The band's word. Public so the visit detail screen names risk the same way.
  static String wordFor(StatusLevel level) => switch (level) {
        StatusLevel.critical => 'High risk',
        StatusLevel.warning => 'Elevated',
        _ => 'Low risk',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flagged = ref.watch(flaggedVisitsProvider);

    return ManagerScaffold(
      title: 'Fraud Review',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Risk is scored 0–100 on submit. The signals are the evidence.',
            style: TextStyle(fontSize: 12, color: context.colors.ink3),
          ),
          const SizedBox(height: 12),
          AsyncSection<FlaggedPage>(
            value: flagged,
            label: 'flagged visits',
            onRetry: () => ref.invalidate(flaggedVisitsProvider),
            builder: (page) {
              // Riskiest first: the list reads top-down as the review order.
              final sorted = [...page.data]
                ..sort((a, b) => b.riskScore.compareTo(a.riskScore));
              int count(StatusLevel l) =>
                  sorted.where((v) => levelFor(v.riskScore) == l).length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TriageStrip(
                    counts: [
                      (
                        label: 'High risk',
                        count: count(StatusLevel.critical),
                        level: StatusLevel.critical,
                      ),
                      (
                        label: 'Elevated',
                        count: count(StatusLevel.warning),
                        level: StatusLevel.warning,
                      ),
                      (
                        label: 'Low risk',
                        count: count(StatusLevel.neutral),
                        level: StatusLevel.neutral,
                      ),
                    ],
                  ),
                  // An unscored visit is not a clean one. Say so, rather than
                  // let a short list read as "nothing suspicious" (#236).
                  if (page.unscored > 0) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${page.unscored} submitted '
                      '${page.unscored == 1 ? 'visit has' : 'visits have'} '
                      'not been scored yet and '
                      '${page.unscored == 1 ? 'is' : 'are'} not listed here.',
                      key: const ValueKey('fraud-unscored'),
                      style:
                          TextStyle(fontSize: 12, color: context.colors.ink3),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _FlaggedList(
                    visits: sorted,
                    hasMore: page.nextCursor != null,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FlaggedList extends StatelessWidget {
  const _FlaggedList({required this.visits, required this.hasMore});

  final List<FlaggedVisit> visits;

  /// The backend returned the riskiest page and there are more below it.
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    final noun = visits.length == 1 ? 'visit' : 'visits';
    return PanelCard(
      title: hasMore
          ? 'Top ${visits.length} flagged $noun'
          : '${visits.length} flagged $noun',
      subtitle: 'Highest risk first',
      padded: false,
      child: visits.isEmpty
          ? const EmptyState(
              message: 'Nothing flagged',
              hint: 'Visits appear here when the fraud engine scores one above '
                  'the review threshold.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [for (final v in visits) _FlaggedVisitRow(visit: v)],
            ),
    );
  }
}

class _FlaggedVisitRow extends StatelessWidget {
  const _FlaggedVisitRow({required this.visit});

  final FlaggedVisit visit;

  @override
  Widget build(BuildContext context) {
    final idLength = visit.visitId.length >= 8 ? 8 : visit.visitId.length;
    final level = FraudScreen.levelFor(visit.riskScore);
    final codes = visit.signals.map((s) => s.code).join(', ');
    final details = visit.signals.map((s) => s.detail).join(' · ');

    return WorklistRow(
      key: ValueKey('flagged-${visit.visitId}'),
      title: 'Visit ${visit.visitId.substring(0, idLength)}',
      meta: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CodeToken(visit.visitId),
              const SizedBox(width: 6),
              // The score as a plain figure, then the rules that fired. Read
              // this line and you know why the visit is on the page.
              Flexible(
                child: Text(
                  'Risk ${visit.riskScore.toStringAsFixed(0)} · $codes',
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  // A figure and rule codes — machine-facing, so glass sets
                  // them in the mono. Null keeps the meta style in dark.
                  style: context.colors.glass
                      ? const TextStyle(
                          fontFamily: LumenGlass.mono,
                          fontFeatures: [FontFeature.tabularFigures()],
                        )
                      : null,
                ),
              ),
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              details,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: context.colors.ink3),
            ),
          ],
        ],
      ),
      level: level,
      statusLabel: FraudScreen.wordFor(level),
      // The evidence behind the score is one hop away: the whole visit.
      actions: [
        RowAction(
          key: ValueKey<String>('view-visit-${visit.visitId}'),
          label: 'View visit',
          onPressed: () => context.push('/visits/${visit.visitId}'),
        ),
      ],
    );
  }
}
