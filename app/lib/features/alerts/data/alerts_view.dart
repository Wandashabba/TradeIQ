import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/torchlight/row/row.dart';
import '../../outlets/data/outlets_repository.dart';
import 'alerts_repository.dart';

/// THE ALERTS WORKLIST'S VIEW MODEL.
///
/// Everything the screen renders, resolved once, so the widget tree does no
/// arithmetic and every rule below is testable without pumping a frame.
///
/// Three decisions live here rather than in the screen:
///
/// 1. **A row names an outlet, never a UUID.** The list before this one
///    printed `Outlet 5f3c…` on every row — #399/#400's exact failure, one
///    table down from a person. The outlet list is a base layer and never a
///    blocker: a row with an unresolved id is worse than one with a name and
///    far better than no list at all.
/// 2. **Sorted by consequence, then by state.** Unacknowledged critical,
///    unacknowledged warning, then acknowledged — the list reads top-down as a
///    to-do order.
/// 3. **Filtering is client-side over the loaded page.** A filter change never
///    refetches, so the list does not flash; the counts on the chips are of the
///    page in hand, which is the only thing the client can honestly count.

/// Which slice of the page the rail is showing.
enum AlertTab {
  /// Everything a rule fired on that nobody has picked up.
  open,

  /// Picked up. Still listed, at `ink2`, with its mark intact.
  acknowledged,

  /// Both.
  all,
}

/// One alert, ready to render.
class AlertRow {
  const AlertRow({
    required this.id,
    required this.message,
    required this.rule,
    required this.outletName,
    required this.severity,
    required this.severityLabel,
    required this.acknowledged,
    required this.rawSeverity,
    this.visitId,
    this.evidencePhotoId,
    this.createdAt,
  });

  final String id;

  /// The rule's own sentence. The row's title.
  final String message;

  /// `OSA_BELOW_50` — machine-facing, so it wears the mono identifier face and
  /// a manager can quote it straight back into the rules screen.
  final String rule;

  /// Resolved against the outlet list. Falls back to "Unassigned outlet" when
  /// the alert carries no outlet at all, and to the id only while the outlet
  /// list has not arrived.
  final String outletName;

  final SoftRowSeverity severity;

  /// The word. Severity is never carried by the bar's colour alone.
  final String severityLabel;

  final bool acknowledged;

  /// The wire's own value, which is what the severity filter matches on.
  final String rawSeverity;

  final String? visitId;
  final String? evidencePhotoId;
  final DateTime? createdAt;

  /// Critical before warning, and unacknowledged before both.
  static int compare(AlertRow a, AlertRow b) {
    final byRank = _rank(a).compareTo(_rank(b));
    if (byRank != 0) return byRank;
    final at = a.createdAt;
    final bt = b.createdAt;
    // A finding with no timestamp sorts last within its level: it is not
    // brand new, it is unknown, and unknown does not outrank a measured age.
    if (at == null && bt == null) return a.id.compareTo(b.id);
    if (at == null) return 1;
    if (bt == null) return -1;
    final byAge = at.compareTo(bt);
    return byAge != 0 ? byAge : a.id.compareTo(b.id);
  }

  static int _rank(AlertRow a) => a.acknowledged
      ? 2
      : a.severity == SoftRowSeverity.critical
      ? 0
      : 1;
}

/// The whole worklist.
class AlertsView {
  const AlertsView({required this.rows, this.nextCursor});

  /// Every alert on the loaded page, worst first.
  final List<AlertRow> rows;

  /// The server's cursor for the page after this one, or null when this page
  /// is the whole truth. It is carried so the footer can say the list was cut
  /// — the API answers a first page and has never said how many rows there
  /// are in total, so the footer says "there are more" and never a fabricated
  /// number.
  final String? nextCursor;

  bool get hasMore => nextCursor != null;

  /// The lead indicator's dominant figure: open criticals. Not a peer of the
  /// other two, which is why the rail is not three equal cells.
  int get openCritical => rows
      .where((r) => !r.acknowledged && r.severity == SoftRowSeverity.critical)
      .length;

  int get openWarning => rows
      .where((r) => !r.acknowledged && r.severity != SoftRowSeverity.critical)
      .length;

  int get acknowledged => rows.where((r) => r.acknowledged).length;

  int get open => rows.where((r) => !r.acknowledged).length;

  /// What the list shows under one tab and one severity, already sorted.
  ///
  /// [severity] is the wire's own word (`critical`, `warning`), or null for
  /// every severity — the filter matches what the server said, not what the
  /// screen decided to call it.
  List<AlertRow> visible(AlertTab tab, String? severity) {
    final out = rows.where((r) {
      final byTab = switch (tab) {
        AlertTab.open => !r.acknowledged,
        AlertTab.acknowledged => r.acknowledged,
        AlertTab.all => true,
      };
      return byTab && (severity == null || r.rawSeverity == severity);
    }).toList();
    out.sort(AlertRow.compare);
    return out;
  }
}

/// The alerts page, merged with the outlet names it needs to be readable.
///
/// It reads the repository rather than [alertsListProvider] for one reason:
/// that provider drops `nextCursor` on the floor, and a worklist that cannot
/// say it was cut is a worklist that reads as the whole truth. The Floor keeps
/// watching the plain list — it wants the rows and not the paging — so nothing
/// there changes and nothing is fetched twice.
final alertsViewProvider = FutureProvider<AlertsView>((ref) async {
  final page = await ref.read(alertsRepositoryProvider).listAlerts();
  final alerts = page.data;

  // A base layer, never a blocker. `maybeWhen` rather than `await`: a slow or
  // failed outlet list must not take the worklist down with it.
  final outlets = ref
      .watch(outletsListProvider)
      .maybeWhen(data: (list) => list, orElse: () => const <Outlet>[]);
  final names = <String, String>{for (final o in outlets) o.id: o.name};

  String nameFor(String? outletId) {
    if (outletId == null) return 'Unassigned outlet';
    return names[outletId] ?? outletId;
  }

  return AlertsView(
    nextCursor: page.nextCursor,
    rows: <AlertRow>[
      for (final a in alerts)
        AlertRow(
          id: a.id,
          message: a.message,
          rule: a.metric,
          outletName: nameFor(a.outletId),
          severity: a.severity == 'critical'
              ? SoftRowSeverity.critical
              : SoftRowSeverity.watch,
          severityLabel: a.severity == 'critical' ? 'Critical' : 'Watch',
          rawSeverity: a.severity,
          acknowledged: a.acknowledged,
          visitId: a.visitId,
          evidencePhotoId: a.evidencePhotoId,
          createdAt: a.createdAt,
        ),
    ]..sort(AlertRow.compare),
  );
});
