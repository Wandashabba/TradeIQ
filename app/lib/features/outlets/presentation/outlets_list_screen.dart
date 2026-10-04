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
import '../../../core/widgets/torchlight/console_desk.dart';
import '../../../core/widgets/torchlight/console_frame.dart';
import '../../../core/widgets/torchlight/console_record.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../l10n/l10n.dart';
import '../../beatplans/data/today_route.dart' show RouteDistance;
import '../../dashboard/data/dashboard_repository.dart'
    show dashboardFilterProvider;
import '../../dashboard/presentation/dashboard_filters.dart'
    show applyTerritory, allTerritoriesToken, pickTerritory, territoryFact;
import '../../territories/data/territories_repository.dart'
    show territoriesListProvider;
import '../data/outlets_repository.dart';

/// STORES — the reference list, and the queue of pins an agent says are wrong.
///
/// ```text
///   Stores                                        [ ⟳ ]
///   A store without coordinates cannot be geofenced.
///   ( All territories )
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
/// ## The territory, and whose territory it is
///
/// *"when choosing a territory we need it to only show the store on that
/// territory and not everything else"* — and this screen had no scope at all,
/// under a backend whose `GET /outlets` had no territory parameter to send
/// one to.
///
/// The chip writes [dashboardFilterProvider], the scope The Floor and the
/// execution overview already read, and opens [pickTerritory] — the same
/// sheet, over the same rows. A second territory state would let a manager
/// choose Gauteng on The Floor, walk here, and find themselves somewhere else
/// with nothing on either screen to say which answer they were looking at.
/// The filter's `range` is not consulted: a shop is not in or out of a
/// reference list because of a date window, which is why this opens the
/// territory sheet alone and not The Floor's two-part scope sheet.
///
/// The list itself comes from [scopedOutletsProvider] rather than
/// `outletsListProvider` — see its doc comment for why the unscoped one must
/// stay unscoped.
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
/// are severity, and the lead figure is crimson. Night paints **1** and Day
/// paints **0** — its one rung is the primary commit block and this route has
/// none.
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
    ref.invalidate(scopedOutletsProvider);
    ref.invalidate(openPinDisputesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final outlets = ref.watch(scopedOutletsProvider);

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
    // The provider walks every page, so this is a count of every store IN
    // SCOPE — a measured figure, and a measured zero that renders "0". Scoped
    // to a territory it counts that territory's, which is the question a
    // manager looking at one territory is asking.
    final unplaced = outlets.where((o) => !outletIsLocated(o)).length;
    final territoryId = ref.watch(
      dashboardFilterProvider.select((filter) => filter.territoryId),
    );

    final lead = _UnplacedLead(count: unplaced);
    final sectionRule = SectionRule(
      l10n.outletsSectionHeading,
      // THE RECORDS' OWN MARKER, and not the one `_OpenPinReports` nests above
      // it — which is why this is a flag and not the frame taking the first
      // marker it finds in the pane.
      listAction: true,
      count: outlets.isEmpty ? null : outlets.length,
      action: SectionRuleAction(
        l10n.outletsCreateStore,
        onTap: () async {
          await context.push('/outlets/create');
          _refresh(ref);
        },
      ),
    );

    return _frame(
      context,
      ref,
      phase: outlets.isEmpty ? 'empty' : 'loaded',
      // ── WHAT THE DESK GETS, AND WHAT IT DOES NOT ─────────────────────────
      //
      // `lead` is this screen's whole head, in the phone's own order: the
      // territory chip, the unplaced figure, the open pin reports and the
      // stores marker — the same `_TerritoryScope`, the same `_UnplacedLead`,
      // the same `_OpenPinReports` and the same `SectionRule` instances the
      // phone arm is handed.
      //
      // **The territory chip is in `lead` and not in `filters`, deliberately.**
      // `ConsoleDeskRecords` draws `filters` *below* `lead`, and this chip is a
      // scope rather than a rail: it scopes the unplaced count as well as the
      // rows, and the phone puts it "ABOVE EVERYTHING IT SCOPES" for a reason
      // that does not stop being true at 1440dp. A single chip under the figure
      // it governs would read as a filter on the list alone.
      //
      // The marker stays for the same reason it does on Orders: one chip naming
      // a territory neither names nor counts the column of stores under it, so
      // dropping the marker would leave the rows unnamed and uncounted.
      //
      // The pin-report rows in `lead` **keep their own push** to the repair
      // screen. They are a different queue over a different endpoint — the
      // account's, not the territory's — and they are not records of this list,
      // so the frame's selection has no claim on them.
      desk: outlets.isEmpty
          ? null
          : ConsoleDeskRecords(
              toolbar: ConsoleDeskToolbar.marker,
              lead: <Widget>[
                const _TerritoryScope(),
                const SizedBox(height: TiqSpace.s5),
                lead,
                const SizedBox(height: TiqSpace.s6),
                const _OpenPinReports(),
                sectionRule,
                const SizedBox(height: TiqSpace.s5),
              ],
              records: <ConsoleDeskRecord>[
                for (var i = 0; i < outlets.length; i++)
                  ConsoleDeskRecord(
                    id: outlets[i].id,
                    row: (context, selected) => _OutletRow(
                      outlet: outlets[i],
                      last: i == outlets.length - 1,
                      onDesk: true,
                    ),
                    detail: (context) => _OutletPane(outlet: outlets[i]),
                  ),
              ],
            ),
      children: <Widget>[
        // THE SAME TWO OBJECTS THE LIST PANE'S `lead` HOLDS, and the same
        // instances. Only one arm of `ConsoleFrame` is ever mounted.
        lead,
        const SizedBox(height: TiqSpace.s6),
        const _OpenPinReports(),
        sectionRule,
        const SizedBox(height: TiqSpace.s5),
        // TWO EMPTIES, AND THEY ARE NOT THE SAME SENTENCE.
        //
        // With no territory chosen, an empty list means the account has no
        // stores yet: an invitation, and the action is to create one.
        //
        // Scoped, it means this territory has none while the rest of the
        // account carries on having them — an absence, which is what
        // `EmptyDrawing.shelf` is for ("a filtered-to-nothing list", §1.12).
        // Offering "Add a store" here would be answering a question nobody
        // asked; the way out of a filter is out of the filter, so the action
        // clears the scope. The body names this product's actual reason for a
        // territory reading zero when it should not: `Outlet.territoryId` is
        // free text with no foreign key, so a store filed under the wrong
        // code is filed nowhere, and the manager staring at an empty
        // territory is the person who can fix it.
        if (outlets.isEmpty && territoryId != null)
          EmptyState(
            key: const ValueKey<String>('outlets-empty-territory'),
            headline: l10n.outletsEmptyInTerritoryHeadline(
              territoryFact(ref, l10n, territoryId),
            ),
            drawing: EmptyDrawing.shelf,
            body: l10n.outletsEmptyInTerritoryBody,
            action: TorchSecondaryButton(
              key: const ValueKey<String>('outlets-clear-territory'),
              label: l10n.outletsShowAllTerritories,
              onPressed: () => applyTerritory(
                ref,
                ref.read(dashboardFilterProvider),
                allTerritoriesToken,
              ),
            ),
          )
        else if (outlets.isEmpty)
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
    ConsoleDeskRecords? desk,
  }) {
    final l10n = context.l10n;
    return ConsoleFrame(
      phase: phase,
      // Null on `loading`, `error` and both empties: a skeleton, a failure, an
      // account with no stores and a territory with none are not records, so
      // those phases keep the rail and one centred column — and the territory
      // chip stays at the top of that column, where the `children` list below
      // puts it in every phase.
      desk: desk,
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
      children: <Widget>[
        // ABOVE EVERYTHING IT SCOPES, and present in every phase — a scope
        // control that disappears while the list loads or after it fails
        // leaves the reader unable to tell what they were asking for, which
        // on an error screen is the moment they most need to know.
        const _TerritoryScope(),
        const SizedBox(height: TiqSpace.s5),
        ...children,
      ],
    );
  }
}

