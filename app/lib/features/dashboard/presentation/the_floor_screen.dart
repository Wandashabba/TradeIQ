import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/torch_scope.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/console_frame.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/plate/plate.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../visits/data/visit_detail_repository.dart';
import '../data/dashboard_repository.dart';
import '../data/floor_repository.dart';
import 'first_run_board.dart';

/// THE FLOOR — the manager's home.
///
/// It answers one question on a 360×640dp phone: *what is broken, and who is
/// fixing it?* Everything on it is in service of that sentence, and anything
/// that was not has been cut.
///
/// ```text
///   PLATE            a real shelf, one strip of light, the hero figure on it
///   ── ground ──
///   OSA              the one dominant metric, its supports as meta
///   Needs a decision 5      the knocked-out section rule
///   ▌ Outlet name          worst first, five and then a count
///   ▌ …
///   [ nav pill ] ( + )
/// ```
///
/// No cards. No shadows. Nothing centred. Separation is whitespace, mass and
/// rhythm, because a fill or a line under 2:1 is invisible on a cheap panel in
/// daylight.
///
/// ## The two ambers, counted
///
/// Night allows two lit objects in the composed frame. The nav pill's active
/// tab is slot 1 whenever the nav renders; this route spends slot 2 on the
/// plate's strip light. Everything else that might have asked is unlit **by
/// construction rather than by argument**: the hero's delta is severity
/// crimson, every sparkline's last dot is severity crimson, the section rule
/// has no colour at all, and the nav circle is denied by the ladder. When
/// there is no photograph the plate's grant goes unspent and the screen
/// renders one amber object — a budget is a ceiling, not a quota.
///
/// ## Unknown is not zero
///
/// A brand-new tenant gets the [FirstRunBoard], not a scoreboard of zeros. A
/// tenant with outlets but no visits in this window gets The Floor with em
/// dashes, sentences and no deltas — never-measured and not-measured-lately
/// are different facts. The distinction comes from the server's `totals`, not
/// from a figure that happens to be 0.
class TheFloorScreen extends ConsumerWidget {
  const TheFloorScreen({super.key});

  /// The [TorchClaim] id the plate's strip light is declared under.
  static const String plateClaimId = 'floor-plate-strip-light';

  /// The nav circle's id. It is declared and then *denied*, every time: the
  /// plate takes the one content grant at rung 2 and the circle sits at rung
  /// 4. Naming it anyway is what makes the denial visible in
  /// `TorchAllocation.describe()` rather than invisible in a widget that
  /// quietly never asked.
  static const String navCircleClaimId = 'floor-standing-action';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(floorViewProvider);

    return view.when(
      loading: () => const _FloorFrame(
        phase: 'loading',
        hasPlatePhoto: false,
        children: <Widget>[_FloorSkeleton()],
      ),
      error: (error, stack) => _FloorFrame(
        phase: 'error',
        hasPlatePhoto: false,
        children: <Widget>[
          _FloorError(onRetry: () => ref.invalidate(floorViewProvider)),
        ],
      ),
      data: (data) {
        if (data.phase == FloorPhase.firstRun) {
          return const FirstRunBoard();
        }
        return _Floor(view: data);
      },
    );
  }
}

/// The frame every state of this route wears, so a skeleton, an error and the
/// real thing are the same screen in three conditions rather than three
/// screens.
class _FloorFrame extends StatelessWidget {
  const _FloorFrame({
    required this.phase,
    required this.hasPlatePhoto,
    required this.children,
  });

  final String phase;
  final bool hasPlatePhoto;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return TorchScope(
      skin: context.skin,
      phase: phase,
      navRenders: true,
      tabbedRoute: true,
      claims: <TorchClaim>[
        // Declared only when there is something to light. The allocator is
        // told the truth about the frame rather than handed a claim the
        // widget will then decline to spend.
        if (hasPlatePhoto)
          const TorchClaim.plateStripLight(TheFloorScreen.plateClaimId),
      ],
      child: FloorScaffold(children: children),
    );
  }
}

