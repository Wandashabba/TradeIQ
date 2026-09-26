import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tiq_number.dart';
import '../../../core/network/human_error.dart';
import '../../../core/theme/torchlight/console_skin.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/console_frame.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../l10n/l10n.dart';
import '../../beatplans/data/today_route.dart' show RouteDistance;
import '../data/outlets_repository.dart';

/// STORES — the reference list, and the queue of pins an agent says are wrong.
///
/// ```text
///   Stores                                        [ ⟳ ]
///   A store without coordinates cannot be geofenced.
///   ┌────────────────────────────────────────┐
///   │ ▲  CANNOT BE GEOFENCED              1  │
///   └────────────────────────────────────────┘
///   ── Open pin reports  2 ───────────────────
///   ▌ Kasi Corner Spaza              No location
///   ▌ Thandi stood 8,4 km away
///   ── Stores  12 ──────────── Add a store ───
///   ▏ Shoprite Klipspruit Mall               ›
///   ▏ SKM-001
///   [ nav pill ]
/// ```
///
/// ## The one state an outlet carries
///
/// GET /outlets says almost nothing about a shop, and the one thing it does
/// say that matters is whether it has usable coordinates. An outlet at 0,0 —
/// the API's unset for a required double, and a spot in the Gulf of Guinea —
/// cannot be geofenced, so a visit there cannot be verified. That is a defect
/// in the record, not a verdict on the shop, but it is a defect that stops
/// work: it takes the **watch** severity, which is a crimson outlined bar plus
/// the word "No location", so it survives greyscale, glare and a reader.
///
/// ## The amber, counted
///
/// A console route under Menu, so the nav's active tab is object 1 in Night
/// and the content has one grant left. It declines it. Nothing here is a
/// commit: "Add a store" is a section rule's ghost action, the severity bars
/// are severity, and the lead figure is crimson. Night paints **1**, Day and
/// Veld paint **0** — their one rung is the primary commit block and this
/// route has none.
class OutletsListScreen extends ConsumerWidget {
  const OutletsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ConsoleTorchlightRoute(child: _Outlets());
  }
}

/// 0,0 is the API's "unset" for a required double — it is in the Gulf of
/// Guinea, so no real outlet sits there.
bool outletIsLocated(Outlet outlet) => outlet.lat != 0 || outlet.lng != 0;

class _Outlets extends ConsumerWidget {
  const _Outlets();

  void _refresh(WidgetRef ref) {
    ref.invalidate(outletsListProvider);
    ref.invalidate(openPinDisputesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final outlets = ref.watch(outletsListProvider);

    return outlets.when(
      loading: () => _frame(
        context,
        ref,
        phase: 'loading',
        children: <Widget>[
          Skeleton(
            label: l10n.outletsTitle,
            child: const SkeletonRows(count: 5, rowHeight: 64),
          ),
        ],
      ),
      error: (error, stack) => _frame(
        context,
        ref,
        phase: 'error',
        children: <Widget>[
          TorchErrorRegion(
            name: 'outlets',
            child: ErrorState(
              message: TorchErrorMessage(
                kind: TorchErrorKind.unknown,
                headline: l10n.outletsLoadErrorHeadline,
                // The app's one voice: a 500 and a parse failure must not
                // read to a manager as a connectivity problem.
                body: humanErrorMessage(error, l10n),
                offersRetry: true,
              ),
              drawing: EmptyDrawing.shelf,
              action: TorchSecondaryButton(
                key: const ValueKey<String>('outlets-retry'),
                label: l10n.outletsRetry,
                onPressed: () => _refresh(ref),
              ),
            ),
          ),
        ],
      ),
      data: (list) => _loaded(context, ref, list),
    );
  }

  Widget _loaded(BuildContext context, WidgetRef ref, List<Outlet> outlets) {
    final l10n = context.l10n;
    final gutter = context.skin.space.gutterFor(
      MediaQuery.sizeOf(context).width,
    );
    // The provider walks every page, so this is a count of every store in the
    // account — a measured figure, and a measured zero that renders "0".
    final unplaced = outlets.where((o) => !outletIsLocated(o)).length;

    return _frame(
      context,
      ref,
      phase: outlets.isEmpty ? 'empty' : 'loaded',
      children: <Widget>[
        _UnplacedLead(count: unplaced),
        const SizedBox(height: TiqSpace.s6),
        const _OpenPinReports(),
        SectionRule(
          l10n.outletsSectionHeading,
          count: outlets.isEmpty ? null : outlets.length,
          action: SectionRuleAction(
            l10n.outletsCreateStore,
            onTap: () async {
              await context.push('/outlets/create');
              _refresh(ref);
            },
          ),
        ),
        const SizedBox(height: TiqSpace.s5),
        if (outlets.isEmpty)
          EmptyState(
            headline: l10n.outletsEmptyHeadline,
            drawing: EmptyDrawing.shelf,
            body: l10n.outletsEmptyBody,
            action: TorchSecondaryButton(
              key: const ValueKey<String>('create-outlet'),
              label: l10n.outletsCreateStore,
              icon: Icons.add_location_alt_outlined,
              onPressed: () async {
                await context.push('/outlets/create');
                _refresh(ref);
              },
            ),
          )
        else
          TorchBleed(
            extra: gutter.left * 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < outlets.length; i++)
                  _OutletRow(outlet: outlets[i], last: i == outlets.length - 1),
              ],
            ),
          ),
      ],
    );
  }

  Widget _frame(
    BuildContext context,
    WidgetRef ref, {
    required String phase,
    required List<Widget> children,
  }) {
    final l10n = context.l10n;
    return ConsoleFrame(
      phase: phase,
      active: ConsoleSlot.menu,
      header: TorchAppHeader(
        title: l10n.outletsTitle,
        facts: <String>[l10n.outletsSubtitle],
        trailing: TorchIconButton(
          key: const ValueKey<String>('outlets-refresh'),
          icon: Icons.refresh,
          semanticLabel: l10n.outletsRefresh,
          onPressed: () => _refresh(ref),
        ),
      ),
      children: children,
    );
  }
}