/// THE ONE CONTROL ON THIS SCREEN — which territory's stores.
///
/// A single chip rather than a rail of them: the territory list is
/// arbitrary-length, which is the reason the overview's own territory chip
/// opens a sheet instead of laying every territory out sideways (unify
/// §18.1). It is [TorchFilterChip], so selected is the lifted fill, the tick,
/// weight 700 and an ink step — four channels, none of them amber and none of
/// them colour alone.
///
/// Unselected the chip reads "All territories", which is what the screen is
/// showing. That is also what it reads while the territory list is still
/// loading, with the chip disabled: a label that went blank would make the
/// reader think the scope had been lost.
class _TerritoryScope extends ConsumerWidget {
  const _TerritoryScope();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final filter = ref.watch(dashboardFilterProvider);
    final territories = ref.watch(territoriesListProvider);
    final fact = territoryFact(ref, l10n, filter.territoryId);

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TorchFilterChip(
        key: const ValueKey<String>('outlets-territory'),
        label: fact,
        selected: filter.territoryId != null,
        // "Gauteng North" read out alone is a place, not a control. The
        // sheet's own title is the word that makes it one.
        semanticsLabel: '${l10n.dashTerritory}. $fact',
        onSelected: territories.hasValue
            ? () => pickTerritory(context, ref, filter)
            : null,
      ),
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
  const _OutletRow({
    required this.outlet,
    required this.last,
    this.onDesk = false,
  });

