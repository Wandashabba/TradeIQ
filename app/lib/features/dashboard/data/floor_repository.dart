import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audit/data/photos_repository.dart';

import '../../../core/widgets/torchlight/row/row.dart';
import '../../alerts/data/alerts_repository.dart';
import '../../outlets/data/outlets_repository.dart';
import '../../tasks/data/tasks_admin_repository.dart';
import '../../territories/data/territories_repository.dart';
import '../../territories/data/territories_view.dart';
import 'dashboard_repository.dart';

/// THE FLOOR's view model.
///
/// The screen answers one question — *what is broken, and who is fixing it* —
/// and this is where the answer is assembled, once, so the widget tree does no
/// arithmetic and every rule below is testable without pumping a frame.
///
/// Three decisions live here rather than in the screen:
///
/// 1. **Alerts and tasks are one list.** A manager does not think in terms of
///    which table a finding came out of. They are merged, ranked by severity
///    and then by age, and the worst is first.
/// 2. **The column means one thing.** Both kinds carry `raisedAt`, so the
///    trailing figure is *how long this has been broken* for every row. Mixing
///    an alert's age with a task's SLA deadline would put two meanings in one
///    column and make it unreadable as a column.
/// 3. **Unknown is not zero.** [FloorView.phase] distinguishes a tenant with
///    no outlets (the first-run board), a tenant with outlets and no visits in
///    this window (The Floor with unmeasured figures and a wider-window
///    action), and a measured window (the real thing). No screen anywhere in
///    this feature infers that difference from a figure being 0.

/// Which of the two tables a decision came out of. Carried so a row can route
/// to the right detail, never shown as a label — "Alert" is not a reason.
enum DecisionKind { alert, task }

/// What The Floor is looking at.
enum FloorPhase {
  /// Nothing has ever been measured: no outlets on the books. Hands off to the
  /// first-run board, which is a different screen, not an empty variant.
  firstRun,

  /// Outlets exist; this window has no visits. The Floor renders with
  /// unmeasured figures and a "widen the window" action. Never-measured and
  /// not-measured-lately are different facts and get different screens.
  windowEmpty,

  /// A real window with real visits.
  measured,
}

/// Whether the decision list below the figures is scoped to the chosen
/// territory — and, when it is not, why not.
///
/// The figures come back scoped from the server (`GET /dashboard?territoryId`).
/// The decision list cannot: `GET /alerts` and `GET /tasks` have no territory
/// parameter, and the client's `Outlet` carries no territory either, so the
/// membership has to come from `GET /territories/:id/coverage`. That is a
/// second request, and a second request can fail on its own.
///
/// The failure is a **designed state and not a silent fallback**: a list of
/// every territory's findings under an eyebrow that names one territory is a
/// lie the reader cannot see, and an empty list is a different lie. So the
/// list is withheld and the section says why, while the figures above it —
/// which really were scoped, by the server — stay.
enum FloorScope {
  /// No territory chosen. Everything is in scope, which is the truth.
  all,

  /// A territory is chosen and the decision list is that territory's.
  scoped,

  /// A territory is chosen and its outlet list has not arrived yet.
  pending,

  /// A territory is chosen and its outlet list did not load.
  failed,
}

/// One thing that needs somebody to decide something.
class FloorDecision {
  const FloorDecision({
    required this.id,
    required this.kind,
    required this.outletId,
    required this.outletName,
    required this.reason,
    required this.severity,
    required this.severityLabel,
    required this.route,
    this.raisedAt,
    this.visitId,
    this.evidencePhotoId,
  });

  final String id;
  final DecisionKind kind;
  final String outletId;

  /// Resolved against the outlet list. Falls back to the id only when the
  /// outlet list has not arrived — never to an empty string, because a row
  /// with no name is a row a manager cannot act on.
  final String outletName;

  /// Why it needs a decision, in words. The server's own message for an alert;
  /// the required fix for a task.
  final String reason;

  final SoftRowSeverity severity;

  /// The word. Severity is never carried by the bar's colour alone.
  final String severityLabel;

  /// Where tapping the row goes.
  final String route;

  /// When it was raised. Null renders an em dash and a sentence in the row's
  /// figure slot rather than a zero.
  final DateTime? raisedAt;

  final String? visitId;

  /// The newest photo of the linked visit, batched onto the row server-side.
  /// This is what the plate draws when this decision is the first one.
  final String? evidencePhotoId;

