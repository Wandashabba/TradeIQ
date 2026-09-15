import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/glass_page_scaffold.dart';
import '../../../core/widgets/lumen_kit.dart';
import '../../../core/widgets/worklist.dart';
import '../../audit/data/photos_repository.dart';
import '../../fraud/presentation/fraud_screen.dart';
import '../data/visit_detail_repository.dart';

/// One visit, as a manager reviews it (#208): who went where and when, the
/// score and what it is made of, what each capture section found, the photos
/// and the fraud signals.
///
/// Reached by `push` from any manager surface that lists a visit (alerts, the
/// fraud review, the agent trail), so the back chip returns to that list. A
/// deep link has nothing to pop to, and gets a way back to the console
/// instead.
///
/// Every status here is a word on its wash ([LumenStatusPill]); no finding
/// rides on colour alone.
class VisitDetailScreen extends ConsumerWidget {
  const VisitDetailScreen({super.key, required this.visitId});

  final String visitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(visitDetailProvider(visitId));
    final canPop = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;

    final error = detail.error;
    final Widget body = error is VisitNotFoundException && !detail.isLoading
        ? _NotFound(visitId: visitId)
        : AsyncSection<VisitDetail>(
            value: detail,
            label: 'visit',
            onRetry: () => ref.invalidate(visitDetailProvider(visitId)),
            builder: (d) => _DetailBody(detail: d),
          );

    return GlassPageScaffold(
      title: const Text('Visit review'),
      actions: [
        if (!canPop)
          TextButton(
            key: const ValueKey('visit-detail-console'),
            onPressed: () => context.go('/dashboard'),
            child: const Text('Console'),
          ),
      ],
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: body,
        ),
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.visitId});

  final String visitId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Align(
        alignment: Alignment.topCenter,
        child: GlassPane(
          key: const ValueKey('visit-not-found'),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const LumenStatusPill(
                status: LumenStatus.none,
                label: 'Not found',
              ),
              const SizedBox(height: 10),
              Text(
                'This visit does not exist, or it belongs to another client.',
                style: TextStyle(fontSize: 14, color: colors.ink1),
              ),
              const SizedBox(height: 4),
              CodeToken(visitId),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: () => context.go('/alerts'),
                child: const Text('Back to alerts'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail});

  final VisitDetail detail;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Header(detail: detail),
        const SizedBox(height: 12),
        _ScorePanel(detail: detail),
        const SizedBox(height: 12),
        _Sections(sections: detail.sections),
        const SizedBox(height: 12),
        _Photos(detail: detail),
        if (detail.signals.isNotEmpty) ...[
          const SizedBox(height: 12),
          _FraudPanel(detail: detail),
        ],
      ],
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.detail});

  final VisitDetail detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final meta = TextStyle(fontSize: 12.5, color: colors.ink3);
    final dwell = detail.dwellMinutes;

    return GlassPane(
      key: const ValueKey('visit-header'),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Kicker('Visit')),
              LumenStatusPill(
                key: const ValueKey('visit-status'),
                status: detail.isDraft ? LumenStatus.current : LumenStatus.good,
                label: detail.isDraft ? 'In progress' : 'Submitted',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              Text(
                detail.outlet.name,
                style: LumenGlass.title(size: 22, color: colors.ink1),
              ),
              CodeToken(detail.outlet.code),
            ],
          ),
          const SizedBox(height: 6),
          Text(detail.agent.email, style: meta),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _Fact(
                label: 'Checked in',
                value: formatVisitTime(detail.checkinTs),
                note: 'device clock',
              ),
              _Fact(
                label: 'Submitted',
                value: detail.submittedAtClient == null
                    ? 'Not yet'
                    : formatVisitTime(detail.submittedAtClient!),
                note: dwell == null ? null : '$dwell min on site',
              ),
              _Fact(
                label: 'Geofence',
                value: detail.distanceM == null
                    ? 'No distance'
                    : '${detail.distanceM!.toStringAsFixed(1)} m',
                trailing: LumenStatusPill(
                  key: const ValueKey('visit-geofence'),
                  status: detail.geofencePass
                      ? LumenStatus.good
                      : LumenStatus.crit,
                  label: detail.geofencePass ? 'Inside fence' : 'Outside fence',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.label,
    required this.value,
    this.note,
    this.trailing,
  });

  final String label;
  final String value;
  final String? note;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Kicker(label, size: 9.5),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: LumenGlass.figure(size: 15, color: colors.ink1)),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
        if (note != null) ...[
          const SizedBox(height: 2),
          Text(note!, style: TextStyle(fontSize: 11, color: colors.ink3)),
        ],
      ],
    );
  }
}

