import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/design/tiq_number.dart';
import '../../../core/design/torch_scope.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/console_frame.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../data/clients_repository.dart';
import '../data/iana_time_zones.dart';

/// SCORING CONFIG — the four things the engine reads, and the calendar it
/// counts days in.
///
/// ```text
///   Scoring config                                [ ⟳ ]
///   ── Timezone ──────────────────────────────────
///   Timezone                        Africa/Johannesburg
///   The calendar your team's days are counted in      ›
///   ── Scorecard weights                       6 ──
///   On-shelf availability               2      33.3%
///   Pricing                             0   Excluded
///   [ Edit the weights ]
///   …
///   [ nav pill ]
/// ```
///
/// ## What a reader may do, and what they may only read
///
/// `PATCH /clients/me` is admin-only for weights and thresholds, and open to a
/// manager for the timezone and the working hours. This screen mirrors both
/// rules exactly, because **a field you can type into but never save is worse
/// than one you cannot type into at all** — before this, a manager who filled
/// the form in got a 403 as an unhandled exception and the screen crashed.
///
/// ## Every commit is in a sheet
///
/// Four editable groups and one screen: inline saves would mean up to four
/// primaries on one route, and the amber ladder grants one. Each group is
/// read-only on the page and opens the one modal container to be changed, so
/// there is exactly one commit on screen at any moment — which is also the
/// arrangement the census measures.
///
/// ## The amber, counted
///
/// A tab root: Night paints the nav's active tab and nothing else, because
/// this route nominates no content amber. Day and Veld paint zero. A sheet
/// extinguishes the route beneath it and carries its own single commit.
class ClientConfigScreen extends ConsumerWidget {
  const ClientConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(clientConfigProvider);

    return config.when(
      loading: () => _frame(
        ref,
        phase: 'loading',
        children: <Widget>[
          Skeleton(
            label: 'scoring config',
            child: const SkeletonRows(count: 6, rowHeight: 64),
          ),
        ],
      ),
      error: (error, stack) => _frame(
        ref,
        phase: 'error',
        children: <Widget>[
          TorchErrorRegion(
            name: 'scoring config',
            child: ErrorState(
              message: TorchErrorMessage.sanitise(error),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('config-retry'),
                label: 'Try again',
                onPressed: () => ref.invalidate(clientConfigProvider),
              ),
            ),
          ),
        ],
      ),
      data: (cfg) => _frame(
        ref,
        phase: 'loaded',
        children: <Widget>[_ConfigBody(config: cfg)],
      ),
    );
  }

  Widget _frame(
    WidgetRef ref, {
    required String phase,
    required List<Widget> children,
  }) {
    return ConsoleFrame(
      phase: phase,
      active: ConsoleSlot.menu,
      header: TorchAppHeader(
        title: 'Scoring config',
        facts: const <String>['What the engine reads, and nothing else.'],
        trailing: TorchIconButton(
          key: const ValueKey<String>('config-refresh'),
          icon: Icons.refresh,
          semanticLabel: 'Refresh the scoring config',
          onPressed: () => ref.invalidate(clientConfigProvider),
        ),
      ),
      children: children,
    );
  }
}

class _ConfigBody extends ConsumerWidget {
  const _ConfigBody({required this.config});

  final ClientConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = context.skin;
    final gutter = skin.space.gutter;
    final canEditPolicy = canEditConfig(ref);
    final canEditCalendar = canEditTimezone(ref);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // ── The calendar ──────────────────────────────────────────────
        SectionRule('Timezone'),
        const SizedBox(height: TiqSpace.s5),
        SoftRow(
          key: const ValueKey<String>('timezone-current'),
          form: SoftRowForm.standalone,
          density: SoftRowDensity.tall,
          title: 'Timezone',
          subtitle: config.timezone,
          meta: const Text("The calendar your team's days are counted in"),
          trailing: canEditCalendar ? const SoftRowChevron() : null,
          onTap: canEditCalendar
              ? () => showTimezoneSheet(context, current: config.timezone)
              : null,
          semanticsLabel:
              'Timezone. ${config.timezone}. '
              "The calendar your team's days are counted in."
              '${canEditCalendar ? ' Change the timezone.' : ''}',
        ),
        const SizedBox(height: TiqSpace.s4),
        _Note(
          'Decides which day a check-in counts toward — a visit at 00:30 '
          "belongs to that morning's route, not yesterday's — and where trend "
          'days and weeks begin. A change applies to trends straight away; '
          'stops already ticked on past routes stay as they are.',
        ),