  /// How long this has been broken, in hours. The trailing figure.
  double? ageHoursAt(DateTime now) =>
      raisedAt == null ? null : now.difference(raisedAt!).inMinutes / 60.0;

  /// THE REASON, WITHOUT THE OUTLET NAME IN IT.
  ///
  /// The server writes a message meant to stand on its own — "Kalahari Cola
  /// 2L out of stock at SaveMor Glenwood (6 days)" — and on this row the
  /// outlet name is already the title, one line above. Repeating it spends
  /// the reason's only line on a word the reader has just read, and on a
  /// 390dp card that is the difference between a sentence that ends and one
  /// that stops inside "days".
  ///
  /// Conservative by construction: it strips the name only where the name
  /// appears verbatim with a joining word in front of it ("at", "in", "for",
  /// "—", ","), and hands the message back untouched otherwise. A reason
  /// that would be left empty or meaningless keeps the original, because a
  /// row with no reason is worse than a row that repeats itself.
  static String reasonWithout(String message, String outletName) {
    var out = _withoutAge(message);
    if (outletName.isEmpty || !out.contains(outletName)) return out;
    for (final joiner in const <String>[' at ', ' in ', ' for ', ' — ', ', ']) {
      out = out.replaceAll('$joiner$outletName', '');
    }
    // A leading "Outlet: …" or "Outlet — …" form.
    for (final joiner in const <String>[': ', ' — ', ' - ']) {
      if (out.startsWith('$outletName$joiner')) {
        out = out.substring(outletName.length + joiner.length);
      }
    }
    final trimmed = out.trim();
    return trimmed.isEmpty ? message : trimmed;
  }

  /// A trailing "(6 days)" or "(14 hours)" is the row's **trailing figure**,
  /// printed a second time in the sentence. The column means one thing on
  /// every row — how long this has been broken — so the sentence does not
  /// need to say it, and on a 390dp card that parenthetical is what pushes
  /// the reason past the end of its line.
  ///
  /// Only a duration comes out: "(SKU 4412)" and "(third week running)" are
  /// facts the figure does not carry.
  static final RegExp _age = RegExp(
    r'\s*\((?:about\s+)?\d+\s*(?:m|h|d|min|mins|minute|minutes|hour|hours|day|days|week|weeks|month|months)\)\s*$',
    caseSensitive: false,
  );

  static String _withoutAge(String message) =>
      message.replaceFirst(_age, '').trimRight();

  /// Worst first: critical before watch before unmarked, and within a level
  /// the one that has been broken longest.
  static int compare(FloorDecision a, FloorDecision b) {
    final bySeverity = _rank(a.severity).compareTo(_rank(b.severity));
    if (bySeverity != 0) return bySeverity;
    final at = a.raisedAt;
    final bt = b.raisedAt;
    // A finding with no timestamp sorts last within its level: it is not
    // "brand new", it is unknown, and unknown does not outrank a measured
    // three days.
    if (at == null && bt == null) return a.id.compareTo(b.id);
    if (at == null) return 1;
    if (bt == null) return -1;
    final byAge = at.compareTo(bt);
    return byAge != 0 ? byAge : a.id.compareTo(b.id);
  }

  static int _rank(SoftRowSeverity s) => switch (s) {
    SoftRowSeverity.critical => 0,
    SoftRowSeverity.watch => 1,
    SoftRowSeverity.none => 2,
  };
}

/// Everything The Floor renders, resolved once.
class FloorView {
  const FloorView({
    required this.phase,
    required this.territoryName,
    required this.windowLabel,
    required this.snapshot,
    required this.decisions,
    required this.outletsTotal,
    this.territoryId,
    this.scope = FloorScope.all,
  });

  final FloorPhase phase;

  /// `Gauteng North`, or `All territories` when nothing is filtered.
  final String territoryName;

  /// `Last 30 days`. Uppercased by the eyebrow role, not here.
  ///
  /// It says the window the figures were actually measured over. It used to
  /// say `Week 38` whatever the filter held — and the filter has always been
  /// shared with the overview, so a manager who set "Last 7 days" there came
  /// back to a Floor whose figures were seven days old under a label naming a
  /// calendar week. A label that does not follow its own control is worse
  /// than no label.
  final String windowLabel;

  /// The territory the screen is scoped to, or null for all of them. The id,
  /// not the name: the name is for reading and this is for comparing.
  final String? territoryId;

