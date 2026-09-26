import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tiq_number.dart' show TiqNumber;
import '../../../core/design/torch_scope.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/card.dart';
import '../../../core/widgets/torchlight/console_frame.dart';
import '../../../core/widgets/torchlight/figure/sparkline.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/plate/plate.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../territories/data/territories_view.dart';
import '../../trends/data/trends_repository.dart';
import '../../visits/data/visit_detail_repository.dart';
import '../data/dashboard_repository.dart';
import '../data/floor_repository.dart';
import 'dashboard_filters.dart';
import 'first_run_board.dart';

/// THE FLOOR — the manager's home.
///
/// It answers one question on a 360×640dp phone: *what is broken, and who is
/// fixing it?* Everything on it is in service of that sentence, and anything
/// that was not has been cut.
///
/// ```text
///   ╭───────────────╮  the plate: a real shelf, one strip of light,
///   │ ──────        │  the hero figure and its delta on it
///   │ 72 ▼19        │
///   ╰───────────────╯
///   ╭───────────────╮  the one dominant metric: label, figure,
///   │ OSA 61%   /\/ │  one line of facts, a sparkline
///   ╰───────────────╯
///   NEEDS A DECISION   words on the ground, no rule and no count
///   ╭───────────────╮  worst first, five and then a count
///   │ • Outlet  48h │
///   ╰───────────────╯
///   ╭───────────────╮
///   [ nav pill ] ( + )
/// ```
///
/// **Cards, since 25 September 2026.** unify §1.3 ruled every list row flush
/// and this screen's blocks bare on the ground; the owner overruled it twice
/// looking at the running screen ("I hate this box style"; "it's still very
/// boxy and I don't need that") and the grammar is now a soft card at radius
/// 22 with a gap of ground between. The override is recorded in
/// `docs/design/spec/unify.md` §1.3 and `docs/design/torchlight-aisle.md`.
/// Still true: no shadows, nothing centred, no gradient inside a list row.
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
      // THE PLATE IS A CARD AND NO LONGER THE TOP EDGE. It ran full-bleed to
      // y=0 until 25 September 2026, and `bleedTop` is what took the shell's
      // 24dp console inset away to let it. The owner's reference insets the
      // plate and rounds it, so the inset comes back for every state — a card
      // hard against the status bar is a card with one edge missing.
      child: FloorScaffold(bleedTop: false, children: children),
    );
  }
}