/// The scroll frame: [TorchShell] in its console profile, with the manager's
/// four nav slots and the standing action beside them.
///
/// The Floor carries **no app header**. The plate is the header: it runs
/// full-bleed to the top edge and its eyebrow names the territory and the
/// week, which is everything a title bar would have said. A 56dp title row
/// above a photograph that already says where you are is the fold spent
/// twice.
///
/// The consequence is named rather than hidden: the skin cycle lives in the
/// header's single trailing slot on a tab root, and this route has no header
/// to put it in. On The Floor it belongs in the Menu destination, which is
/// where the manager's overflow lives — see the follow-up for the Menu sheet.
///
/// ## The nav is the console's nav, not a copy of it
///
/// This frame exists because The Floor cannot use [ConsoleFrame] — it has no
/// app header, and the plate has to run full-bleed to the top edge. What it
/// must **not** do is own a second copy of the bar. It did: a private slot
/// list, `activeIndex: 0`, `onSelect: onSelectSlot ?? (_) {}` with no caller
/// ever passing `onSelectSlot`, and `onPressed: () {}` on the circle. The
/// manager's home screen shipped with four destinations and a standing action
/// that pressed, buzzed, scaled to 0.98 and did nothing — the one defect a
/// widget test of the pill in isolation can never see.
///
/// So the slots come from [consoleNavSlots] and the press goes through
/// [consoleNavSelect], exactly as every other console route's do.
class FloorScaffold extends StatelessWidget {
  const FloorScaffold({
    super.key,
    required this.children,
    this.onSelectSlot,
    this.onStandingAction,
  });

  final List<Widget> children;

  /// Overrides the console's own routing. Null is the real app: the bar goes
  /// where [consoleNavSelect] says, which is the only place it may go.
  final ValueChanged<int>? onSelectSlot;

  /// Overrides what the `+` circle opens. Null is the real app.
  final VoidCallback? onStandingAction;

  @override
  Widget build(BuildContext context) {
    return TorchShell(
      profile: TorchShellProfile.console,
      navPill: TorchNavPill(
        slots: consoleNavSlots,
        activeIndex: ConsoleSlot.floor.index,
        onSelect: onSelectSlot ?? (index) => consoleNavSelect(context, index),
      ),
      navCircle: TorchNavCircle(
        claimId: TheFloorScreen.navCircleClaimId,
        // The circle is the role's standing action and it is *never* lit on
        // this route: the ladder denies rung 4 once the plate has taken the
        // one content grant. Declaring `expected` honestly and letting the
        // allocator say no is the point — a circle that decided for itself
        // would be a third light.
        expected: false,
        icon: Icons.add,
        expectedIcon: Icons.add,
        semanticLabel: 'Raise a task or assign a visit',
        expectedSemanticLabel: 'Raise a task or assign a visit',
        onPressed:
            onStandingAction ?? () => showFloorStandingAction(context),
      ),
      children: children,
    );
  }
}

/// THE STANDING ACTION'S TWO VERBS.
///
/// The circle's own label has always promised "Raise a task or assign a
/// visit", and `surface-manager.json` says in as many words that tapping it
/// opens exactly that pair. It opened nothing. A circle that names two verbs
/// and performs neither is worse than no circle: it teaches a manager that
/// the chrome on this screen is decoration.
///
/// One sheet, two rows, both to destinations that already exist. It is
/// deliberately *not* a third nav destination and deliberately not a form:
/// raising a task from a blank page is not a thing this product does — a task
/// is raised against a finding, and the finding is on the Work queue.
///
/// **Amber: none.** A menu commits nothing, and while it is up every amber on
/// the route beneath goes out (unify §1.10).
Future<void> showFloorStandingAction(BuildContext context) {
  return showTorchSheet<void>(
    context,
    builder: (sheetContext) => const FloorStandingActionSheet(),
  );
}

/// The sheet's body — public so a test can pump it without a scrim.
class FloorStandingActionSheet extends StatelessWidget {
  const FloorStandingActionSheet({super.key});

  @override
  Widget build(BuildContext context) {
    void leaveFor(String route) {
      Navigator.of(context).pop();
      context.go(route);
    }

    return TorchSheet(
      title: 'Raise a task or assign a visit',
      subtitle: 'Two ways to put somebody on a problem.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SoftRow(
            key: const ValueKey<String>('floor-standing-raise-task'),
            density: SoftRowDensity.compact,
            title: 'Raise a task',
            subtitle: 'Against a finding on the work queue',
            trailing: const SoftRowChevron(),
            onTap: () => leaveFor('/tasks'),
          ),
          SoftRow(
            key: const ValueKey<String>('floor-standing-assign-visit'),
            density: SoftRowDensity.compact,
            title: 'Assign a visit',
            subtitle: 'Send an agent to an outlet today',
            trailing: const SoftRowChevron(),
            onTap: () => leaveFor('/dispatch'),
          ),
        ],
      ),
    );
  }
}