/// How many stores cannot be geofenced, as the one figure that sends somebody
/// somewhere.
///
/// Three channels and none working alone: the crimson outline, the drawn
/// triangle beside it, and the word in the eyebrow. Never amber — a count of
/// broken records is the least lit thing on this screen.
class _UnplacedLead extends StatelessWidget {
  const _UnplacedLead({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final kind = count > 0 ? SeverityMarkKind.watch : SeverityMarkKind.onTarget;

    return Row(
      key: const ValueKey<String>('outlets-unplaced'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: TiqSpace.s5),
          child: SeverityMark(kind: kind),
        ),
        const SizedBox(width: TiqSpace.s3),
        Expanded(
          child: StatTile(
            eyebrow: l10n.outletsNoLocation,
            // A measured zero renders 0 and keeps its place: nought unplaced
            // stores is a fact worth reading, not an absence. The provider
            // walks every page, so there is no cut list to make it an unknown.
            value: count,
            lead: true,
            severity: count > 0 ? SeverityMarkKind.watch : null,
            subordinates: l10n.outletsSubtitle,
          ),
        ),
      ],
    );
  }
}

/// One store, as a row.
class _OutletRow extends StatelessWidget {
  const _OutletRow({required this.outlet, required this.last});

  final Outlet outlet;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final located = outletIsLocated(outlet);

    return SoftRow(
      key: ValueKey<String>('outlet-${outlet.id}'),
      density: SoftRowDensity.standard,
      title: outlet.name,
      // A shop's name middle-truncates before anything else on the row does.
      titleTruncation: SoftRowTruncation.middle,
      subtitle: located ? null : l10n.outletsNoCoordinates,
      // The code is what an agent quotes and what an import keys on, so it
      // wears the identifier face.
      meta: Text(
        outlet.code,
        style: skin.text.monoIdent.style(color: skin.palette.ink3),
      ),
      severity: located ? SoftRowSeverity.none : SoftRowSeverity.watch,
      severityLabel: located ? null : l10n.outletsNoLocation,
      trailing: const SoftRowChevron(),
      // The way into the repair screen (#386). Until it existed there was
      // nowhere in the product an outlet's coordinates could be corrected, so
      // this list was a dead end for the one problem it displays.
      onTap: () => context.push('/outlets/${outlet.id}'),
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: <String>[
        outlet.name,
        outlet.code,
        located ? l10n.outletsPlaced : l10n.outletsNoLocation,
      ].join('. '),
    );
  }
}