  final Outlet outlet;
  final bool last;

  /// True in the desk's list pane, where the row's press is the **selection**
  /// and the store's record is already beside it.
  ///
  /// `context.push('/outlets/:id')` there would put a whole second console
  /// route — header, back button, thumb zone and its one amber commit — over
  /// the list the manager chose from. So the press goes to the frame instead,
  /// and the way into the repair screen is a verb **in the pane**: see
  /// [_OutletPane], which is where that push now lives at desk width.
  final bool onDesk;

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
      onTap: onDesk ? null : () => context.push('/outlets/${outlet.id}'),
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: <String>[
        outlet.name,
        outlet.code,
        located ? l10n.outletsPlaced : l10n.outletsNoLocation,
      ].join('. '),
    );
  }
}

/// ── ONE STORE, IN THE DETAIL PANE — and why it is NOT the repair screen ──
///
/// The instruction for this screen was to reuse `_OutletDetailBody` from
/// `outlet_detail_screen.dart` in the pane. **It cannot be reused, and the
/// reason is what that widget actually is**, read rather than assumed:
///
/// * it is not a body. `_OutletDetailBody.build` returns `_OutletFrame`,
///   which is a `TorchScope` wrapping a `TorchShell` with an app header, a
///   back button and a thumb zone. Dropping it in here would mount a second
///   console screen inside a 440dp pane of the first one.
/// * it is a **form**: three `TextEditingController`s, a `ChoiceRow`, a
///   validator and a PATCH. The recipe's own ruling is that a form is not a
///   detail pane; the pane is built from the record's fields and the form's
///   opener goes in `actions`.
/// * it declares `TorchPrimaryButton.claim(OutletDetailScreen.saveClaimId)`.
///   The pane may add no amber and declare no new claim, so even the form's
///   Save could not come with it.
///
/// So this is the record, from the `Outlet` the list already holds — which
/// also means **the pane fetches nothing at all**: no `outletDetailProvider`
/// watch, no request on selection, and no loading state to draw.
///
/// ## What it carries, and what it refuses to print
///
/// The row's own three lines — the name, the code in the identifier face, and
/// the "No location" word behind its bar — plus the fields the repair screen
/// edits. The **coordinates only where there are coordinates**: 0,0 is the
/// API's unset for a required double, so a store with no pin gets the kicker
/// and the sentence rather than a latitude of 0 printed as a measured fact.
/// The channel type only where the response carried one — an empty string
/// means "not sent", not "no channel".
///
/// ## The way into the repair screen is the one lifted verb
///
/// The row's whole-row tap *was* that way in, and the frame has taken the tap
/// for the selection, so without this button the desk would make the repair
/// screen unreachable from Stores — the dead end #386 existed to remove,
/// reintroduced at 1440dp. It is a [TorchSecondaryButton]: outline and ink,
/// which the ladder never lights, so the pane still paints no amber. The
/// commit itself is still on the route it pushes, where that route's own
/// scope owns it.
class _OutletPane extends StatelessWidget {
  const _OutletPane({required this.outlet});