class _Floor extends ConsumerWidget {
  const _Floor({required this.view});

  final FloorView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = view.plateSubject;
    final hasPhoto = subject?.evidencePhotoId != null;
    final measured = view.phase == FloorPhase.measured;

    // `TorchShell` gutter-pads its children; a `SoftRow` and the plate pad
    // themselves. Exactly two children opt back out to the screen's edges
    // rather than un-padding the shell for everything — see [_Bleed].
    return _FloorFrame(
      phase: measured ? 'loaded' : 'window-empty',
      hasPlatePhoto: hasPhoto,
      children: <Widget>[
        // 1. THE PLATE — full-bleed.
        TorchBleed(
          extra: context.skin.space.gutter * 2,
          child: _FloorPlate(view: view),
        ),
        const SizedBox(height: TiqSpace.s6),

        // 2. THE ONE DOMINANT METRIC, on the ground.
        _AvailabilityTile(view: view),

        // s6 and not s8 above the rule: on a phone the 40dp of deliberate
        // nothing cost half a decision row, and it survives only at >= 600dp.
        const SizedBox(height: TiqSpace.s6),

        // 3. THE SECTION RULE.
        SectionRule(
          'Needs a decision',
          count: view.decisions.isEmpty ? null : view.decisions.length,
          emptyLine: view.nothingNeedsADecision ? 'Everything triaged.' : null,
        ),
        const SizedBox(height: TiqSpace.s5),

        // 4. THE DECISION ROWS — worst first, and out to the edges because a
        //    row owns its own gutter and draws its rule inset to the text.
        TorchBleed(
          extra: context.skin.space.gutter * 2,
          child: _DecisionList(view: view),
        ),
      ],
    );
  }
}

class _DecisionList extends ConsumerWidget {
  const _DecisionList({required this.view});

  final FloorView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = view.visible;
    if (visible.isEmpty) return const SizedBox.shrink();
    final now = ref.read(nowProvider)();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var i = 0; i < visible.length; i++)
          _DecisionRowFor(
            decision: visible[i],
            now: now,
            last: i == visible.length - 1 && view.moreCount == 0,
          ),
        if (view.moreCount > 0) _MoreRow(count: view.moreCount),
      ],
    );
  }
}

/// One decision, as a row.
class _DecisionRowFor extends StatelessWidget {
  const _DecisionRowFor({
    required this.decision,
    required this.now,
    required this.last,
  });

  final FloorDecision decision;
  final DateTime now;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final age = decision.ageHoursAt(now);

    return DecisionRow(
      title: decision.outletName,
      reason: decision.reason,
      severity: decision.severity,
      severityLabel: decision.severityLabel,
      // The column means ONE thing on every row: how long this has been
      // broken. An alert's age and a task's SLA deadline are both times and
      // are not the same measurement, so only one of them is allowed here.
      value: age,
      unit: TiqUnit.worded('h', tight: true),
      figureState: age == null ? FigureState.missing : FigureState.measured,
      valueSemanticsLabel: age == null
          ? 'No time recorded for this finding'
          : 'Open for ${age.round()} hours',
      // The sparkline slot stays empty until there is a real per-outlet
      // series to put in it. `DecisionRow` omits the slot rather than holding
      // a gap, and inventing a shape here would be the one thing the
      // component's own doc forbids. See the follow-up ticket.
      sparkline: null,
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      onTap: () {},
    );
  }
}

/// `and 11 more need a decision` — a 44dp meta row into the full worklist.
///
/// The list is always five plus this. A list that grows with the problem stops
/// fitting on the fold at exactly the moment it matters most.
class _MoreRow extends StatelessWidget {
  const _MoreRow({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final spec = SoftRowSpec.resolve(skin: skin);
    return Semantics(
      button: true,
      label: 'and $count more need a decision',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Container(
          constraints: BoxConstraints(minHeight: skin.space.tapTarget),
          padding: EdgeInsets.symmetric(
            horizontal: spec.textInset(hasLeading: false),
            vertical: TiqSpace.s3,
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            'and $count more need a decision',
            style: skin.text.meta.style(color: skin.palette.ink2),
          ),
        ),
      ),
    );
  }
}