/// Agents who have reported a pin as wrong and are waiting on somebody (#386).
///
/// It sits above the list because each row is an agent currently working
/// around broken data — a visit already recorded outside the fence, flagged,
/// waiting for the one person who can correct the number. A queue nobody is
/// shown is a queue nobody works.
///
/// Silent when there are none, and silent when the request fails: a manager
/// who cannot reach this endpoint still needs the store list underneath it.
class _OpenPinReports extends ConsumerStatefulWidget {
  const _OpenPinReports();

  @override
  ConsumerState<_OpenPinReports> createState() => _OpenPinReportsState();
}

class _OpenPinReportsState extends ConsumerState<_OpenPinReports> {
  /// Pages two and on, in order. Page one stays in the provider so a resolved
  /// dispute still refreshes the queue.
  final List<PinDispute> _older = <PinDispute>[];
  String? _cursor;
  bool _cursorRead = false;
  bool _loading = false;
  bool _failed = false;

  Future<void> _loadMore(String cursor) async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final page = await ref
          .read(outletAdminRepositoryProvider)
          .listPinDisputes(cursor: cursor);
      if (!mounted) return;
      setState(() {
        _older.addAll(page.data);
        _cursor = page.nextCursor;
        _cursorRead = true;
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      // The reports already on screen stay. A failed *next* page is not a
      // failed queue.
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final disputes = ref.watch(openPinDisputesProvider);
    final page = disputes.value;
    final open = <PinDispute>[...?page?.data, ..._older];
    if (open.isEmpty) return const SizedBox.shrink();
    // Page one's cursor until something older has been loaded, then the last
    // page's. `_cursorRead` separates "not asked yet" from "the server sent
    // none" — the same unknown-versus-zero distinction the figures make.
    final next = _cursorRead ? _cursor : page?.nextCursor;

    final gutter = context.skin.space.gutterFor(
      MediaQuery.sizeOf(context).width,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionRule(l10n.outletsPinReportsHeading, count: open.length),
        const SizedBox(height: TiqSpace.s3),
        Text(
          l10n.outletsPinReportsNote,
          style: skin.text.meta.style(color: skin.palette.ink3),
        ),
        const SizedBox(height: TiqSpace.s4),
        TorchBleed(
          extra: gutter.left * 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (var i = 0; i < open.length; i++)
                SoftRow(
                  key: ValueKey<String>('pin-report-${open[i].id}'),
                  density: SoftRowDensity.standard,
                  title: open[i].outletName,
                  titleTruncation: SoftRowTruncation.middle,
                  subtitle: l10n.outletsPinReportStood(
                    open[i].agentLabel,
                    formatDistance(context, open[i].distanceM),
                  ),
                  severity: SoftRowSeverity.watch,
                  severityLabel: l10n.outletsPinReported,
                  trailing: const SoftRowChevron(),
                  onTap: () => context.push('/outlets/${open[i].outletId}'),
                  separator: i == open.length - 1
                      ? SoftRowSeparator.none
                      : SoftRowSeparator.auto,
                ),
            ],
          ),
        ),
        // WHAT THE QUEUE IS SHOWING. The count beside the marker was
        // `open.length` — the size of one page, read as the size of the
        // queue. A manager cleared what they could see and believed they were
        // done, and an unworked pin report is a store an agent cannot check
        // into.
        if (next != null || _failed) ...<Widget>[
          const SizedBox(height: TiqSpace.s4),
          PaginationFooter(
            summary: l10n.outletsPinReportsShowing(open.length),
            narrowLine: _failed ? l10n.outletsPinReportsMoreFailed : null,
            action: next == null
                ? null
                : TorchTertiaryButton(
                    key: const ValueKey<String>('pin-reports-more'),
                    label: l10n.outletsPinReportsShowMore,
                    busy: _loading,
                    onPressed: _loading ? null : () => _loadMore(next),
                  ),
          ),
        ],
        const SizedBox(height: TiqSpace.s7),
      ],
    );
  }
}

/// A distance in words and digits, through the one formatter.
///
/// It is a sentence fragment rather than a [FigureSlot] because it sits inside
/// a row's subtitle, which is a translated sentence with the distance in the
/// middle of it — and a figure widget cannot be put inside a `String`. The
/// digits, the grouping and the decimal mark are still the formatter's.
String formatDistance(BuildContext context, double metres) {
  final l10n = context.l10n;
  final distance = RouteDistance.fromMetres(metres);
  final digits = TiqNumber.of(
    context,
  ).format(distance.value, decimals: distance.decimals);
  final unit = distance.kilometres ? l10n.unitKilometres : l10n.unitMetres;
  return '$digits $unit';
}