        // ── The working window ────────────────────────────────────────
        SizedBox(height: skin.space.blockGap),
        SectionRule('Working hours'),
        const SizedBox(height: TiqSpace.s5),
        SoftRow(
          key: const ValueKey<String>('working-hours-current'),
          form: SoftRowForm.standalone,
          density: SoftRowDensity.tall,
          title: 'Working hours',
          subtitle: '${config.workHoursStart} – ${config.workHoursEnd}',
          meta: Text(describeWorkDays(config.workDays)),
          trailing: canEditCalendar ? const SoftRowChevron() : null,
          onTap: canEditCalendar
              ? () => showWorkingHoursSheet(context, config: config)
              : null,
          semanticsLabel:
              'Working hours. ${config.workHoursStart} to '
              '${config.workHoursEnd}. ${describeWorkDays(config.workDays)}.'
              '${canEditCalendar ? ' Change the working hours.' : ''}',
        ),
        const SizedBox(height: TiqSpace.s4),
        _Note(
          'Read by one thing only: an agent who has switched on background '
          'route tracking is tracked inside this window and at no other time '
          '— never at night, never at a weekend. It is not a shift model and '
          'not attendance: nothing is scored against it and no agent is '
          'measured by it. The times are read on the clock of the timezone '
          'above (${config.timezone}), and the end time is exclusive — a '
          'point recorded at exactly ${config.workHoursEnd} is outside the '
          'window.',
        ),

        // ── The weights ───────────────────────────────────────────────
        SizedBox(height: skin.space.blockGap),
        SectionRule('Scorecard weights', count: config.scorecardWeights.length),
        const SizedBox(height: TiqSpace.s5),
        TorchBleed(
          extra: gutter * 2,
          child: _WeightRows(weights: config.scorecardWeights),
        ),
        const SizedBox(height: TiqSpace.s5),
        if (canEditPolicy)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TorchSecondaryButton(
              key: const ValueKey<String>('edit-weights'),
              label: 'Edit the weights',
              onPressed: () =>
                  showWeightsSheet(context, weights: config.scorecardWeights),
            ),
          )
        else
          const ReadOnlyNotice(),
        const SizedBox(height: TiqSpace.s4),
        _Note(
          'Weights are relative, not percentages: the score is the weighted '
          'average divided by the total weight, so doubling every weight '
          'changes nothing. A dimension weighted 0 is dropped from the score '
          'entirely.',
        ),

        // ── The thresholds ────────────────────────────────────────────
        SizedBox(height: skin.space.blockGap),
        SectionRule('KPI thresholds', count: KpiThreshold.values.length),
        const SizedBox(height: TiqSpace.s5),
        TorchBleed(
          extra: gutter * 2,
          child: _ThresholdRows(thresholds: config.kpiThresholds),
        ),
        const SizedBox(height: TiqSpace.s5),
        if (canEditPolicy)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TorchSecondaryButton(
              key: const ValueKey<String>('edit-thresholds'),
              label: 'Edit the thresholds',
              onPressed: () => showThresholdsSheet(
                context,
                thresholds: config.kpiThresholds,
              ),
            ),
          )
        else
          const ReadOnlyNotice(),
        const SizedBox(height: TiqSpace.s4),
        _Note(
          'These four keys are the whole contract — the engine reads nothing '
          'else. Changing a band re-grades new scorecards only; it does not '
          'retroactively re-score past visits.',
        ),
      ],
    );
  }
}

/// A paragraph of the console's own explanation.
class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Text(text, style: skin.text.meta.style(color: skin.palette.ink3));
  }
}

/// The weights, read-only, with each dimension's share of the score.
class _WeightRows extends StatelessWidget {
  const _WeightRows({required this.weights});