/// On-shelf availability, and the figures that support it as meta.
///
/// One dominant metric, not a grid: the manager reads one number here and the
/// rest of the instrument is one line beneath it.
class _AvailabilityTile extends StatelessWidget {
  const _AvailabilityTile({required this.view});

  final FloorView view;

  @override
  Widget build(BuildContext context) {
    final snapshot = view.snapshot;
    final current = snapshot.current;
    final measured = view.phase == FloorPhase.measured;
    final n = current.sampleSizes.osaPct;
    final baselineN = snapshot.previous?.sampleSizes.osaPct;
    final delta = snapshot.of((k) => k.osaPct);

    return StatTile(
      eyebrow: 'On-shelf availability',
      // A window with no visits is an absence, not a score of zero. The
      // server's `totals` is what says which, and it is the only thing that
      // can: eight genuine zeros look exactly like eight missing ones.
      value: measured ? current.osaPct : null,
      unit: TiqUnit.percent,
      noDataReason: measured ? null : 'No visits in this window',
      sampling: FigureSampling(
        kind: MetricKind.rate,
        n: n,
        // The baseline denominator is the PREVIOUS window's own sample size,
        // from the second request the console already makes — not an
        // inference from this window's.
        baselineN: baselineN,
      ),
      meter: MeterData(value: measured ? current.osaPct : null),
      delta: measured && delta.hasDelta
          ? DeltaData(
              direction: delta.change! > 0
                  ? DeltaDirection.up
                  : delta.change! < 0
                  ? DeltaDirection.down
                  : DeltaDirection.flat,
              // Severity, never amber: availability falling is bad and
              // availability rising is good, and neither is a light source.
              sentiment: delta.change! > 0
                  ? TiqSentiment.good
                  : delta.change! < 0
                  ? TiqSentiment.bad
                  : TiqSentiment.neutral,
              magnitude: delta.change!.abs(),
              unit: TiqUnit.worded('pts'),
              comparedTo: 'vs the window before',
            )
          : null,
      lead: true,
      subordinates: _supports(view),
      semanticsHint: 'Opens the figures behind on-shelf availability',
    );
  }