  final Outlet outlet;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final located = outletIsLocated(outlet);

    return ConsoleRecordDetail(
      key: ValueKey<String>('outlet-detail-${outlet.id}'),
      title: outlet.name,
      // The row's severity bar, as its two channels that survive greyscale:
      // the silhouette and the word. A placed store has no standing and gets
      // no kicker rather than a grey one saying it is fine.
      kicker: located
          ? null
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SeverityMark(kind: SeverityMarkKind.watch),
                const SizedBox(width: TiqSpace.s2),
                Flexible(child: Eyebrow(l10n.outletsNoLocation)),
              ],
            ),
      lede: located ? null : l10n.outletsNoCoordinates,
      facts: <RecordFact>[
        // What an agent quotes and what an import keys on, in the face the row
        // prints it in.
        RecordFact('Code', outlet.code, mono: true),
        RecordFact(
          l10n.outletFieldStatus,
          outlet.status == 'closed'
              ? l10n.outletStatusClosed
              : l10n.outletStatusActive,
        ),
        if (outlet.channelType.isNotEmpty)
          RecordFact(l10n.outletFieldChannel, outlet.channelType),
        if (located) ...<RecordFact>[
          RecordFact(
            l10n.outletFieldLatitude,
            outlet.lat.toString(),
            mono: true,
          ),
          RecordFact(
            l10n.outletFieldLongitude,
            outlet.lng.toString(),
            mono: true,
          ),
        ],
      ],
      actions: <Widget>[
        TorchSecondaryButton(
          key: ValueKey<String>('outlet-open-${outlet.id}-pane'),
          label: 'Open the store record',
          onPressed: () => context.push('/outlets/${outlet.id}'),
        ),
      ],
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
    // WHAT THE TERRITORY CHIP DOES NOT SCOPE. GET /outlets/pin-disputes takes
    // no territory, so this queue is the whole account's — and a queue sitting
    // under a chip naming one territory reads as that territory's. It is said
    // in words rather than left to be inferred, because the alternative is a
    // manager clearing what they can see and believing they are done, which is
    // the failure the pagination footer below already exists to prevent.
    final scoped =
        ref.watch(
          dashboardFilterProvider.select((filter) => filter.territoryId),
        ) !=
        null;
    // Page one's cursor until something older has been loaded, then the last
    // page's. `_cursorRead` separates "not asked yet" from "the server sent
    // none" — the same unknown-versus-zero distinction the figures make.
    final next = _cursorRead ? _cursor : page?.nextCursor;


    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionRule(l10n.outletsPinReportsHeading, count: open.length),
        const SizedBox(height: TiqSpace.s3),
        Text(
          scoped
              ? '${l10n.outletsPinReportsNote} '
                    '${l10n.outletsPinReportsEveryTerritory}'
              : l10n.outletsPinReportsNote,
          style: skin.text.meta.style(color: skin.palette.ink3),
        ),
        const SizedBox(height: TiqSpace.s4),
        TorchBleed(
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