  final Map<String, double> weights;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final entries = weights.entries.toList();
    final total = weights.values.where((w) => w > 0).fold(0.0, (a, b) => a + b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var i = 0; i < entries.length; i++)
          Builder(
            builder: (context) {
              final weight = entries[i].value;
              final excluded = weight <= 0;
              final share = (excluded || total <= 0)
                  ? null
                  : (weight / total) * 100;
              return SoftRow(
                key: ValueKey<String>('weight-${entries[i].key}'),
                density: SoftRowDensity.compact,
                title: humaniseDimension(entries[i].key),
                meta: Text('Weight ${TiqNumber.of(context).format(weight)}'),
                // A dropped dimension is stated in words, not implied by a 0.
                // The share is null then, and a null figure renders an em dash
                // — so the chip carries the fact and nothing pretends to a
                // percentage nobody computed.
                trailing: excluded
                    ? const StatusChip(
                        level: StatusLevel.held,
                        label: 'Excluded',
                      )
                    : FigureSlot(
                        value: share,
                        role: skin.text.figureS,
                        unit: TiqUnit.percent,
                        decimals: 1,
                        color: skin.palette.ink1,
                        textAlign: TextAlign.end,
                      ),
                separator: i == entries.length - 1
                    ? SoftRowSeparator.none
                    : SoftRowSeparator.auto,
                semanticsLabel: <String>[
                  humaniseDimension(entries[i].key),
                  'Weight ${TiqNumber.of(context).format(weight)}',
                  if (excluded)
                    'Excluded from the score'
                  else
                    '${TiqNumber.of(context).format(share, decimals: 1)} '
                        'per cent of the score',
                ].join('. '),
              );
            },
          ),
      ],
    );
  }
}

/// The four KPI thresholds, read-only.
class _ThresholdRows extends StatelessWidget {
  const _ThresholdRows({required this.thresholds});

  final Map<String, double> thresholds;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var i = 0; i < KpiThreshold.values.length; i++)
          Builder(
            builder: (context) {
              final t = KpiThreshold.values[i];
              // A key the server has not sent is not an absence: the engine
              // uses its own fallback, so the fallback is what is true and it
              // is shown with the word that says where it came from.
              final stored = thresholds[t.key];
              final value = stored ?? t.fallback;
              return SoftRow(
                key: ValueKey<String>('threshold-${t.key}'),
                density: SoftRowDensity.tall,
                title: t.label,
                subtitle: t.help,
                meta: stored == null
                    ? const Text('Not set — the engine uses this default')
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    FigureSlot(
                      value: value,
                      role: skin.text.figureS,
                      color: skin.palette.ink1,
                      textAlign: TextAlign.end,
                    ),
                    if (t.suffix.isNotEmpty)
                      Text(
                        t.suffix,
                        style: skin.text.meta.style(color: skin.palette.ink3),
                      ),
                  ],
                ),
                separator: i == KpiThreshold.values.length - 1
                    ? SoftRowSeparator.none
                    : SoftRowSeparator.auto,
                semanticsLabel: <String>[
                  t.label,
                  t.help,
                  '${TiqNumber.of(context).format(value)}${t.suffix}',
                  if (stored == null) 'Not set — the engine uses this default',
                ].join('. '),
              );
            },
          ),
      ],
    );
  }
}

// ── The sheets ────────────────────────────────────────────────────────

/// CHOOSE A TIMEZONE. Picked from a list rather than typed, because the server
/// accepts only exact canonical IANA names and a free-text box would mostly
/// produce 400s.
Future<void> showTimezoneSheet(
  BuildContext context, {
  required String current,
}) {
  return showTorchSheet<void>(
    context,
    builder: (_) => _TimezoneSheet(current: current),
  );
}

class _TimezoneSheet extends ConsumerStatefulWidget {
  const _TimezoneSheet({required this.current});

  final String current;

  @override
  ConsumerState<_TimezoneSheet> createState() => _TimezoneSheetState();
}

class _TimezoneSheetState extends ConsumerState<_TimezoneSheet> {
  /// How many zones the sheet renders before it stops and says so.
  static const int _cap = 30;