/// The scroll frame: [TorchShell] in its console profile, with the manager's
/// four nav slots and the standing action beside them.
///
/// The Floor carries **no app header**. The plate is the header: its eyebrow
/// names the territory and the week, which is everything a title bar would
/// have said. A 56dp title row above a photograph that already says where you
/// are is the fold spent twice. (It used to run full-bleed to the top edge as
/// well; since 25 September 2026 it is an inset card and the shell's own
/// console inset is the air above it.)
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
    this.bleedTop = true,
  });

  final List<Widget> children;

  /// Whether the body starts at the top edge. True for every state whose first
  /// child is the plate; see [_FloorFrame].
  final bool bleedTop;

  /// Overrides the console's own routing. Null is the real app: the bar goes
  /// where [consoleNavSelect] says, which is the only place it may go.
  final ValueChanged<int>? onSelectSlot;

  /// Overrides what the `+` circle opens. Null is the real app.
  final VoidCallback? onStandingAction;

  @override
  Widget build(BuildContext context) {
    return TorchShell(
      profile: TorchShellProfile.console,
      // The plate IS the header, so it starts at the top edge. Without this
      // the shell's 24dp console inset put a band of ground above a
      // photograph the design runs full-bleed, and spent 24dp of a 640dp fold
      // on nothing. `PlateSpec.heightFor` has always measured the full
      // viewport "including the status bar, because the plate runs full-bleed
      // to the top edge" — this is the other half of that sentence.
      bleedTop: bleedTop,
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
        onPressed: onStandingAction ?? () => showFloorStandingAction(context),
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

    // `TorchShell` gutter-pads its children, and every block on this screen
    // hangs off that one line: the plate card, the lead card, the section
    // marker and — through its own margin — every decision card. The list is
    // the one child that opts back out to the screen's edges, because a
    // `SoftRow` owns its own gutter; see [TorchBleed].
    return _FloorFrame(
      phase: measured ? 'loaded' : 'window-empty',
      hasPlatePhoto: hasPhoto,
      children: <Widget>[
        // 1. THE PLATE — an inset, rounded card.
        _FloorPlate(view: view),
        // s4 between blocks, and it is arithmetic rather than taste: at s5
        // the third decision card crossed the nav pill on an 844dp phone by
        // five pixels. A card has its own edge, so the air between two of
        // them reads as more than the same number between two bare columns
        // did.
        const SizedBox(height: TiqSpace.s4),

        // 2. THE ONE DOMINANT METRIC, as one card: figure, label, one line of
        //    supporting facts, and a sparkline at the trailing edge.
        _AvailabilityCard(view: view),
        const SizedBox(height: TiqSpace.s4),

        // 3. THE SECTION MARKER — words on the ground. No rule, no count.
        _NeedsADecision(view: view),
        const SizedBox(height: TiqSpace.s3),

        // 4. THE DECISION CARDS — worst first, out to the edges because each
        //    card carries the gutter as its own margin.
        TorchBleed(
          extra: context.skin.space.gutter * 2,
          child: _DecisionList(view: view),
        ),
      ],
    );
  }
}

/// `NEEDS A DECISION`, as words rather than as a rule.
///
/// **Owner override, 25 September 2026, widened 26 September.** unify §1.17
/// used to say a screen-level section marker is the knocked-out rule at
/// `title.m` in sentence case, with The Floor as the single exception. The
/// owner then asked for this screen's design "global and everywhere on the
/// app", so [SectionRule] *is* this marker now and every screen wears it.
///
/// This widget stays a local [Eyebrow] rather than becoming a `SectionRule`
/// for one reason: The Floor's marker takes no count. The count is not
/// dropped, it moves — the list says how many it is not showing in words, at
/// the foot, where a manager who wants the number is already looking.
///
/// The count goes with the line. It was never the thing the marker was for:
/// the list says how many it is not showing in words, at the foot, where a
/// manager who wants the number is already looking.
class _NeedsADecision extends ConsumerWidget {
  const _NeedsADecision({required this.view});

  final FloorView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = context.skin;
    final note = _note();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Two lines, which is the eyebrow role's own allowance: at 2.0× in
        // Afrikaans a one-line marker would ellipsise, and half a section
        // marker is worse than a marker that wraps.
        const Eyebrow('Needs a decision'),
        // The empty state keeps its sentence: a marker with nothing under it
        // is the one case where the screen has to say what the absence means.
        // With a territory chosen there are four different absences and they
        // are four different sentences — "nothing here" and "I could not find
        // out" are not the same fact, which is unify §4 applied to a list
        // rather than to a figure.
        if (note != null) ...<Widget>[
          const SizedBox(height: TiqSpace.s3),
          Text(note, style: skin.text.body.style(color: skin.palette.ink2)),
        ],
        // THE WAY BACK IS ONE TAP. A screen that can be scoped and not
        // unscoped is a trap, and the state that needs the exit is exactly
        // the state that shows it: a filtered list with nothing in it.
        if (view.isFiltered && view.nothingNeedsADecision)
          TorchTertiaryButton(
            key: const ValueKey<String>('floor-clear-territory'),
            label: 'Show all territories',
            onPressed: () => clearFloorTerritory(ref),
          ),
        // The coverage request is the only thing that failed, so the retry is
        // the coverage request — not the route, whose figures are fine.
        if (view.scope == FloorScope.failed)
          TorchTertiaryButton(
            key: const ValueKey<String>('floor-retry-scope'),
            label: 'Retry loading this territory’s outlets',
            onPressed: () =>
                ref.invalidate(territoryCoverageProvider(view.territoryId!)),
          ),
      ],
    );
  }

  /// One sentence per absence, or null when there is a list to read instead.
  String? _note() => switch (view.scope) {
    FloorScope.pending => 'Finding the outlets in ${view.territoryName}…',
    FloorScope.failed =>
      'The outlet list for ${view.territoryName} did not load, so these '
          'decisions are not shown. The figures above are still this '
          'territory’s.',
    _ when !view.nothingNeedsADecision => null,
    _ when view.isFiltered =>
      'Nothing needs a decision in ${view.territoryName} over '
          '${view.windowLabel.toLowerCase()}.',
    _ => 'Everything triaged.',
  };
}

