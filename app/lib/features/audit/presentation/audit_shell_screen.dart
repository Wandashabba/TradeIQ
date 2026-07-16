import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/agent_kit.dart';
import '../../../core/widgets/agent_motion.dart';
import '../../../core/widgets/agent_scaffold.dart';
import '../../outlets/data/outlets_repository.dart';
import '../data/visit_progress.dart';
import '../data/visits_repository.dart';
import 'submit_gate_screen.dart';
import 'sections/s1_outlet_info_screen.dart';
import 'sections/s2_stock_screen.dart';
import 'sections/s3_4_visibility_display_screen.dart';
import 'sections/s5_pricing_promotions_screen.dart';
import 'sections/s6_competitive_screen.dart';
import 'sections/s7_capability_screen.dart';
import 'sections/s8_risks_screen.dart';
import 'sections/s9_action_plan_screen.dart';
import 'sections/s10_scorecard_screen.dart';

/// The visit hub.
///
/// This replaces a Material [Stepper] whose steps were built with
/// `Step(title: SizedBox.shrink())` — nine sections with *no titles at all*, on
/// one long scroll. An agent could not see which section they were on, what was
/// done, or what was left.
///
/// Sections can be done in any order, because a store will not always let you
/// follow one: you cannot count stock while a delivery is blocking the aisle.
class AuditShellScreen extends ConsumerStatefulWidget {
  const AuditShellScreen({super.key, required this.outletId});

  final String outletId;

  @override
  ConsumerState<AuditShellScreen> createState() => _AuditShellScreenState();
}

class _AuditShellScreenState extends ConsumerState<AuditShellScreen> {
  bool _checkInStarted = false;
  CheckInResult? _checkInResult;
  DateTime? _checkinTs;
  String? _visitDraftId;

  Future<void> _startCheckIn(double outletLat, double outletLng) async {
    final result = await ref.read(visitsRepositoryProvider).checkIn(
          outletId: widget.outletId,
          outletLat: outletLat,
          outletLng: outletLng,
        );
    if (!mounted) return;
    setState(() {
      _checkInResult = result;
      if (result is CheckInSucceeded) {
        _checkinTs = DateTime.now();
        _visitDraftId = result.visitId;
      }
    });
  }

  Outlet? _findOutlet(List<Outlet> outlets) {
    for (final outlet in outlets) {
      if (outlet.id == widget.outletId) return outlet;
    }
    return null;
  }

  Widget _sectionBody(AuditSection section, String visitDraftId) {
    return switch (section) {
      AuditSection.outletInfo => S1OutletInfoScreen(checkinTs: _checkinTs),
      AuditSection.stock => S2StockScreen(visitDraftId: visitDraftId, outletId: widget.outletId),
      AuditSection.visibility =>
        S3S4VisibilityDisplayScreen(visitDraftId: visitDraftId),
      AuditSection.pricing => S5PricingPromotionsScreen(
          visitDraftId: visitDraftId,
          outletId: widget.outletId,
        ),
      AuditSection.competitive => S6CompetitiveScreen(visitDraftId: visitDraftId),
      AuditSection.capability => S7CapabilityScreen(visitDraftId: visitDraftId),
      AuditSection.risks => S8RisksScreen(visitDraftId: visitDraftId),
      AuditSection.actionPlan => S9ActionPlanScreen(
          visitDraftId: visitDraftId,
          outletId: widget.outletId,
        ),
      AuditSection.score => S10ScorecardScreen(visitDraftId: visitDraftId),
    };
  }

  /// One section, full screen. No nesting, no long scroll of nine forms.
  ///
  /// It slides in from the right, which says "you have gone *into* something and
  /// can come back out" — exactly the hub/section relationship.
  void _openSection(AuditSection section, String visitDraftId) {
    Navigator.of(context).push(
      agentSectionRoute<void>(
        _SectionScreen(
          title: section.label,
          child: _sectionBody(section, visitDraftId),
        ),
      ),
    );
  }