  /// Whether [decisions] is genuinely scoped to [territoryId].
  final FloorScope scope;

  /// Whether the screen is showing a slice rather than everything. The
  /// eyebrow says so and the way back is one tap.
  bool get isFiltered => territoryId != null;

  final DashboardSnapshot snapshot;

  /// Every decision, worst first. The screen shows [visibleCount] of them and
  /// says how many it did not show — it never silently truncates.
  final List<FloorDecision> decisions;

  final int? outletsTotal;

  /// Five, plus the more-row. Always five: a list that grows with the problem
  /// is a list that stops fitting on the fold exactly when it matters most.
  static const int visibleCount = 5;

  List<FloorDecision> get visible => decisions.take(visibleCount).toList();

  int get moreCount =>
      decisions.length <= visibleCount ? 0 : decisions.length - visibleCount;

  /// The plate's photograph comes from the FIRST decision — the outlet the
  /// manager is about to act on.
  ///
  /// Not the prettiest frame in the territory, and deliberately: a hero image
  /// chosen by a score is something an agent can game by photographing one
  /// good aisle, and a plate that decorates the screen instead of arguing with
  /// the list is a plate that could be a stock photo without anybody noticing.
  /// The provenance caption is what keeps this honest — the figure above the
  /// list is about the territory, and the picture is a named specimen from it.
  FloorDecision? get plateSubject => decisions.isEmpty ? null : decisions.first;

  bool get nothingNeedsADecision => decisions.isEmpty;
}

/// THE WINDOW, IN THE WORDS OF THE CONTROL THAT SETS IT.
///
/// This was `isoWeekLabel(now)` — "Week 38", the ISO week number — and it was
/// printed whatever [DashboardFilter.range] held. The range defaults to the
/// last 30 days and is **shared with the overview**, so the eyebrow named a
/// calendar week over figures measured across thirty days, and a manager who
/// picked "Last 7 days" on the overview came back to a Floor that still said
/// Week 38. Now that The Floor can change the window itself, a label that does
/// not follow its own control would be a bug the reader cannot see.
///
/// English, like the rest of this screen's strings. When The Floor is
/// localised these become `rangeLabel(l10n, range)`, which already exists.
String windowLabelFor(DashboardRange range) => switch (range) {
  DashboardRange.last7 => 'Last 7 days',
  DashboardRange.last30 => 'Last 30 days',
  DashboardRange.last90 => 'Last 90 days',
  DashboardRange.ytd => 'Year to date',
  DashboardRange.allTime => 'All time',
};

