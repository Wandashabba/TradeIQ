import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audit/data/photos_repository.dart';

import '../../../core/widgets/torchlight/row/row.dart';
import '../../alerts/data/alerts_repository.dart';
import '../../outlets/data/outlets_repository.dart';
import '../../tasks/data/tasks_admin_repository.dart';
import '../../territories/data/territories_repository.dart';
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
  });

  final FloorPhase phase;

  /// `Gauteng North`, or `All territories` when nothing is filtered.
  final String territoryName;

  /// `Week 38`. Uppercased by the eyebrow role, not here.
  final String windowLabel;

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

/// `Week 38` — ISO 8601 week number, which is what "week 38" means to everyone
/// who has ever been handed a retail calendar.
String isoWeekLabel(DateTime date) {
  final thursday = DateTime(
    date.year,
    date.month,
    date.day,
  ).add(Duration(days: 4 - (date.weekday == 7 ? 7 : date.weekday)));
  final firstThursday = DateTime(thursday.year, 1, 4);
  final week =
      1 +
      (thursday.difference(firstThursday).inDays +
              (firstThursday.weekday - 1)) ~/
          7;
  return 'Week $week';
}

/// The merged, ranked decision list plus everything around it.
final floorViewProvider = FutureProvider<FloorView>((ref) async {
  final snapshot = await ref.watch(dashboardSnapshotProvider.future);
  final filter = ref.watch(dashboardFilterProvider);
  final now = ref.read(nowProvider)();

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
        reason: a.message,
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
        reason: t.requiredFix,
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
  ]..sort(FloorDecision.compare);

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
    windowLabel: isoWeekLabel(now),
    snapshot: snapshot,
    decisions: decisions,
    outletsTotal: current.outletsTotal,
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