  /// Submitting is irreversible and it raises tasks against a real shop. It does
  /// not happen on one tap of a hub button — the agent gets to see what they are
  /// about to say about this store, and confirm it.
  Future<void> _openSubmitGate(Outlet outlet) async {
    final id = _visitDraftId;
    if (id == null) return;

    final confirmed = await Navigator.of(context).push<bool>(
      agentSectionRoute<bool>(
        SubmitGateScreen(
          visitDraftId: id,
          outletId: outlet.id,
          outletName: outlet.name,
          checkinTs: _checkinTs,
          onConfirm: () => Navigator.of(context).pop(true),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref.read(visitsRepositoryProvider).submitVisit(id);
    if (!mounted) return;

    // The visit is done. Let them feel it — they are about to walk out of the
    // shop and will not be looking at the screen.
    Buzz.done();
    // The score is the outcome of the visit, so it is where the visit ends.
    // `go` rather than `push`: there is no way back into a submitted visit.
    context.go('/audit/${outlet.id}/done?draft=$id&name=${Uri.encodeComponent(outlet.name)}');
  }

  @override
  Widget build(BuildContext context) {
    final outletsAsync = ref.watch(outletsListProvider);

    return outletsAsync.when(
      loading: () => const AgentScaffold(
        title: 'Starting visit',
        showSyncChip: false,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => AgentScaffold(
        title: 'Visit',
        showSyncChip: false,
        body: Center(child: Text('Failed to load outlet: $err')),
      ),
      data: (outlets) {
        final outlet = _findOutlet(outlets);
        if (outlet == null) {
          return const AgentScaffold(
            title: 'Visit',
            showSyncChip: false,
            body: Center(child: Text('Outlet not found')),
          );
        }

        if (!_checkInStarted) {
          _checkInStarted = true;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _startCheckIn(outlet.lat, outlet.lng),
          );
        }

        return switch (_checkInResult) {
          null => _CheckingIn(outlet: outlet),
          CheckInSucceeded() => _hub(outlet),
          CheckInGeofenceFailed(:final distanceMeters) => _TooFar(
              outlet: outlet,
              distanceMeters: distanceMeters,
              onRetry: () => setState(() {
                _checkInStarted = false;
                _checkInResult = null;
              }),
            ),
          CheckInLocationUnavailable(:final message) => _NoLocation(
              outlet: outlet,
              message: message,
              onRetry: () => setState(() {
                _checkInStarted = false;
                _checkInResult = null;
              }),
            ),
        };
      },
    );
  }

  Widget _hub(Outlet outlet) {
    final visitDraftId = _visitDraftId!;
    final progressAsync = ref.watch(
      visitProgressProvider((visitDraftId: visitDraftId, outletId: widget.outletId)),
    );

    return progressAsync.when(
      loading: () => AgentScaffold(
        title: outlet.name,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => AgentScaffold(
        title: outlet.name,
        body: Center(child: Text('Could not read this visit: $err')),
      ),
      data: (progress) {
        final blocking = progress.blocking;

        return AgentScaffold(
          title: outlet.name,
          subtitle: _checkinTs == null
              ? null
              : 'In store ${formatAgo(_checkinTs!).replaceAll(' ago', '')}',
          bottomAction: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // A blocked action explains itself. A dead end in a shop is a
              // phone call to the manager.
              if (blocking.isNotEmpty)
                BarNote(
                  'Finish ${blocking.map((s) => s.label).join(' and ')} to submit',
                ),
              AgentButton(
                key: const ValueKey('submit-visit'),
                label: 'Submit visit',
                onPressed:
                    progress.canSubmit ? () => _openSubmitGate(outlet) : null,
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              _Progress(progress: progress),
              const SizedBox(height: 18),
              const _Heading('The audit'),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(AppColors.radiusPanel),
                ),
                child: Column(
                  children: [
                    for (final (i, section) in AuditSection.values.indexed)
                      Reveal(
                        index: i,
                        child: _SectionRow(
                          section: section,
                          state: progress.stateOf(section),
                          detail: progress.details[section],
                          last: section == AuditSection.values.last,
                          // The score is the RESULT of the other eight, so it
                          // cannot be opened and filled in.
                          onTap: section == AuditSection.score
                              ? null
                              : () => _openSection(section, visitDraftId),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Do the sections in any order — the store will not always let you '
                'follow one. Everything saves as you go, even with no signal.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.ink3,
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A section, full screen, with its own way back to the hub.
class _SectionScreen extends StatelessWidget {
  const _SectionScreen({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AgentScaffold(
      title: title,
      subtitle: 'Saves as you go',
      onBack: () => Navigator.of(context).pop(),
      bottomAction: AgentButton(
        label: 'Done · back to visit',
        onPressed: () => Navigator.of(context).pop(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: child,
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.progress});

  final VisitProgress progress;

  @override
  Widget build(BuildContext context) {
    final done = progress.doneCount;
    final total = progress.captureCount;
    final blocking = progress.blocking.length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppColors.radiusPanel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Row(
                  key: const ValueKey('visit-progress'),
                  children: [
                    // The count rolls up as sections land — nine small wins a
                    // visit, and each one should be visible.
                    AnimatedCount(
                      value: done,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink1,
                      ),
                    ),
                    Text(
                      ' of $total sections',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                blocking == 0
                    ? 'Ready to submit'
                    : '$blocking still required',
                style: TextStyle(
                  fontSize: 12,
                  color: blocking == 0 ? AppColors.good : AppColors.ink3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: total == 0 ? 0 : done / total),
              duration: reduceMotion(context) ? Duration.zero : Motion.slow,
              curve: Motion.enter,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: AppColors.surface3,
                valueColor: AlwaysStoppedAnimation(
                  // The bar turns green the moment the visit is submittable —
                  // "you can go" said in colour, before it is said in words.
                  blocking == 0 ? AppColors.good : AppColors.series1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.9,
          color: AppColors.ink3,
        ),
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.section,
    required this.state,
    required this.detail,
    required this.last,
    required this.onTap,
  });

  final AuditSection section;
  final SectionState state;
  final String? detail;
  final bool last;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isScore = section == AuditSection.score;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('section-${section.name}'),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: AppColors.line)),
          ),
          child: Opacity(
            opacity: isScore ? 0.7 : 1,
            child: Row(
              children: [
                _StateMark(state: state, isScore: isScore),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        section.label,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.ink1,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        isScore
                            ? 'Calculated when you submit'
                            : detail ??
                                (section.required
                                    ? 'Not started'
                                    : 'Optional'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.ink3,
                        ),
                      ),
                      if (section.required && state != SectionState.done)
                        const Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: Text(
                            'REQUIRED TO SUBMIT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: AppColors.crit,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (onTap != null)
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.ink3,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// State is a shape *and* a colour — readable in glare, in greyscale, and under
/// colour-vision deficiency.
class _StateMark extends StatelessWidget {
  const _StateMark({required this.state, required this.isScore});

  final SectionState state;
  final bool isScore;

  @override
  Widget build(BuildContext context) {
    if (isScore) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: Center(
          child: Text('—', style: TextStyle(color: AppColors.ink3)),
        ),
      );
    }

    // Done draws its tick; the other two are static marks. Completing a section
    // is the small win the agent gets nine times a visit — it should land, not
    // blink into existence.
    if (state == SectionState.done) {
      return const TickMark(done: true);
    }

    final color = state == SectionState.partial ? AppColors.warn : AppColors.ink3;

    return AnimatedContainer(
      duration: reduceMotion(context) ? Duration.zero : Motion.base,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
      child: state == SectionState.partial
          ? Icon(Icons.more_horiz, size: 13, color: color)
          : null,
    );
  }
}

// ── Check-in states ────────────────────────────────────────────────────────

class _CheckingIn extends StatelessWidget {
  const _CheckingIn({required this.outlet});

  final Outlet outlet;

  @override
  Widget build(BuildContext context) {
    return AgentScaffold(
      title: outlet.name,
      subtitle: outlet.code,
      showSyncChip: false,
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // A radar, not a spinner. A spinner says "something is happening";
              // this says "we are looking for you", which is what waiting for a
              // GPS fix actually is.
              _LocatingRadar(),
              SizedBox(height: 22),
              Text(
                'Finding you…',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink1,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'You must be within 50 m of the store to check in. '
                'This is what proves the visit happened.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppColors.ink2,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The geofence failure. It used to be a bare sentence with a "Back to outlets"
/// button — a dead end. It now shows the measured distance against the
/// threshold, offers a way forward, and is honest that hammering retry from far
/// away is itself a fraud signal (it is: `failed_attempts` carries up to 25
/// risk points, and every attempt is recorded server-side).
class _TooFar extends StatelessWidget {
  const _TooFar({
    required this.outlet,
    required this.distanceMeters,
    required this.onRetry,
  });

  final Outlet outlet;
  final double distanceMeters;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AgentScaffold(
      title: outlet.name,
      subtitle: outlet.code,
      showSyncChip: false,
      bottomAction: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AgentButton(
            key: const ValueKey('checkin-retry'),
            label: 'Try again',
            onPressed: onRetry,
          ),
          const SizedBox(height: 8),
          AgentButton(
            label: 'Back to route',
            secondary: true,
            onPressed: () => context.go('/audit'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.location_off_outlined,
              size: 52,
              color: AppColors.crit,
            ),
            const SizedBox(height: 20),
            const Text(
              'You’re too far away',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.ink1,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Move closer to the store and try again. Nothing is lost — the '
              'visit hasn’t started.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.ink2,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              key: const ValueKey('checkin-distance'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.crit.withValues(alpha: 0.4),
                ),
                borderRadius: BorderRadius.circular(AppColors.radiusControl),
              ),
              child: Text(
                '${distanceMeters.round()} m away · need 50 m or closer',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.crit,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'This attempt is recorded. Retrying from far away is itself a '
              'fraud signal, so it is better to walk closer than to keep '
              'tapping.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.ink3,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoLocation extends StatelessWidget {
  const _NoLocation({
    required this.outlet,
    required this.message,
    required this.onRetry,
  });

  final Outlet outlet;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AgentScaffold(
      title: outlet.name,
      subtitle: outlet.code,
      showSyncChip: false,
      bottomAction: AgentButton(
        key: const ValueKey('checkin-retry'),
        label: 'Try again',
        onPressed: onRetry,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.gps_off_outlined,
              size: 52,
              color: AppColors.warn,
            ),
            const SizedBox(height: 20),
            const Text(
              'Can’t find your location',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.ink1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.ink2,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Concentric rings sweeping outward while we wait for a GPS fix.
///
/// This is the one place a longer, looping animation earns its keep: the agent
/// is standing still, waiting, and the app has to show it is working. It stops
/// the moment we have a fix.
class _LocatingRadar extends StatefulWidget {
  const _LocatingRadar();

  @override
  State<_LocatingRadar> createState() => _LocatingRadarState();
}

class _LocatingRadarState extends State<_LocatingRadar>
    with SingleTickerProviderStateMixin {
  // Eager, not `late final`: a lazily-created controller would first be built by
  // dispose() whenever build skipped it (reduced motion), and constructing a
  // Ticker against a dead element throws.
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const pin = Icon(Icons.location_on_outlined, size: 40, color: AppColors.series1);

    if (reduceMotion(context)) {
      return const SizedBox(width: 120, height: 120, child: Center(child: pin));
    }

    return SizedBox(
      width: 120,
      height: 120,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Stack(
          alignment: Alignment.center,
          children: [
            // Two rings, half a cycle apart, so there is always one in flight.
            for (final offset in [0.0, 0.5])
              _Ring(t: (_c.value + offset) % 1.0),
            child!,
          ],
        ),
        child: pin,
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40 + 80 * t,
      height: 40 + 80 * t,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.series1.withValues(alpha: 0.45 * (1 - t)),
          width: 1.5,
        ),
      ),
    );
  }
}
