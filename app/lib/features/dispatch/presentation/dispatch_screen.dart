import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/console_frame.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../l10n/l10n.dart';
import '../../outlets/data/outlets_repository.dart';
import '../data/dispatch_repository.dart';

/// DISPATCH — who should take this one.
///
/// ```text
///   Dispatch                                      [ ⟳ ]
///   Agents are ranked in-territory first, then by distance
///   from their last known location.
///   ── The outlet ─────────────────────────────────────
///   ┌────────────────────────────────────────────────┐
///   │ Kasi Corner Spaza                          ›   │
///   │ KCS-001                                        │
///   └────────────────────────────────────────────────┘
///   ── Candidates  2 ──────────────────────────────────
///   [SN]  Sipho Ndlovu                    Recommended
///         Field agent · In territory
///         120 m away
///   [TM]  Thandi Mokoena                     Available
///         Field agent · Outside territory
///         No last-known location
///   [ nav pill ]
/// ```
///
/// ## A row names a person
///
/// The candidates were a `WorklistRow` whose title fell back to an email
/// address and whose meta line was two sentences glued with a middot. They
/// are [PersonRow]s now: initials, the name, the role and the outlet — never
/// a database id, and never a photograph (POPIA, unify §1.15). An agent the
/// roster never named still gets the address people actually mail, which is
/// not a key either.
///
/// ## Unknown is not zero, and it is the whole point of this screen
///
/// `distanceM` is null for an agent the server cannot place. The old screen
/// said "No last-known location" in the meta line and was right to — an agent
/// with no fix must never look like one standing on the doorstep. Here the
/// figure itself is the em dash with the unit suppressed and the sentence
/// beneath it, which is the same statement made in the kit's own grammar.
///
/// **A rank is never invented.** `recommended` comes from the server. Where
/// the server names nobody, no row is marked — the list is still ranked, and
/// the order is the statement.
///
/// ## The amber, counted
///
/// A tab root reached from the Menu: the nav's active tab is slot 1 and the
/// content declines its grant on every phase. Dispatch **reads** a ranking;
/// assigning the visit is a different screen's commit. Day and Veld: zero.
class DispatchScreen extends ConsumerStatefulWidget {
  const DispatchScreen({super.key});

  @override
  ConsumerState<DispatchScreen> createState() => _DispatchScreenState();
}

class _DispatchScreenState extends ConsumerState<DispatchScreen> {
  Outlet? _outlet;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final outlets = ref.watch(dispatchOutletsProvider);
    final chosen = _outlet;

    return ConsoleFrame(
      phase: chosen == null ? 'no-outlet' : 'ranking',
      active: ConsoleSlot.menu,
      header: TorchAppHeader(
        title: l10n.dispatchTitle,
        facts: <String>[l10n.dispatchFact],
      ),
      children: <Widget>[
        SectionRule(l10n.dispatchOutletSection),
        const SizedBox(height: TiqSpace.s3),
        SoftRow(
          key: const ValueKey<String>('outlet-select'),
          form: SoftRowForm.standalone,
          density: SoftRowDensity.tall,
          title: chosen?.name ?? l10n.dispatchChooseOutlet,
          titleTruncation: SoftRowTruncation.middle,
          subtitle: chosen == null ? l10n.dispatchChooseOutletHint : null,
          meta: chosen == null
              ? null
              : Text(
                  chosen.code,
                  style: skin.text.monoIdent.style(color: skin.palette.ink3),
                ),
          trailing: const SoftRowChevron(),
          onTap: () => _pickOutlet(outlets),
          semanticsLabel: chosen == null
              ? l10n.dispatchChooseOutlet
              : l10n.dispatchChangeOutlet(chosen.name),
        ),
        SizedBox(height: skin.space.blockGap),

        if (chosen == null)
          EmptyState(
            scope: EmptyScope.inPanel,
            headline: l10n.dispatchNoOutletHeadline,
            body: l10n.dispatchNoOutletBody,
          )
        else
          _Candidates(
            key: ValueKey<String>('candidates-${chosen.id}'),
            outlet: chosen,
          ),
      ],
    );
  }

  Future<void> _pickOutlet(AsyncValue<List<Outlet>> outlets) async {
    final picked = await showTorchSheet<Outlet>(
      context,
      builder: (_) => _OutletPickerSheet(outlets: outlets),
    );
    if (picked != null && mounted) setState(() => _outlet = picked);
  }
}

/// The outlet list, as the one modal container. The dialog is deleted and the
/// `DropdownButtonFormField` with it: a dropdown's menu is a second material
/// with its own scrim, its own insets and its own answer to what happens to
/// the amber underneath.
class _OutletPickerSheet extends ConsumerWidget {
  const _OutletPickerSheet({required this.outlets});

