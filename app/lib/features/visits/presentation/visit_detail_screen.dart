import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/rating_band.dart';
import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/glass_page_scaffold.dart';
import '../../../core/widgets/lumen_kit.dart';
import '../../../core/widgets/worklist.dart';
import '../../../l10n/l10n.dart';
import '../../audit/data/photos_repository.dart';
import '../../fraud/data/fraud_view.dart';
import '../../templates/domain/template_schema.dart';
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
        for (final answers in detail.templateResponses) ...[
          const SizedBox(height: 12),
          _TemplateAnswersPanel(answers: answers),
        ],
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

// ── Client questions ───────────────────────────────────────────────────────

/// The visit's answers to the client's audit template (#122), each under the
/// question the template asked. The template's own score, when its schema is
/// weighted, is shown here only — it is not part of the perfect-store score.
class _TemplateAnswersPanel extends StatelessWidget {
  const _TemplateAnswersPanel({required this.answers});

  final VisitTemplateAnswers answers;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final schema = TemplateSchema.parse(answers.schema);
    final given = Map<String, Object?>.from(answers.answers);
    final known = {for (final f in schema.fields) f.id};
    final orphans = [
      for (final entry in given.entries)
        if (!known.contains(entry.key)) entry,
    ];
    final maxScore = schema.maxScore;

    final version = answers.answeredOlderVersion
        ? 'Answered against v${answers.templateVersion} · template now '
              'v${answers.currentVersion}, labels from the current version'
        : 'Answered against v${answers.templateVersion}';

    final rows = <Widget>[
      for (final field in schema.fields)
        // A question hidden by its condition was never put to the agent.
        if (field.isVisible(given))
          _AnswerRow(
            key: ValueKey('visit-template-answer-${field.id}'),
            label: field.label,
            value: _answerText(field, given),
            missing: !field.isAnswered(given),
            required: field.blocksSubmit,
          ),
      for (final entry in orphans)
        _AnswerRow(
          key: ValueKey('visit-template-answer-${entry.key}'),
          label: '${entry.key} (no longer in the template)',
          value: _plain(entry.value),
          missing: false,
          required: false,
        ),
    ];

    return PanelCard(
      key: ValueKey('visit-template-${answers.templateId}'),
      title: 'Client questions · ${answers.templateName}',
      subtitle: version,
      trailing: maxScore > 0
          ? LumenStatusPill(
              key: const ValueKey('visit-template-score'),
              status: LumenStatus.none,
              label:
                  'Template score ${_trim(schema.scoreFor(given))} / ${_trim(maxScore)}',
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (rows.isEmpty)
            Text(
              'No answers were recorded.',
              style: TextStyle(fontSize: 12.5, color: colors.ink3),
            )
          else
            ...rows,
          if (maxScore > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'The template score is the client’s own measure. It is not '
                'part of the perfect store score.',
                style: TextStyle(fontSize: 11, color: colors.ink3),
              ),
            ),
        ],
      ),
    );
  }

  static String _answerText(TemplateField field, Map<String, Object?> given) {
    if (field.type == TemplateFieldType.photo) return 'Not captured in the app';
    if (!field.isAnswered(given)) return 'Not answered';
    return _plain(given[field.id]);
  }

  static String _plain(Object? value) => switch (value) {
    true => 'Yes',
    false => 'No',
    final num n => _trim(n.toDouble()),
    null => '—',
    _ => '$value',
  };

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
}

class _AnswerRow extends StatelessWidget {
  const _AnswerRow({
    super.key,
    required this.label,
    required this.value,
    required this.missing,
    required this.required,
  });

  final String label;
  final String value;
  final bool missing;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              required ? '$label (required)' : label,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: colors.ink2,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: missing ? FontWeight.w400 : FontWeight.w600,
                color: missing ? colors.ink3 : colors.ink1,
              ),
            ),
          ),
        ],
      ),
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
              // Outside the fence BECAUSE the agent said the pin is wrong
              // (#386). Without this a reviewer cannot tell a depot-pinned
              // outlet from a faked visit, and that is the whole difference.
              if (detail.pinDispute case final dispute?)
                _Fact(
                  key: const ValueKey('visit-pin-dispute'),
                  label: 'Pin',
                  value: 'Agent reported it wrong',
                  note: [
                    switch (dispute.status) {
                      'applied' =>
                        'Pin moved'
                            '${dispute.resolvedByLabel == null ? '' : ' by ${dispute.resolvedByLabel}'}',
                      'rejected' =>
                        'Pin kept'
                            '${dispute.resolvedByLabel == null ? '' : ' by ${dispute.resolvedByLabel}'}',
                      _ => 'Waiting for review',
                    },
                    if (dispute.note case final note?) '"$note"',
                  ].join(' · '),
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
    super.key,
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

/// The stored band as a status and its labelled word. Words and marks, never
/// colour alone — both come from [RatingBand], the one place the wire values
/// `green` / `amber` / `red` become something a person reads.
///
/// A band this build does not recognise is NOT guessed at: it shows as
/// unbanded, with no severity and no mark.
({LumenStatus status, String label}) bandStatus(
  AppLocalizations l10n,
  String band,
) {
  final known = RatingBand.fromWire(band);
  return known == null
      ? (status: LumenStatus.none, label: 'Unbanded')
      : (status: known.status, label: known.markedWord(l10n));
}

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

    final band = bandStatus(context.l10n, score.ratingBand);
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
                label: band.label,
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
    // The band is a fact about the number and lives with the data, so this
    // screen and the review queue cannot drift into calling 71 "High risk"
    // in one place and "Elevated" in the other.
    final band = FraudRiskBand.of(detail.riskScore);
    final level = switch (band) {
      FraudRiskBand.high => StatusLevel.critical,
      FraudRiskBand.elevated => StatusLevel.warning,
      FraudRiskBand.low => StatusLevel.neutral,
    };
    return PanelCard(
      key: const ValueKey('visit-fraud'),
      title: 'Fraud signals',
      subtitle: 'Risk ${detail.riskScore.toStringAsFixed(0)} of 100',
      trailing: LumenStatusPill(status: level.lumen, label: band.word),
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