/// The merged, ranked decision list plus everything around it.
final floorViewProvider = FutureProvider<FloorView>((ref) async {
  final snapshot = await ref.watch(dashboardSnapshotProvider.future);
  final filter = ref.watch(dashboardFilterProvider);

  // WHICH OUTLETS ARE IN SCOPE.
  //
  // `GET /dashboard` takes a territoryId and the figures come back scoped.
  // `GET /alerts` and `GET /tasks` do not take one, and the client's `Outlet`
  // carries no territory column, so the membership has to come from the
  // territory's own coverage. It is watched — not awaited — so a slow or
  // broken coverage request leaves the figures on screen instead of taking
  // the whole route to its error state; the list below says what happened.
  final coverage = filter.territoryId == null
      ? null
      : ref.watch(territoryCoverageProvider(filter.territoryId!));
  final scope = switch (coverage) {
    null => FloorScope.all,
    AsyncData<TerritoryCoverage>() => FloorScope.scoped,
    AsyncError<TerritoryCoverage>() => FloorScope.failed,
    _ => FloorScope.pending,
  };
  final inScope = <String>{
    for (final o in coverage?.value?.outlets ?? const <Outlet>[]) o.id,
  };

  // The outlet list is a base layer, never a blocker: a decision row with a
  // raw id is worse than one with a name and far better than no list at all.
  final outlets = ref
      .watch(outletsListProvider)
      .maybeWhen(data: (list) => list, orElse: () => const <Outlet>[]);
  final names = <String, String>{for (final o in outlets) o.id: o.name};

  final alerts = ref
      .watch(alertsListProvider)
      .maybeWhen(data: (list) => list, orElse: () => const <AlertItem>[]);
  final tasks = ref
      .watch(tasksListProvider)
      .maybeWhen(data: (list) => list, orElse: () => const <TaskItem>[]);

  final territories = ref
      .watch(territoriesListProvider)
      .maybeWhen(data: (list) => list, orElse: () => const <Territory>[]);

  String nameFor(String? outletId) {
    if (outletId == null) return 'Unassigned outlet';
    return names[outletId] ?? outletId;
  }

  final decisions = <FloorDecision>[
    for (final a in alerts.where((a) => !a.acknowledged))
      FloorDecision(
        id: 'alert:${a.id}',
        kind: DecisionKind.alert,
        outletId: a.outletId ?? '',
        outletName: nameFor(a.outletId),
        reason: FloorDecision.reasonWithout(a.message, nameFor(a.outletId)),
        severity: a.severity == 'critical'
            ? SoftRowSeverity.critical
            : SoftRowSeverity.watch,
        severityLabel: a.severity == 'critical' ? 'Critical' : 'Watch',
        route: '/alerts',
        raisedAt: a.createdAt,
        visitId: a.visitId,
        evidencePhotoId: a.evidencePhotoId,
      ),
    for (final t in tasks.where((t) => t.status != 'closed'))
      FloorDecision(
        id: 'task:${t.id}',
        kind: DecisionKind.task,
        outletId: t.outletId,
        outletName: nameFor(t.outletId),
        reason: FloorDecision.reasonWithout(t.requiredFix, nameFor(t.outletId)),
        // `normal` is still on the list — it is not "fine", and a bar-less row
        // in this system means fine and nothing else.
        severity: t.priority == 'critical'
            ? SoftRowSeverity.critical
            : SoftRowSeverity.watch,
        severityLabel: t.priority == 'critical' ? 'Critical' : 'Watch',
        route: '/tasks',
        raisedAt: t.createdAt,
        visitId: t.visitId,
        evidencePhotoId: t.evidencePhotoId,
      ),
  ]
    // A decision belongs to the chosen territory when its outlet does. An
    // unassigned finding — `outletId` empty — belongs to no territory, so it
    // is out of a territory's scope and in "all territories".
    ..retainWhere(
      (d) => scope != FloorScope.scoped || inScope.contains(d.outletId),
    )
    ..sort(FloorDecision.compare);

  final current = snapshot.current;
  final phase = current.hasNoOutlets
      ? FloorPhase.firstRun
      : current.measuredSomething
      ? FloorPhase.measured
      : FloorPhase.windowEmpty;

  final territoryName = filter.territoryId == null
      ? 'All territories'
      : territories
                .where((t) => t.id == filter.territoryId)
                .map((t) => t.name)
                .firstOrNull ??
            'This territory';

  return FloorView(
    phase: phase,
    territoryName: territoryName,
    windowLabel: windowLabelFor(filter.range),
    snapshot: snapshot,
    // Withheld rather than half-scoped: see [FloorScope].
    decisions: scope == FloorScope.scoped || scope == FloorScope.all
        ? decisions
        : const <FloorDecision>[],
    outletsTotal: current.outletsTotal,
    territoryId: filter.territoryId,
    scope: scope,
  );
});

/// How a photo id becomes something the plate can draw.
///
/// A seam, and a deliberate one. The default reaches for the ≤60 kB,
/// LRU-cached, authed thumbnail route — the only byte budget worth spending on
/// a prepaid bundle, and the only route that can carry a bearer token on web.
/// A test replaces it with an already-decoded frame, because `Image.memory`
/// decodes on the engine's clock and the frame the amber census measures would
/// otherwise arrive after the assertion.
typedef PlateImageResolver =
    ImageProvider<Object>? Function(WidgetRef ref, String photoId);

/// FOLLOW-UP (plate bake ticket, filed with this PR): serve a purpose-baked
/// plate asset — 12% chroma, `#474747` luminance ceiling, alpha edge dissolve,
/// ≤60 kB WebP — and read it here instead of a shelf thumbnail. Until then
/// `TiqPlate` applies the luminance half of that bake client-side.
ImageProvider<Object>? defaultPlateImage(WidgetRef ref, String photoId) {
  final bytes = ref
      .watch(thumbnailBytesProvider(photoId))
      .maybeWhen(data: (b) => b, orElse: () => null);
  return bytes == null ? null : MemoryImage(bytes);
}

final plateImageResolverProvider = Provider<PlateImageResolver>(
  (ref) => defaultPlateImage,
);