/// Back to every territory, from anywhere on The Floor.
void clearFloorTerritory(WidgetRef ref) => applyTerritory(
  ref,
  ref.read(dashboardFilterProvider),
  allTerritoriesToken,
);

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
      // `push`, not `go`: a decision is read on top of The Floor and the
      // manager comes back to the same scroll offset, which is the behaviour
      // `surface-manager.json` names. `FloorDecision.route` has carried
      // "where tapping the row goes" since the model was written and nothing
      // ever read it.
      onTap: () => context.push(decision.route),
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
        // The full worklist. A row that announces itself as a button and then
        // does nothing is worse than a line of text.
        onTap: () => context.go('/tasks'),
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

/// ON-SHELF AVAILABILITY — one card, four things in it.
///
/// The label, the figure, one line of supporting facts, and a sparkline at
/// the trailing edge. Nothing else.
///
/// **What this replaced, and why.** The tile shipped as four stacked
/// elements: the eyebrow, the figure at near-hero size, a full-width meter,
/// a delta line ("▼ −0.3 pts vs the window before") and a coverage line. That
/// is five reads for a metric the hero above it is already the headline for,
/// and on a 390dp phone it cost the fold a whole decision row. The owner's
/// reference has a card with four things in it, and the two that went are the
/// two that were saying the figure twice:
///
/// * **the meter** — a full-width bar of the same percentage the figure has
///   already printed, at a size that made it the loudest object under the
///   plate;
/// * **the delta line** — a movement on a supporting metric, printed in a
///   sentence, under a hero whose own delta is the screen's one movement.
///   The sparkline carries the shape instead, which is what a shape is for.
///
/// The supporting facts move to the spec's own subordinates —
/// "Coverage 79% · Price compliance 91%" — rather than the raw denominators
/// ("Coverage 33 of 42 outlets · 42 visits"), because the card is a reading
/// and the denominators are provenance. They are one tap away, where the
/// figure's own trend is.
class _AvailabilityCard extends ConsumerWidget {
  const _AvailabilityCard({required this.view});

  final FloorView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = view.snapshot;
    final current = snapshot.current;
    final measured = view.phase == FloorPhase.measured;
    final n = current.sampleSizes.osaPct;
    final baselineN = snapshot.previous?.sampleSizes.osaPct;
    final delta = snapshot.of((k) => k.osaPct);

    // THE SHAPE OF THE LAST FEW PERIODS. `/trends/availability` is the series
    // the overview already draws; the sparkline is the same data at 64×20.
    // A failure or an empty series drops the cell — `Sparkline` renders
    // nothing under two points, and a fabricated shape is the one thing its
    // own doc forbids.
    final trend = ref
        .watch(availabilityTrendProvider)
        .maybeWhen(
          data: (points) => points.map((p) => p.value).toList(),
          orElse: () => const <double>[],
        );