// ── Score ──────────────────────────────────────────────────────────────────

/// The stored band as a status and its word. Words, never colour alone.
({LumenStatus status, String word}) bandStatus(String band) => switch (band) {
  'green' => (status: LumenStatus.good, word: 'Healthy'),
  'amber' => (status: LumenStatus.warn, word: 'At risk'),
  'red' => (status: LumenStatus.crit, word: 'Gap'),
  _ => (status: LumenStatus.none, word: 'Unbanded'),
};

const _dimensionLabels = <String, String>{
  'availability': 'Availability',
  'visibility': 'Visibility',
  'display': 'Display',
  'pricing': 'Pricing',
  'competitive': 'Competitive',
  'salesCapability': 'Sales capability',
};

class _ScorePanel extends StatelessWidget {
  const _ScorePanel({required this.detail});

  final VisitDetail detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final score = detail.score;

    if (score == null) {
      return GlassPane(
        key: const ValueKey('visit-score'),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Kicker('Perfect store score')),
                const LumenStatusPill(
                  status: LumenStatus.none,
                  label: 'Not scored',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              detail.isDraft
                  ? 'The score is calculated when the visit is submitted.'
                  : 'No scorecard has been generated for this visit.',
              style: TextStyle(fontSize: 13, color: colors.ink2),
            ),
          ],
        ),
      );
    }

    final band = bandStatus(score.ratingBand);
    return GlassPane(
      key: const ValueKey('visit-score'),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Kicker('Perfect store score')),
              LumenStatusPill(
                key: const ValueKey('visit-band'),
                status: band.status,
                label: band.word,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                score.weightedTotal.toStringAsFixed(0),
                key: const ValueKey('visit-score-figure'),
                style: LumenGlass.figure(size: 40, color: colors.ink1),
              ),
              const SizedBox(width: 6),
              Text(
                '/ 100 · target ${score.target.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 12.5, color: colors.ink3),
              ),
            ],
          ),
          const SizedBox(height: 10),
          BenchmarkBar(
            value: score.weightedTotal,
            target: score.target,
            status: band.status,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, box) {
              final twoUp = box.maxWidth >= 560;
              final width = twoUp ? (box.maxWidth - 24) / 2 : box.maxWidth;
              return Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  for (final d in score.dimensions)
                    SizedBox(
                      width: width,
                      child: _DimensionRow(dimension: d, target: score.target),
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

class _DimensionRow extends StatelessWidget {
  const _DimensionRow({required this.dimension, required this.target});

  final ScoreDimension dimension;
  final double target;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final value = dimension.score;
    final status = value == null
        ? LumenStatus.none
        : value >= target
        ? LumenStatus.good
        : LumenStatus.warn;
    final word = value == null
        ? 'Not measured'
        : value >= target
        ? 'On target'
        : 'Below target';

    return Column(
      key: ValueKey('visit-dimension-${dimension.key}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _dimensionLabels[dimension.key] ?? dimension.key,
                style: TextStyle(fontSize: 12.5, color: colors.ink2),
              ),
            ),
            Text(
              value == null ? '—' : value.toStringAsFixed(0),
              style: LumenGlass.figure(size: 13, color: colors.ink1),
            ),
            const SizedBox(width: 8),
            LumenStatusPill(status: status, label: word),
          ],
        ),
        const SizedBox(height: 6),
        BenchmarkBar(
          value: value ?? 0,
          target: target,
          status: status,
          height: 5,
        ),
      ],
    );
  }
}

// ── Sections ───────────────────────────────────────────────────────────────

const _sectionLabels = <String, String>{
  'stock': 'Stock',
  'visibility': 'Visibility',
  'pricing': 'Pricing',
  'competitive': 'Competitive',
  'risks': 'Risks',
};

/// A section's state as a status and its word.
({LumenStatus status, String word}) sectionStatus(VisitSectionSummary s) {
  if (s.count == 0) return (status: LumenStatus.none, word: 'Not captured');
  if (s.flagged == 0) return (status: LumenStatus.good, word: 'Clear');
  // A flagged risk is an in-store hazard; everything else is an execution gap.
  return (
    status: s.key == 'risks' ? LumenStatus.crit : LumenStatus.warn,
    word: '${s.flagged} flagged',
  );
}