  final TextEditingController _search = TextEditingController();
  bool _saving = false;
  TorchErrorMessage? _failure;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _choose(String zone) async {
    if (zone == widget.current) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await ref.read(clientsRepositoryProvider).updateTimezone(zone);
      ref.invalidate(clientConfigProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      showTorchToast(
        context,
        message: 'Timezone set to $zone.',
        kind: ToastKind.success,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failure = TorchErrorMessage(
          kind: TorchErrorKind.permission,
          headline: 'The timezone was not changed.',
          body: describeSaveFailure(
            error,
            forbidden:
                'Only a manager or administrator can change the timezone.',
          ),
          offersRetry: false,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final options = timezoneOptions(_search.text, current: widget.current);
    final matches = <String>[...options.suggested, ...options.all];
    // A CAP AND A SENTENCE, not a 420-row list.
    //
    // The sheet body scrolls; a bounded, lazily built list inside it cannot
    // (a viewport in an unbounded column has no height to expand into), and a
    // fixed box overflows the 88% ceiling the moment the text scale moves.
    // So the list is capped and **says it is capped**, and the search box is
    // how a manager reaches the rest — which is how anybody finds a timezone
    // in a list of four hundred anyway.
    final shown = matches.take(_cap).toList();
    final numbers = TiqNumber.of(context);

    return TorchSheet(
      title: 'Choose a timezone',
      subtitle: "The calendar your team's days are counted in.",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TorchTextField(
            key: const ValueKey<String>('timezone-search'),
            label: 'Search',
            controller: _search,
            hint: 'Johannesburg, New York',
            identifier: true,
            autocorrect: false,
            enabled: !_saving,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: TiqSpace.s5),

          if (shown.isEmpty)
            EmptyState(
              key: const ValueKey<String>('timezone-no-match'),
              scope: EmptyScope.inline,
              headline: 'No timezone matches “${_search.text.trim()}”.',
              body: 'Search for a city, or clear the box to see them all.',
            )
          else ...<Widget>[
            if (options.suggested.isNotEmpty) ...<Widget>[
              SectionRule('Suggested'),
              const SizedBox(height: TiqSpace.s3),
            ],
            for (var i = 0; i < shown.length; i++) ...<Widget>[
              if (options.suggested.isNotEmpty &&
                  i == options.suggested.length) ...<Widget>[
                const SizedBox(height: TiqSpace.s5),
                SectionRule('All timezones'),
                const SizedBox(height: TiqSpace.s3),
              ],
              _ZoneRow(
                zone: shown[i],
                chosen: shown[i] == widget.current,
                last: i == shown.length - 1,
                onTap: _saving ? null : () => _choose(shown[i]),
              ),
            ],
            if (matches.length > shown.length) ...<Widget>[
              const SizedBox(height: TiqSpace.s5),
              PaginationFooter(
                key: const ValueKey<String>('timezone-footer'),
                summary:
                    'Showing ${numbers.format(shown.length)} of '
                    '${numbers.format(matches.length)} timezones.',
                narrowLine: 'Search for a city to find the rest.',
              ),
            ],
          ],

          if (_failure != null) ...<Widget>[
            SizedBox(height: skin.space.intraBlock),
            TorchErrorRegion(
              name: 'timezone',
              child: ErrorState(
                key: const ValueKey<String>('timezone-error'),
                scope: ErrorScope.inline,
                message: _failure!,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One zone: the place a manager recognises first, the exact IANA name under
/// it — machine-facing, so it wears the mono face.
class _ZoneRow extends StatelessWidget {
  const _ZoneRow({
    required this.zone,
    required this.chosen,
    required this.last,
    required this.onTap,
  });

  final String zone;
  final bool chosen;
  final bool last;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final place = zone.split('/').last.replaceAll('_', ' ');
    return SoftRow(
      key: ValueKey<String>('timezone-option-$zone'),
      density: SoftRowDensity.compact,
      title: place,
      meta: place == zone
          ? null
          : Text(
              zone,
              style: skin.text.monoIdent.style(color: skin.palette.ink3),
            ),
      trailing: chosen ? const Text('Chosen') : null,
      onTap: onTap,
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: chosen ? '$place, $zone, chosen' : '$place, $zone',
    );
  }
}

/// CHANGE THE WORKING WINDOW.
Future<void> showWorkingHoursSheet(
  BuildContext context, {
  required ClientConfig config,
}) {
  return showTorchSheet<void>(
    context,
    builder: (_) => _WorkingHoursSheet(config: config),
  );
}

class _WorkingHoursSheet extends ConsumerStatefulWidget {
  const _WorkingHoursSheet({required this.config});

  final ClientConfig config;

  @override
  ConsumerState<_WorkingHoursSheet> createState() => _WorkingHoursSheetState();
}

class _WorkingHoursSheetState extends ConsumerState<_WorkingHoursSheet> {
  static const String commitClaimId = 'working-hours-save';

  late final TextEditingController _start = TextEditingController(
    text: widget.config.workHoursStart,
  );
  late final TextEditingController _end = TextEditingController(
    text: widget.config.workHoursEnd,
  );
  late final Set<int> _days = <int>{...widget.config.workDays};
  String? _error;
  bool _saving = false;
  TorchErrorMessage? _failure;

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final days = _days.toList()..sort();
    final error = validateWorkingHoursEdit(
      start: _start.text.trim(),
      end: _end.text.trim(),
      days: days,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await ref
          .read(clientsRepositoryProvider)
          .updateWorkingHours(
            start: _start.text.trim(),
            end: _end.text.trim(),
            days: days,
          );
      ref.invalidate(clientConfigProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      showTorchToast(
        context,
        message: 'Working hours saved.',
        kind: ToastKind.success,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failure = TorchErrorMessage(
          kind: TorchErrorKind.permission,
          headline: 'The working hours were not saved.',
          body: describeSaveFailure(
            error,
            forbidden:
                'Only a manager or administrator can change working hours.',
          ),
          offersRetry: false,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return TorchSheet(
      title: 'Working hours',
      subtitle: 'The only hours background location tracking may run in.',
      claims: _saving
          ? const <TorchClaim>[]
          : const <TorchClaim>[TorchClaim.primaryCommit(commitClaimId)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TorchTextField(
            key: const ValueKey<String>('work-hours-start'),
            label: 'Start',
            controller: _start,
            hint: '07:00',
            identifier: true,
            autocorrect: false,
            enabled: !_saving,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: TiqSpace.s5),
          TorchTextField(
            key: const ValueKey<String>('work-hours-end'),
            label: 'End (exclusive)',
            controller: _end,
            hint: '17:00',
            identifier: true,
            autocorrect: false,
            enabled: !_saving,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          SizedBox(height: skin.space.blockGap),
          TorchCheckboxGroup(
            label: 'Working days',
            error: _error,
            children: <Widget>[
              for (var day = 1; day <= 7; day++)
                TorchCheckbox(
                  key: ValueKey<String>('work-day-$day'),
                  label: weekdayNames[day],
                  value: _days.contains(day),
                  onChanged: _saving
                      ? null
                      : (on) => setState(() {
                          if (on) {
                            _days.add(day);
                          } else {
                            _days.remove(day);
                          }
                          _error = null;
                        }),
                ),
            ],
          ),

          if (_failure != null) ...<Widget>[
            SizedBox(height: skin.space.intraBlock),
            TorchErrorRegion(
              name: 'working hours',
              child: ErrorState(
                key: const ValueKey<String>('work-hours-error'),
                scope: ErrorScope.inline,
                message: _failure!,
              ),
            ),
          ],

          SizedBox(height: skin.space.blockGap),
          TorchPrimaryButton(
            key: const ValueKey<String>('save-working-hours'),
            claimId: commitClaimId,
            label: 'Save the working hours',
            busy: _saving,
            onPressed: _saving ? null : _save,
            blockedReason: _saving ? 'Saving.' : null,
          ),
          const SizedBox(height: TiqSpace.s2),
          TorchSecondaryButton(
            key: const ValueKey<String>('cancel-working-hours'),
            label: 'Cancel',
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// CHANGE THE SCORECARD WEIGHTS.
Future<void> showWeightsSheet(
  BuildContext context, {
  required Map<String, double> weights,
}) {
  return showTorchSheet<void>(
    context,
    builder: (_) => _WeightsSheet(weights: weights),
  );
}

class _WeightsSheet extends ConsumerStatefulWidget {
  const _WeightsSheet({required this.weights});

  final Map<String, double> weights;

  @override
  ConsumerState<_WeightsSheet> createState() => _WeightsSheetState();
}

class _WeightsSheetState extends ConsumerState<_WeightsSheet> {
  static const String commitClaimId = 'weights-save';

  late final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{
        for (final e in widget.weights.entries)
          // The share column has to move as you type, or the weights are just
          // opaque numbers.
          e.key: TextEditingController(text: '${e.value}')
            ..addListener(() => setState(() {})),
      };
  bool _saving = false;
  TorchErrorMessage? _failure;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double _weightOf(String key) =>
      double.tryParse(_controllers[key]!.text.trim()) ?? 0;

  /// The server scores with `weightedSum / weightSum`, so the weights are
  /// *relative* — they do not have to add up to 1. What actually matters is
  /// each dimension's share of the total, which is what we show.
  double get _total => _controllers.keys
      .map(_weightOf)
      .where((w) => w > 0)
      .fold(0.0, (a, b) => a + b);

  Future<void> _save() async {
    final map = <String, double>{
      for (final key in _controllers.keys) key: _weightOf(key),
    };
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await ref.read(clientsRepositoryProvider).updateWeights(map);
      ref.invalidate(clientConfigProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      showTorchToast(
        context,
        message: 'Scorecard weights saved.',
        kind: ToastKind.success,
      );
    } catch (error) {
      // A failed save must not take the app down. Before this, a 403 from the
      // admin-only endpoint escaped as an unhandled DioException and crashed
      // the screen — after showing a manager an editable form they were never
      // allowed to submit.
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failure = TorchErrorMessage(
          kind: TorchErrorKind.permission,
          headline: 'The weights were not saved.',
          body: describeSaveFailure(error),
          offersRetry: false,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final total = _total;

    return TorchSheet(
      title: 'Scorecard weights',
      subtitle: 'Relative — the server normalises by their total.',
      claims: _saving
          ? const <TorchClaim>[]
          : const <TorchClaim>[TorchClaim.primaryCommit(commitClaimId)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final key in _controllers.keys) ...<Widget>[
            TorchNumericField(
              key: ValueKey<String>('weight-field-$key'),
              label: humaniseDimension(key),
              controller: _controllers[key],
              decimals: 2,
              enabled: !_saving,
              help: _shareLine(context, key, total),
            ),
            const SizedBox(height: TiqSpace.s5),
          ],

          if (_failure != null) ...<Widget>[
            TorchErrorRegion(
              name: 'weights',
              child: ErrorState(
                key: const ValueKey<String>('weights-error'),
                scope: ErrorScope.inline,
                message: _failure!,
              ),
            ),
            SizedBox(height: skin.space.intraBlock),
          ],

          TorchPrimaryButton(
            key: const ValueKey<String>('save-config'),
            claimId: commitClaimId,
            label: 'Save the weights',
            busy: _saving,
            onPressed: _saving ? null : _save,
            blockedReason: _saving ? 'Saving.' : null,
          ),
          const SizedBox(height: TiqSpace.s2),
          TorchSecondaryButton(
            key: const ValueKey<String>('cancel-weights'),
            label: 'Cancel',
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// What this weight is worth, in words, as it is typed. A dimension weighted
  /// nought is **excluded** and says so — never "0% of the score", which reads
  /// as a measurement.
  String _shareLine(BuildContext context, String key, double total) {
    final weight = _weightOf(key);
    if (weight <= 0) return 'Excluded from the score entirely.';
    if (total <= 0) return 'Excluded from the score entirely.';
    final share = TiqNumber.of(
      context,
    ).format((weight / total) * 100, decimals: 1);
    return '$share% of the score.';
  }
}

/// CHANGE THE KPI THRESHOLDS.
Future<void> showThresholdsSheet(
  BuildContext context, {
  required Map<String, double> thresholds,
}) {
  return showTorchSheet<void>(
    context,
    builder: (_) => _ThresholdsSheet(thresholds: thresholds),
  );
}

class _ThresholdsSheet extends ConsumerStatefulWidget {
  const _ThresholdsSheet({required this.thresholds});

  final Map<String, double> thresholds;

  @override
  ConsumerState<_ThresholdsSheet> createState() => _ThresholdsSheetState();
}

class _ThresholdsSheetState extends ConsumerState<_ThresholdsSheet> {
  static const String commitClaimId = 'thresholds-save';

  late final Map<KpiThreshold, TextEditingController> _controllers =
      <KpiThreshold, TextEditingController>{
        for (final t in KpiThreshold.values)
          t: TextEditingController(
            text: '${widget.thresholds[t.key] ?? t.fallback}',
          ),
      };
  bool _saving = false;
  TorchErrorMessage? _failure;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final map = <String, double>{};
    _controllers.forEach((threshold, controller) {
      final parsed = double.tryParse(controller.text.trim());
      // A blank or unparseable box must not silently become 0 — that would
      // turn "leave it alone" into "never trigger". Fall back to what the
      // engine already uses.
      map[threshold.key] = parsed ?? threshold.fallback;
    });

    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await ref.read(clientsRepositoryProvider).updateThresholds(map);
      ref.invalidate(clientConfigProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      showTorchToast(
        context,
        message: 'KPI thresholds saved.',
        kind: ToastKind.success,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failure = TorchErrorMessage(
          kind: TorchErrorKind.permission,
          headline: 'The thresholds were not saved.',
          body: describeSaveFailure(error),
          offersRetry: false,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return TorchSheet(
      title: 'KPI thresholds',
      subtitle: 'What counts as Healthy, and what opens a task.',
      claims: _saving
          ? const <TorchClaim>[]
          : const <TorchClaim>[TorchClaim.primaryCommit(commitClaimId)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final t in KpiThreshold.values) ...<Widget>[
            TorchNumericField(
              key: ValueKey<String>('threshold-${t.key}'),
              label: t.suffix.isEmpty ? t.label : '${t.label}${t.suffix}',
              controller: _controllers[t],
              decimals: 2,
              enabled: !_saving,
              help:
                  '${t.help} Blank uses the engine\'s own '
                  '${TiqNumber.of(context).format(t.fallback)}.',
            ),
            const SizedBox(height: TiqSpace.s5),
          ],

          if (_failure != null) ...<Widget>[
            TorchErrorRegion(
              name: 'thresholds',
              child: ErrorState(
                key: const ValueKey<String>('thresholds-error'),
                scope: ErrorScope.inline,
                message: _failure!,
              ),
            ),
            SizedBox(height: skin.space.intraBlock),
          ],

          TorchPrimaryButton(
            key: const ValueKey<String>('save-thresholds'),
            claimId: commitClaimId,
            label: 'Save the thresholds',
            busy: _saving,
            onPressed: _saving ? null : _save,
            blockedReason: _saving ? 'Saving.' : null,
          ),
          const SizedBox(height: TiqSpace.s2),
          TorchSecondaryButton(
            key: const ValueKey<String>('cancel-thresholds'),
            label: 'Cancel',
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

// ── The rules, unchanged ──────────────────────────────────────────────

/// A dimension key in words: `onShelfAvailability` → "On shelf availability".
String humaniseDimension(String key) {
  final spaced = key.replaceAllMapped(
    RegExp('([a-z])([A-Z])'),
    (m) => '${m[1]} ${m[2]!.toLowerCase()}',
  );
  return spaced[0].toUpperCase() + spaced.substring(1);
}

/// The working days in words: "Monday to Friday" when they run together,
/// otherwise the list. A manager should be able to check this at a glance
/// rather than decode `[1, 2, 3, 4, 5]`.
String describeWorkDays(List<int> days) {
  final sorted = <int>[...days]..sort();
  if (sorted.isEmpty) return 'No days';
  if (sorted.length == 7) return 'Every day';
  final runsTogether = sorted.last - sorted.first == sorted.length - 1;
  if (runsTogether && sorted.length > 2) {
    return '${weekdayNames[sorted.first]} to ${weekdayNames[sorted.last]}';
  }
  return sorted.map((d) => weekdayNames[d]).join(', ');
}

/// Validates an edit the way the server does, so a manager is told what is
/// wrong before a round trip rather than after one.
String? validateWorkingHoursEdit({
  required String start,
  required String end,
  required List<int> days,
}) {
  final startMinutes = parseWallClock(start);
  final endMinutes = parseWallClock(end);
  if (startMinutes == null) return 'Start must be a 24-hour time like 07:00.';
  if (endMinutes == null) return 'End must be a 24-hour time like 17:00.';
  if (startMinutes >= endMinutes) {
    return 'Start must be before end on the same day.';
  }
  if (days.isEmpty) return 'Pick at least one working day.';
  return null;
}

/// `HH:MM` as minutes since midnight, or null. Mirrors the server exactly —
/// `7:00` and `07:00:00` are refused there, so they are refused here.
int? parseWallClock(String value) {
  final match = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(value.trim());
  if (match == null) return null;
  return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
}

/// Zones offered above the full list. Johannesburg leads: it is where every
/// current field team works, and the zone a new client starts in.
const List<String> suggestedTimeZones = <String>[defaultClientTimeZone];

/// The picker's two sections for a search [query].
///
/// With no query, [suggested] holds [suggestedTimeZones] followed by [current]
/// (when it is not already one of them), and [all] holds every other zone, so
/// nothing is listed twice. With a query, matching is case-insensitive and
/// treats a space as the underscore IANA names use ("new york" finds
/// `America/New_York`); [suggested] is empty and any suggested zone that
/// matches leads [all].
({List<String> suggested, List<String> all}) timezoneOptions(
  String query, {
  required String current,
}) {
  final needle = query.trim().toLowerCase().replaceAll(' ', '_');
  if (needle.isEmpty) {
    final suggested = <String>[
      ...suggestedTimeZones,
      if (!suggestedTimeZones.contains(current)) current,
    ];
    return (
      suggested: suggested,
      all: <String>[
        for (final zone in ianaTimeZones)
          if (!suggested.contains(zone)) zone,
      ],
    );
  }
  final matches = <String>[
    for (final zone in ianaTimeZones)
      if (zone.toLowerCase().contains(needle)) zone,
  ];
  return (
    suggested: const <String>[],
    all: <String>[
      for (final zone in suggestedTimeZones)
        if (matches.contains(zone)) zone,
      for (final zone in matches)
        if (!suggestedTimeZones.contains(zone)) zone,
    ],
  );
}

/// Whether the signed-in user may actually change the scoring config.
///
/// `PATCH /clients/me` is `requireRole('admin')`. A manager can *read* the
/// config — they should, it explains their own scores — but offering them a
/// Save button they can never use is a trap: it fails with a 403 after they
/// have done the work of filling the form in.
bool canEditConfig(WidgetRef ref) =>
    ref.watch(sessionControllerProvider).value?.role == 'admin';

/// Whether the signed-in user may change the client's timezone.
///
/// Wider than [canEditConfig]: `PATCH /clients/me` accepts `timezone` from a
/// manager too (#309), while weights and thresholds stay admin-only.
bool canEditTimezone(WidgetRef ref) {
  final role = ref.watch(sessionControllerProvider).value?.role;
  return role == 'manager' || role == 'admin';
}

/// A save failure in words a human can act on, rather than a stack trace.
///
/// [forbidden] is what a 403 means for the thing being saved.
String describeSaveFailure(
  Object error, {
  String forbidden = 'Only an administrator can change scoring config.',
}) {
  if (error is DioException && error.response?.statusCode == 403) {
    return forbidden;
  }
  if (error is DioException && error.response?.statusCode == 400) {
    final message = error.response?.data;
    if (message is Map && message['error'] is String) {
      return message['error'] as String;
    }
    return 'The server rejected those values.';
  }
  // Never the exception's own text: a message that is sometimes an exception
  // is a message that will one day carry a host name into a screenshot.
  return TorchErrorMessage.sanitise(error).body;
}

/// Shown to a manager in place of the controls they cannot use.
class ReadOnlyNotice extends StatelessWidget {
  const ReadOnlyNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      key: ValueKey<String>('read-only-notice'),
      scope: EmptyScope.inline,
      headline: 'Read-only.',
      body:
          'Only an administrator can change scoring config — these figures '
          'are shown because they explain your scores.',
    );
  }
}