    final tile = StatTile(
      eyebrow: 'On-shelf availability',
      // A window with no visits is an absence, not a score of zero. The
      // server's `totals` is what says which, and it is the only thing that
      // can: eight genuine zeros look exactly like eight missing ones.
      value: measured ? current.osaPct : null,
      unit: TiqUnit.percent,
      // The design asks for a whole-number rate here, as it does for the
      // hero. The server sends no `decimals` for this metric; the screen
      // declares the precision the design specifies rather than rounding
      // inside the widget.
      decimals: 0,
      noDataReason: measured ? null : 'No visits in this window',
      sampling: FigureSampling(
        kind: MetricKind.rate,
        n: n,
        // The baseline denominator is the PREVIOUS window's own sample size,
        // from the second request the console already makes — not an
        // inference from this window's.
        baselineN: baselineN,
      ),
      lead: true,
      // Stacked, not eyebrow-left-figure-right: the reference reads label,
      // figure, facts down the card's leading edge, and the trailing edge
      // belongs to the sparkline.
      layout: StatTileLayout.vertical,
      // The card has already spent its inset; the tile's own would be a
      // second, invisible one.
      padding: EdgeInsets.zero,
      subordinates: _supports(view),
      // The hint has promised this since the tile was written; `onTap` is what
      // makes the promise true. Without it the tile announced itself with a
      // hint and no action.
      onTap: () => context.go('/dashboard/overview'),
      semanticsHint: 'Opens the figures behind on-shelf availability',
    );