  /// The supporting figures, as meta. Coverage and the visit count — the two
  /// numbers that say whether the headline is worth believing.
  static String? _supports(FloorView view) {
    final k = view.snapshot.current;
    final parts = <String>[
      if (k.outletsVisited != null && k.outletsTotal != null)
        'Coverage ${k.outletsVisited} of ${k.outletsTotal} outlets',
      if (k.visits != null) '${k.visits} visits',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// The plate, wired to the first decision's outlet.
class _FloorPlate extends ConsumerWidget {
  const _FloorPlate({required this.view});

  final FloorView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = view.plateSubject;
    final photoId = subject?.evidencePhotoId;

    // The bytes. `thumbnailBytes` is the ≤60 kB, LRU-cached, authed route —
    // which is already the byte cap the design declares for a baked plate, and
    // the only honest one to spend on a prepaid bundle. `Image.network` cannot
    // carry the bearer token on web, so bytes is also the only route that
    // works at all.
    //
    // FOLLOW-UP (plate bake ticket, filed with this PR): serve a purpose-baked
    // plate asset — 12% chroma, #474747 luminance ceiling, alpha edge
    // dissolve, ≤60 kB WebP — and read it here instead of a shelf thumbnail.
    final image = photoId == null
        ? null
        : ref.watch(plateImageResolverProvider)(ref, photoId);

    // Provenance. Metadata only — `GET /visits/:id` never carries an image —
    // so this costs a small request and buys the caption that keeps the plate
    // a specimen rather than an assertion.
    final captureTime = subject?.visitId == null
        ? null
        : ref
              .watch(visitDetailProvider(subject!.visitId!))
              .maybeWhen(
                data: (d) => d.photos
                    .where((p) => p.id == photoId)
                    .map((p) => p.timestamp)
                    .firstOrNull,
                orElse: () => null,
              );

    final outletName = subject?.outletName;
    final caption = <String>[
      ?outletName,
      if (captureTime != null) _shortTimestamp(captureTime),
    ].join(' · ');

    return _PlateFor(
      view: view,
      image: image,
      caption: caption.isEmpty ? null : caption,
    );
  }

  static String _shortTimestamp(DateTime t) {
    const months = <String>[
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
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '${t.day} ${months[t.month - 1]} $hh:$mm';
  }
}

/// Split from [_FloorPlate] so the plate and its hero cluster can be built in
/// a test without a Riverpod container.
class _PlateFor extends StatelessWidget {
  const _PlateFor({
    required this.view,
    required this.image,
    required this.caption,
  });

  final FloorView view;
  final ImageProvider<Object>? image;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final snapshot = view.snapshot;
    final current = snapshot.current;
    final measured = view.phase == FloorPhase.measured;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final spec = PlateSpec.resolve(skin: skin, viewportHeight: viewportHeight);

    final delta = snapshot.of((k) => k.executionScore);
    final n = current.sampleSizes.executionScore;
    final baselineN = snapshot.previous?.sampleSizes.executionScore;
    final lowSample = TiqSample.isLow(MetricKind.score, n);

    final figureState = !measured
        ? FigureState.missing
        : lowSample
        ? FigureState.lowSample
        : FigureState.measured;

    return TiqPlate(
      claimId: TheFloorScreen.plateClaimId,
      viewportHeight: viewportHeight,
      image: image,
      caption: caption,
      // Never a stock image and never a gradient pretending to be a
      // photograph: a drawing that is visibly a drawing, and a sentence.
      fallbackSentence: view.plateSubject == null
          ? 'No shelf photo yet. This becomes your territory’s availability '
                'when the first visits land.'
          : 'No shelf photo from ${view.plateSubject!.outletName} yet.',
      semanticLabel: caption,
      hero: PlateHeroCluster(
        eyebrow: '${view.territoryName} · ${view.windowLabel}',
        figure: FigureSlot(
          value: measured ? current.executionScore : null,
          role: spec.figureRole,
          fit: <TiqTypeToken>[
            spec.figureRole,
            skin.text.heroFigureCompact,
            skin.text.display,
          ],
          state: figureState,
          semanticsLabel: measured
              ? null
              : 'Territory health, no visits in this window',
        ),
        // Severity-coloured, never amber. `DeltaSlot` also removes it outright
        // beside a missing figure or a thin sample — a delta never stands
        // beside nothing, and a delta off a thin baseline is a number
        // pretending to be a movement.
        delta: DeltaSlot(
          data: delta.hasDelta
              ? DeltaData(
                  direction: delta.change! > 0
                      ? DeltaDirection.up
                      : delta.change! < 0
                      ? DeltaDirection.down
                      : DeltaDirection.flat,
                  sentiment: delta.change! > 0
                      ? TiqSentiment.good
                      : delta.change! < 0
                      ? TiqSentiment.bad
                      : TiqSentiment.neutral,
                  magnitude: delta.change!.abs(),
                  unit: TiqUnit.worded('pts'),
                )
              : null,
          figureState: figureState,
          sampling: FigureSampling(
            kind: MetricKind.score,
            n: n,
            baselineN: baselineN,
          ),
          compact: true,
        ),
        healthLine: Text(
          'Territory health',
          style: skin.text.label.style(color: skin.palette.ink2),
        ),
        onHealthTap: () {},
      ),
    );
  }
}

class _FloorSkeleton extends StatelessWidget {
  const _FloorSkeleton();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final height = PlateSpec.heightFor(MediaQuery.sizeOf(context).height);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // The skeleton is the real geometry, empty — not a spinner, and not a
        // `well` block at 1.12:1 that nobody can see.
        SizedBox(
          height: height < 200 ? 96 : height,
          child: ColoredBox(color: skin.palette.edgeStructure),
        ),
        const SizedBox(height: TiqSpace.s6),
        for (var i = 0; i < 3; i++) ...<Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: skin.space.gutter),
            child: SizedBox(
              height: TiqSpace.s5,
              child: ColoredBox(color: skin.palette.edgeStructure),
            ),
          ),
          const SizedBox(height: TiqSpace.s6),
        ],
      ],
    );
  }
}

class _FloorError extends StatelessWidget {
  const _FloorError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Padding(
      padding: EdgeInsets.all(skin.space.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'The floor could not be loaded.',
            style: skin.text.titleM.style(color: skin.palette.ink1),
          ),
          const SizedBox(height: TiqSpace.s3),
          Text(
            'Nothing here is a zero — the figures simply did not arrive.',
            style: skin.text.body.style(color: skin.palette.ink2),
          ),
          const SizedBox(height: TiqSpace.s4),
          Semantics(
            button: true,
            label: 'Retry',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRetry,
              child: SizedBox(
                height: skin.space.tapTarget,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Retry',
                    style: skin.text.label.style(color: skin.palette.ink1),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
