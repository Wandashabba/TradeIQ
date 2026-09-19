import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/human_error.dart';
import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/lumen_palette.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/agent_kit.dart';
import '../../../core/widgets/agent_scaffold.dart';
import '../../../core/widgets/glass.dart';
import '../../../l10n/l10n.dart';
import '../data/contests_repository.dart';

/// The agent's Contests view (#124): what is running, how long is left, what
/// the prize is, where they stand, and the top of the board. Recently ended
/// contests follow, so a result can still be seen after the last day.
///
/// Two ways in, and they want different ways out. A manager **pushes** it from
/// the leaderboard, so back pops to the leaderboard. An agent arrives from the
/// third slot of Today's nav pill, which `go`es — there is nothing to pop, and
/// the leaderboard is not where they were. Back is therefore `/today`, which
/// the router already resolves per role: an agent lands on their route, a
/// manager deep-linking here lands on The Floor. Either way, home.
class MyContestsScreen extends ConsumerWidget {
  const MyContestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final contests = ref.watch(currentContestsProvider);

    return AgentScaffold(
      title: l10n.contestsTitle,
      subtitle: l10n.contestsSubtitle,
      showSyncChip: false,
      onBack: () => context.canPop() ? context.pop() : context.go('/today'),
      body: contests.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            StatusBanner(
              key: const ValueKey('contests-error'),
              level: BannerLevel.bad,
              title: l10n.contestsLoadError,
              subtitle: humanErrorMessage(err, l10n),
            ),
            const SizedBox(height: 12),
            AgentButton(
              key: const ValueKey('contests-retry'),
              label: l10n.contestsRetry,
              icon: Icons.refresh,
              secondary: true,
              onPressed: () => ref.invalidate(currentContestsProvider),
            ),
          ],
        ),
        data: (list) {
          final active = [for (final c in list) if (c.contest.isActive) c];
          final ended = [for (final c in list) if (c.contest.isEnded) c];
          if (active.isEmpty && ended.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                StatusBanner(
                  key: const ValueKey('contests-empty'),
                  level: BannerLevel.info,
                  title: l10n.contestsEmptyTitle,
                  subtitle: l10n.contestsEmptyBody,
                ),
              ],
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(currentContestsProvider.future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                if (active.isNotEmpty) ...[
                  _Heading(l10n.contestsActiveHeading),
                  for (final c in active) _ContestCard(entry: c),
                ],
                if (ended.isNotEmpty) ...[
                  _Heading(l10n.contestsEndedHeading),
                  for (final c in ended) _ContestCard(entry: c),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// "1 Oct" in the active locale; falls back to en_US when intl has no symbols
/// loaded for it (a bare test app), as `formatDayHeading` does.
String _shortDay(BuildContext context, String isoDate) {
  final date = DateTime.tryParse(isoDate);
  if (date == null) return isoDate;
  try {
    return DateFormat('d MMM', context.l10n.localeName).format(date);
  } on Exception {
    return DateFormat('d MMM', 'en_US').format(date);
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final glass = context.colors.glass;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 0, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.9,
          color: glass ? context.lumen.inkMuted : context.colors.ink3,
        ),
      ),
    );
  }
}

class _ContestCard extends StatelessWidget {
  const _ContestCard({required this.entry});

  final CurrentContest entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final glass = colors.glass;
    final ink = glass ? context.lumen.ink : colors.ink1;
    final muted = glass ? context.lumen.inkMuted : colors.ink3;
    final c = entry.contest;
    final me = entry.me;