    return TorchCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(child: tile),
          if (measured && trend.length >= 2) ...<Widget>[
            const SizedBox(width: TiqSpace.s4),
            Padding(
              // On the figure's baseline rather than the card's: a shape
              // floating level with the label reads as decoration.
              padding: const EdgeInsets.only(bottom: TiqSpace.s4),
              child: Sparkline(
                points: trend,
                // The last dot takes the metric's own verdict, never amber:
                // a falling availability is bad and a rising one is good.
                severity: !delta.hasDelta
                    ? null
                    : delta.change! < 0
                    ? SeverityMarkKind.watch
                    : SeverityMarkKind.onTarget,
                semanticsLabel: null,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The supporting figures, as one line of meta. Coverage and price
  /// compliance — the manager spec's own subordinates for this indicator.
  static String? _supports(FloorView view) {
    // An unmeasured window has no supports to state: the tile is already
    // saying "No visits in this window" under an em dash, and a line of
    // zeros under that sentence is the scoreboard of zeros this screen
    // exists to refuse.
    if (view.phase != FloorPhase.measured) return null;
    final k = view.snapshot.current;
    final visited = k.outletsVisited;
    final total = k.outletsTotal;
    return <String>[
      // Coverage needs a denominator to be a rate; without `totals` on the
      // wire there is no honest percentage to print.
      if (visited != null && total != null && total > 0)
        'Coverage ${(visited * 100 / total).round()}%',
      // Price compliance is printed whatever it is, including 0%. A measured
      // zero renders zero — it is a finding, and suppressing it would be the
      // one thing unify §4 says a figure may never do.
      'Price compliance ${k.priceCompliancePct.round()}%',
    ].join(' · ');
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
    // THE PROVENANCE. It used to print on the plate's first line; the
    // reference the owner signed off has no caption, so it is carried as the
    // image's semantic label instead — the specimen is still named for
    // anything that reads the screen, and the plate is still a photograph of
    // one identified shop rather than an anonymous mood.
    final caption = <String>[
      ?outletName,
      if (captureTime != null) _shortTimestamp(captureTime),
    ].join(' · ');

    return _PlateFor(
      view: view,
      image: image,
      caption: caption.isEmpty ? null : caption,
      // THE SCOPE CONTROL, AND IT IS THE WORDS THAT WERE ALREADY THERE.
      //
      // The eyebrow prints the territory and the window — exactly the two
      // things the control sets — so the reference's "no filter chrome" and
      // "a manager can change territory from home" are the same object rather
      // than a trade. Nothing new is painted; the line grows a 48dp box and a
      // button node. The sheet behind it is the overview's own: the same
      // `TorchFilterRail` and the same territory rows, from
      // `dashboard_filters.dart`.
      onScopeTap: () => showDashboardScope(context, ref),
      onClearTerritory: view.isFiltered ? () => clearFloorTerritory(ref) : null,
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
    this.onScopeTap,
    this.onClearTerritory,
  });

  final FloorView view;
  final ImageProvider<Object>? image;
  final String? caption;

  /// Opens the scope sheet. Null in a test that pumps the plate alone.
  final VoidCallback? onScopeTap;

  /// Back to all territories in one tap. Null when nothing is filtered —
  /// a Clear that clears nothing is chrome, and this screen has none to
  /// spare.
  final VoidCallback? onClearTerritory;

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
      // Null, not the string: the provenance is in [semanticLabel] below.
      caption: null,
      // Never a stock image and never a gradient pretending to be a
      // photograph: a drawing that is visibly a drawing, and a sentence.
      fallbackSentence: view.plateSubject == null
          ? 'No shelf photo yet. This becomes your territory’s availability '
                'when the first visits land.'
          : 'No shelf photo from ${view.plateSubject!.outletName} yet.',
      semanticLabel: caption,
      hero: PlateHeroCluster(
        eyebrow: '${view.territoryName} · ${view.windowLabel}',
        onEyebrowTap: onScopeTap,
        // The printed line is two facts joined by a separator, which a screen
        // reader spells as a caption. The control has to say what it does.
        eyebrowSemanticLabel: onScopeTap == null
            ? null
            : '${view.territoryName}, ${view.windowLabel}. '
                  'Change the territory or the window.',
        // THE WAY BACK, ON THE ONE ROW THAT HAS SPACE FOR IT. It appears only
        // when a territory is chosen: a Clear that clears nothing is chrome,
        // and this screen has none to spare.
        healthTrailing: onClearTerritory == null
            ? null
            : TorchTertiaryButton(
                key: const ValueKey<String>('floor-plate-clear-territory'),
                label: 'All territories',
                semanticLabel: 'Show all territories',
                onPressed: onClearTerritory,
              ),
        figure: FigureSlot(
          value: measured ? current.executionScore : null,
          role: spec.figureRole,
          fit: <TiqTypeToken>[
            spec.figureRole,
            skin.text.heroFigureCompact,
            skin.text.display,
          ],
          // A TERRITORY-HEALTH SCORE IS A WHOLE NUMBER. It is 73 on the
          // scorecard, 73 in the answer, 73 in the report — and it was 72.9
          // here, because with no declared precision `TiqNumber` keeps one
          // place and the server sends a double. The precision is a property
          // of the metric, so the screen declares it; the formatter still
          // prints whatever the server says the moment `decimals` reaches the
          // wire for this figure, and nothing rounds inside the widget.
          decimals: 0,
          state: figureState,
          semanticsLabel: measured
              ? null
              : 'Territory health, no visits in this window',
        ),
        // THE HERO'S DELTA — the half of the hero that says whether the
        // number is moving, and the half that was missing from the running
        // screen. Severity-coloured, never amber.
        //
        // It was absent for one reason and would have gone absent for a
        // second. First, the screen only built a `DeltaData` when
        // `KpiDelta.hasDelta` was true, and that getter is false for a change
        // under 0.05 *and* for the case that actually bites: `previous` is
        // null whenever the comparison window does not exist or its request
        // did not come back, which is every All-time filter and every flaky
        // morning. `DeltaSlot` then renders nothing, and the hero stands
        // alone. Second, a movement of 0.02 pts is a real comparison and it
        // was being thrown away rather than printed flat.
        //
        // So: a delta is built whenever there is a window to compare against,
        // flat included, and the no-comparison case says so in words on the
        // figure's own baseline instead of leaving the hole the mockup fills
        // with `▼ 19`. The suppressed cases keep their own sentences —
        // `DeltaSlot` still removes the delta outright beside an em dash,
        // because a delta never stands beside nothing.
        delta: DeltaSlot(
          data: delta.change == null
              ? null
              : DeltaData(
                  direction: delta.change! >= 0.05
                      ? DeltaDirection.up
                      : delta.change! <= -0.05
                      ? DeltaDirection.down
                      : DeltaDirection.flat,
                  sentiment: delta.change! >= 0.05
                      ? TiqSentiment.good
                      : delta.change! <= -0.05
                      ? TiqSentiment.bad
                      : TiqSentiment.neutral,
                  magnitude: delta.change!.abs(),
                  // NO UNIT. `▼ −19 pts` was the running screen and the owner
                  // read all three of its parts as one: the triangle says
                  // down, so the minus is the same word twice (fixed in
                  // `Delta` itself, for every screen), and `pts` is the unit
                  // of a score printed beside a score — the figure above it
                  // has no suffix either, because a territory-health number
                  // is not measured in anything else. The reading is `▼ 19`.
                  //
                  // The word is not lost, it moves to where a unit belongs on
                  // a mark this small: the semantics label below says "points"
                  // in a sentence, so nothing that reads the screen has to
                  // infer it from a triangle.
                ),
          figureState: figureState,
          sampling: FigureSampling(
            kind: MetricKind.score,
            n: n,
            baselineN: baselineN,
          ),
          compact: true,
          noComparisonNote: measured ? 'no window before this one' : null,
          // Direction word, magnitude, unit, baseline, verdict — in that
          // order, which is `Delta`'s own contract for this string. Colour is
          // never the only carrier and now neither is the triangle.
          semanticsLabel: delta.change == null
              ? null
              : _heroDeltaSentence(context, delta.change!),
        ),
        healthLine: Text(
          'Territory health',
          style: skin.text.label.style(color: skin.palette.ink2),
        ),
        // The decomposition: what the composite figure is made of. A
        // composite number nobody can open is a number you cannot act on.
        onHealthTap: () => context.go('/dashboard/overview'),
      ),
    );
  }

  /// "Down 19 points against the window before, which is bad."
  ///
  /// Direction word, magnitude, unit, baseline, verdict — [Delta]'s own
  /// stated order for this string. It exists because the printed mark is now
  /// a triangle and a bare number: the word "points" and the word "bad" are
  /// both in here, so neither the unit nor the verdict is carried by a
  /// colour or by a shape alone.
  static String _heroDeltaSentence(BuildContext context, double change) {
    final size = change.abs();
    // The same figure the mark prints, in the reader's own locale: `Delta`
    // passes no `decimals`, so the formatter keeps up to one place and drops a
    // trailing zero, and `TiqNumber.of` is what makes 1,5 a comma in
    // Afrikaans rather than a format string's full stop.
    final magnitude = TiqNumber.of(context).format(size);
    if (change > -0.05 && change < 0.05) {
      return 'Level against the window before.';
    }
    final up = change >= 0.05;
    return '${up ? 'Up' : 'Down'} $magnitude points against the window '
        'before, which is ${up ? 'good' : 'bad'}.';
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
        // `well` block at 1.12:1 that nobody can see. Real geometry now means
        // the card's corners too: a square block that resolves into a rounded
        // one is a layout shift dressed as a loading state.
        DecoratedBox(
          decoration: BoxDecoration(
            color: skin.palette.edgeStructure,
            borderRadius: BorderRadius.circular(skin.radii.plate),
          ),
          child: SizedBox(height: height < 200 ? 96 : height),
        ),
        const SizedBox(height: TiqSpace.s5),
        for (var i = 0; i < 3; i++) ...<Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: skin.palette.edgeStructure,
              borderRadius: BorderRadius.circular(skin.radii.card),
            ),
            child: const SizedBox(height: TiqSpace.s9),
          ),
          const SizedBox(height: TiqSpace.s3),
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