class _Sections extends StatelessWidget {
  const _Sections({required this.sections});

  final List<VisitSectionSummary> sections;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final twoUp = box.maxWidth >= 720;
        final width = twoUp ? (box.maxWidth - 12) / 2 : box.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final s in sections)
              SizedBox(
                width: width,
                child: _SectionPanel(section: s),
              ),
          ],
        );
      },
    );
  }
}

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({required this.section});

  final VisitSectionSummary section;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = sectionStatus(section);
    final countWord = section.key == 'visibility'
        ? (section.count == 0 ? 'Nothing captured' : 'Captured')
        : '${section.count} captured';

    return PanelCard(
      key: ValueKey('visit-section-${section.key}'),
      title: _sectionLabels[section.key] ?? section.key,
      subtitle: countWord,
      trailing: LumenStatusPill(status: state.status, label: state.word),
      child: section.findings.isEmpty
          ? Text(
              section.count == 0
                  ? 'Nothing was recorded in this section.'
                  : 'No findings.',
              style: TextStyle(fontSize: 12.5, color: colors.ink3),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final f in section.findings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('•  ', style: TextStyle(color: colors.ink3)),
                        Expanded(
                          child: Text(
                            f,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                              color: colors.ink1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (section.truncated)
                  Text(
                    'Findings drawn from the first 500 rows.',
                    style: TextStyle(fontSize: 11, color: colors.ink3),
                  ),
              ],
            ),
    );
  }
}

// ── Photos ─────────────────────────────────────────────────────────────────

class _Photos extends StatelessWidget {
  const _Photos({required this.detail});

  final VisitDetail detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final shown = detail.photos.length;
    return PanelCard(
      key: const ValueKey('visit-photos'),
      title: 'Photos',
      subtitle: shown < detail.photoTotal
          ? 'Showing $shown of ${detail.photoTotal}'
          : '${detail.photoTotal} captured',
      child: detail.photos.isEmpty
          ? Text(
              'No photos were captured on this visit.',
              style: TextStyle(fontSize: 12.5, color: colors.ink3),
            )
          : Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [for (final p in detail.photos) _PhotoTile(photo: p)],
            ),
    );
  }
}

/// A captured photo's thumbnail, fetched as bytes through the authed client.
/// Loading or failed shows an empty slot, never a spinner or a broken-image
/// icon: the section and time underneath still say what the photo was.
class _PhotoTile extends ConsumerWidget {
  const _PhotoTile({required this.photo});

  final VisitPhotoRef photo;

  static const double _size = 96;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final bytes = ref.watch(thumbnailBytesProvider(photo.id));
    final radius = BorderRadius.circular(LumenGlass.radiusChip);

    return SizedBox(
      key: ValueKey('visit-photo-${photo.id}'),
      width: _size,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: radius,
            child: SizedBox.square(
              dimension: _size,
              child: bytes.maybeWhen(
                data: (b) => Image.memory(
                  b,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  semanticLabel: '${photo.section} photo',
                ),
                orElse: () => ColoredBox(color: colors.surface3),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            photo.section,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: colors.ink2),
          ),
          Text(
            _clock(photo.timestamp.toLocal()),
            style: LumenGlass.figure(size: 10.5, color: colors.ink3),
          ),
        ],
      ),
    );
  }
}

// ── Fraud ──────────────────────────────────────────────────────────────────

class _FraudPanel extends StatelessWidget {
  const _FraudPanel({required this.detail});

  final VisitDetail detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final level = FraudScreen.levelFor(detail.riskScore);
    return PanelCard(
      key: const ValueKey('visit-fraud'),
      title: 'Fraud signals',
      subtitle: 'Risk ${detail.riskScore.toStringAsFixed(0)} of 100',
      trailing: LumenStatusPill(
        status: level.lumen,
        label: FraudScreen.wordFor(level),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in detail.signals)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  CodeToken(s.code),
                  const SizedBox(height: 3),
                  Text(
                    s.detail,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: colors.ink1,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Formatting ─────────────────────────────────────────────────────────────

const _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _two(int n) => n.toString().padLeft(2, '0');

String _clock(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

/// `14 Sep 2026, 09:12`, in the viewer's local time.
String formatVisitTime(DateTime t) {
  final local = t.toLocal();
  return '${local.day} ${_months[local.month - 1]} ${local.year}, '
      '${_clock(local)}';
}