    final counts = c.eventTypes.isEmpty
        ? l10n.contestEventAll
        : c.eventTypes
            .map(
              (type) => switch (type) {
                'visit_submitted' => l10n.contestEventVisitSubmitted,
                'task_closed' => l10n.contestEventTaskClosed,
                'scorecard' => l10n.contestEventScorecard,
                _ => type,
              },
            )
            .join(' · ');

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                c.name,
                style: glass
                    ? LumenGlass.title(color: ink, size: 16)
                    : TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
              ),
            ),
            const SizedBox(width: 8),
            _Pill(
              key: ValueKey('contest-when-${c.id}'),
              text: c.isActive
                  ? l10n.contestDaysLeft(c.daysLeft ?? 0)
                  : l10n.contestEnded,
              live: c.isActive,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l10n.contestDateRange(
            _shortDay(context, c.startDate),
            _shortDay(context, c.endDate),
          ),
          style: TextStyle(fontSize: 12.5, color: muted),
        ),
        if (c.description != null) ...[
          const SizedBox(height: 8),
          Text(c.description!, style: TextStyle(fontSize: 13.5, color: ink)),
        ],
        if (c.prizeDescription != null) ...[
          const SizedBox(height: 12),
          _Labelled(
            key: ValueKey('contest-prize-${c.id}'),
            label: l10n.contestPrizeLabel,
            value: c.prizeDescription!,
            icon: Icons.emoji_events_outlined,
          ),
        ],
        const SizedBox(height: 10),
        _Labelled(label: l10n.contestCountsLabel, value: counts),
        const SizedBox(height: 14),
        _YourRank(contestId: c.id, me: me, total: entry.participantCount),
        if (entry.standings.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            l10n.contestStandingsHeading,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: muted,
            ),
          ),
          const SizedBox(height: 6),
          for (final s in entry.standings)
            _StandingLine(
              key: ValueKey('contest-standing-${c.id}-${s.agentId}'),
              standing: s,
              isMe: s.agentId == me?.agentId,
            ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: glass
          ? GlassPane(
              key: ValueKey('contest-card-${c.id}'),
              padding: const EdgeInsets.all(16),
              child: content,
            )
          : Container(
              key: ValueKey('contest-card-${c.id}'),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface1,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.line),
              ),
              child: content,
            ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.text, required this.live});

  final String text;

  /// Active contests wear the brand hue; ended ones stay quiet.
  final bool live;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final glass = colors.glass;
    final fg = live
        ? (glass ? LumenGlass.accentInk : colors.brand)
        : (glass ? context.lumen.inkMuted : colors.ink3);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

class _Labelled extends StatelessWidget {
  const _Labelled({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final glass = context.colors.glass;
    final ink = glass ? context.lumen.ink : context.colors.ink1;
    final muted = glass ? context.lumen.inkMuted : context.colors.ink3;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: muted),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 11.5, color: muted)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: 13.5, color: ink)),
            ],
          ),
        ),
      ],
    );
  }
}

class _YourRank extends StatelessWidget {
  const _YourRank({
    required this.contestId,
    required this.me,
    required this.total,
  });

  final String contestId;
  final ContestStanding? me;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final glass = colors.glass;
    final ink = glass ? context.lumen.ink : colors.ink1;
    final mine = me;

    final child = mine == null
        ? Text(
            l10n.contestNotRanked,
            style: TextStyle(fontSize: 13.5, color: ink),
          )
        : Row(
            children: [
              Expanded(
                child: Text(
                  l10n.contestYourRank(mine.rank, total),
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
              ),
              Text(
                l10n.contestPoints(mine.pointsFigure),
                style: glass
                    ? LumenGlass.figure(color: ink, size: 14)
                    : TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ink,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
              ),
            ],
          );

    return Container(
      key: ValueKey('contest-me-$contestId'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: glass ? context.lumen.white(0x80) : colors.surface2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

class _StandingLine extends StatelessWidget {
  const _StandingLine({
    super.key,
    required this.standing,
    required this.isMe,
  });

  final ContestStanding standing;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final glass = colors.glass;
    final ink = glass ? context.lumen.ink : colors.ink1;
    final muted = glass ? context.lumen.inkMuted : colors.ink3;
    final figure = glass
        ? LumenGlass.figure(color: ink, size: 13)
        : TextStyle(
            fontSize: 13,
            color: ink,
            fontFeatures: const [FontFeature.tabularFigures()],
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text('#${standing.rank}', style: figure.copyWith(color: muted)),
          ),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    standing.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: isMe ? FontWeight.w700 : FontWeight.w400,
                      color: ink,
                    ),
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 6),
                  _Pill(text: l10n.contestYouTag, live: true),
                ],
              ],
            ),
          ),
          Text(l10n.contestPoints(standing.pointsFigure), style: figure),
        ],
      ),
    );
  }
}