  final AsyncValue<List<Outlet>> outlets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return TorchSheet(
      title: l10n.dispatchChooseOutlet,
      subtitle: l10n.dispatchChooseOutletHint,
      child: outlets.when(
        loading: () => Skeleton(
          label: l10n.dispatchOutletSection,
          slowLine: l10n.torchStillFetching,
          child: const SkeletonRows(count: 4, rowHeight: 64),
        ),
        error: (error, _) => TorchErrorRegion(
          name: 'outlets',
          child: ErrorState(
            scope: ErrorScope.inline,
            message: TorchErrorMessage.sanitise(error),
            action: TorchTertiaryButton(
              key: const ValueKey<String>('outlets-retry'),
              label: l10n.torchTryAgain,
              onPressed: () => ref.invalidate(dispatchOutletsProvider),
            ),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              scope: EmptyScope.inPanel,
              headline: l10n.dispatchNoOutletsHeadline,
              body: l10n.dispatchNoOutletsBody,
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (var i = 0; i < list.length; i++)
                SoftRow(
                  key: ValueKey<String>('dispatch-outlet-${list[i].id}'),
                  density: SoftRowDensity.compact,
                  title: list[i].name,
                  titleTruncation: SoftRowTruncation.middle,
                  subtitle: list[i].code,
                  onTap: () => Navigator.of(context).pop(list[i]),
                  separator: i == list.length - 1
                      ? SoftRowSeparator.none
                      : SoftRowSeparator.auto,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Candidates extends ConsumerWidget {
  const _Candidates({super.key, required this.outlet});

  final Outlet outlet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final result = ref.watch(dispatchResultProvider(outlet.id));
    final gutter = context.skin.space.gutter;

    return result.when(
      loading: () => Skeleton(
        label: l10n.dispatchCandidatesSection,
        slowLine: l10n.torchStillFetching,
        child: const SkeletonRows(count: 3, rowHeight: 80),
      ),
      error: (error, _) => TorchErrorRegion(
        name: 'candidates',
        child: ErrorState(
          message: TorchErrorMessage.sanitise(error),
          action: TorchSecondaryButton(
            key: const ValueKey<String>('candidates-retry'),
            label: l10n.torchTryAgain,
            onPressed: () => ref.invalidate(dispatchResultProvider(outlet.id)),
          ),
        ),
      ),
      data: (data) {
        if (data.candidates.isEmpty) {
          return EmptyState(
            scope: EmptyScope.inPanel,
            headline: l10n.dispatchNoCandidatesHeadline,
            body: l10n.dispatchNoCandidatesBody,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SectionRule(
              l10n.dispatchCandidatesSection,
              count: data.candidates.length,
            ),
            const SizedBox(height: TiqSpace.s3),
            TorchBleed(
              extra: gutter * 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (var i = 0; i < data.candidates.length; i++)
                    _CandidateRow(
                      // Keyed by email, which is unique; the title is the
                      // name. Nothing keyed on these moves.
                      key: ValueKey<String>(
                        'candidate-${data.candidates[i].email}',
                      ),
                      candidate: data.candidates[i],
                      recommended:
                          data.recommended?.agentId ==
                          data.candidates[i].agentId,
                      last: i == data.candidates.length - 1,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({
    super.key,
    required this.candidate,
    required this.recommended,
    required this.last,
  });

  final DispatchCandidate candidate;
  final bool recommended;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final placed = candidate.distanceM != null;
    final territoryWord = candidate.inTerritory
        ? l10n.dispatchInTerritory
        : l10n.dispatchOutsideTerritory;
    // The placement goes in the REASON LINE, not only in the trailing figure.
    // A plain `trailing` is inside the row's excluded label (§9b), so a figure
    // there is painted and announced nowhere — which is exactly how the
    // "no last-known location" fact would go missing for the reader who most
    // needs it. The figure is the visual; this is the utterance.
    final placement = placed
        ? l10n.dispatchMetresAway(candidate.distanceM!.round())
        : l10n.dispatchNoLocation;

    return PersonRow(
      // The name when there is one, otherwise the address people mail.
      name: candidate.label,
      role: l10n.roleFieldAgent,
      outlet: '$territoryWord · $placement',
      // Both facts, stacked, and never `trailingWord` — that slot takes one
      // word and this row has two things to say: whether the SERVER picked
      // this agent, and how far away the server last saw them.
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (recommended)
            Text(
              // The server's word, not a rank this screen computed. Where the
              // server names nobody, no row carries one and the order is the
              // whole statement.
              l10n.dispatchRecommended,
              textAlign: TextAlign.end,
              style: skin.text.label.style(color: skin.palette.ink1),
            ),
          FigureSlot(
            value: placed ? candidate.distanceM!.round() : null,
            role: skin.text.figureS,
            // A metre suffix on nothing is a unit measuring nothing, so an
            // unplaced agent gets the em dash bare and the sentence beneath.
            unit: TiqUnit.none,
            state: placed ? FigureState.measured : FigureState.missing,
            textAlign: TextAlign.end,
            semanticsLabel: placed ? null : l10n.dispatchNoLocation,
          ),
          Text(
            placed ? l10n.dispatchMetresUnit : l10n.dispatchNoLocationShort,
            textAlign: TextAlign.end,
            style: skin.text.meta.style(color: skin.palette.ink3),
          ),
        ],
      ),
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
    );
  }
}
