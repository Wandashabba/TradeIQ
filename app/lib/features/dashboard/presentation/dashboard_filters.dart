/// THE ONE DASHBOARD SCOPE CONTROL — window and territory, for every screen
/// that reads [dashboardFilterProvider].
///
/// This lived inside `dashboard_shell_screen.dart` as a private widget, which
/// is why The Floor — the manager's *home* — shipped with no way to change
/// territory at all. A manager could not ask "how is Gauteng North doing?"
/// without leaving the screen that exists to answer it. That is the fifth
/// capability this project has lost to a migration, and the fix is not a
/// second copy of the control: it is one implementation both screens read.
///
/// Two presentations of the same state, because the two screens have
/// genuinely different room for chrome:
///
/// * [DashboardFilters] — the overview's rail. Five window chips and a
///   territory chip, above everything they scope.
/// * [showDashboardScope] — The Floor's sheet. The same chips and the same
///   territory list, behind the plate's eyebrow, because the reference the
///   owner signed off has no filter chrome on that screen and a toolbar
///   above the photograph would be the boxiest object on it.
///
/// Both write the same [DashboardFilter]. A per-screen filter would let two
/// figures silently disagree about which slice of time they show, which is
/// worse than no control at all.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../l10n/l10n.dart';
import '../../territories/data/territories_repository.dart';
import '../data/dashboard_repository.dart';

/// The window's own name, localised. `DashboardRange.label` is the wire-ish
/// abbreviation the old pills wore; a fact line and a filter chip are read out
/// loud, so they get words.
String rangeLabel(AppLocalizations l10n, DashboardRange range) =>
    switch (range) {
      DashboardRange.last7 => l10n.dashRangeLast7,
      DashboardRange.last30 => l10n.dashRangeLast30,
      DashboardRange.last90 => l10n.dashRangeLast90,
      DashboardRange.ytd => l10n.dashRangeYtd,
      DashboardRange.allTime => l10n.dashRangeAll,
    };

/// A territory's name from the loaded list, or null when the list has not
/// loaded, failed, or simply does not contain the id — a deleted or stale
/// territory. Never the raw id: a uuid is not a name (unify §1.15).
String? territoryName(WidgetRef ref, String id) =>
    ref.watch(territoriesListProvider).maybeWhen(
      data: (list) {
        for (final t in list) {
          if (t.id == id) return t.name;
        }
        return null;
      },
      orElse: () => null,
    );

/// What the territory chip and the plate's eyebrow both say: the chosen
/// territory's name, or "All territories" when nothing is chosen.
///
/// The middle case is the one a screen gets wrong: a territory *is* chosen and
/// the list has not arrived, which is neither "all" nor a name. It says
/// `dashOneTerritory` — "This territory" — because the figures below really
/// are scoped and claiming otherwise is a lie the reader cannot see.
String territoryFact(WidgetRef ref, AppLocalizations l10n, String? id) {
  if (id == null) return l10n.dashAllTerritories;
  return territoryName(ref, id) ?? l10n.dashOneTerritory;
}

/// One filter rail scoping every panel below it — the window and the
/// territory.
///
/// A per-panel control would let two figures silently disagree about which
/// slice of time they show, which is worse than no control at all. Selected is
/// `lifted` + ink-1 border + tick + weight 700 — three channels, never amber,
/// on any screen (unify §1.6).
class DashboardFilters extends ConsumerWidget {
  const DashboardFilters({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final filter = ref.watch(dashboardFilterProvider);
    final territories = ref.watch(territoriesListProvider);

    void update(DashboardFilter next) =>
        ref.read(dashboardFilterProvider.notifier).set(next);

    return TorchFilterRail(
      semanticsLabel: l10n.dashFilters,
      chips: <Widget>[
        for (final range in DashboardRange.values)
          TorchFilterChip(
            key: ValueKey<String>('range-${range.name}'),
            label: rangeLabel(l10n, range),
            selected: range == filter.range,
            onSelected: () => update(filter.copyWith(range: range)),
          ),
        TorchFilterChip(
          key: const ValueKey<String>('filter-territory'),
          // Loading is a state, not a blank: the chip says "All territories"
          // and is not selected, which is exactly what the screen is showing.
          label: territoryFact(ref, l10n, filter.territoryId),
          selected: filter.territoryId != null,
          onSelected: territories.hasValue
              ? () => pickTerritory(context, ref, filter)
              : null,
        ),
      ],
    );
  }
}

/// The sheet's "all" answer. A null pop is a dismissal, so the clear travels
/// as a token — the same reason the old popup menu carried one.
const String allTerritoriesToken = '__all_territories__';

/// The territory list is arbitrary-length, so it is a sheet of rows rather
/// than a `ChoiceRow` — unify §1.10 gives this product one modal container
/// and §18.1 is why a long list opens it.
Future<void> pickTerritory(
  BuildContext context,
  WidgetRef ref,
  DashboardFilter filter,
) async {
  final l10n = context.l10n;
  final chosen = await showTorchSheet<String>(
    context,
    builder: (sheetContext) => TorchSheet(
      title: l10n.dashTerritory,
      subtitle: l10n.dashTerritorySheetBody,
      child: territoryOptions(context, ref, filter, sheetContext),
    ),
  );
  applyTerritory(ref, filter, chosen);
}

/// The rows the territory sheet is made of, so the two-part scope sheet on
/// The Floor can put the window chips above exactly these and not a copy of
/// them.
///
/// "All territories" is the first row and is always present, because clearing
/// a filter has to be as cheap as setting one: a screen that can be scoped and
/// not unscoped is a trap.
Widget territoryOptions(
  BuildContext context,
  WidgetRef ref,
  DashboardFilter filter,
  BuildContext sheetContext,
) {
  final l10n = context.l10n;
  final list = ref.read(territoriesListProvider).value ?? const <Territory>[];
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      SoftRow(
        key: const ValueKey<String>('territory-option-all'),
        density: SoftRowDensity.compact,
        title: l10n.dashAllTerritories,
        semanticsLabel: filter.territoryId == null
            ? '${l10n.dashAllTerritories}. ${l10n.dashSelected}'
            : null,
        onTap: () => Navigator.of(sheetContext).pop(allTerritoriesToken),
      ),
      for (var i = 0; i < list.length; i++)
        SoftRow(
          key: ValueKey<String>('territory-option-${list[i].id}'),
          density: SoftRowDensity.compact,
          title: list[i].name,
          subtitle: list[i].code,
          semanticsLabel: list[i].id == filter.territoryId
              ? '${list[i].name}. ${l10n.dashSelected}'
              : null,
          separator: i == list.length - 1
              ? SoftRowSeparator.none
              : SoftRowSeparator.auto,
          onTap: () => Navigator.of(sheetContext).pop(list[i].id),
        ),
    ],
  );
}

/// Write back what the sheet popped. Null is a dismissal and changes nothing;
/// [allTerritoriesToken] is the clear.
void applyTerritory(WidgetRef ref, DashboardFilter filter, String? chosen) {
  if (chosen == null) return;
  ref
      .read(dashboardFilterProvider.notifier)
      .set(
        chosen == allTerritoriesToken
            ? filter.copyWith(clearTerritory: true)
            : filter.copyWith(territoryId: chosen),
      );
}

/// THE FLOOR'S SCOPE SHEET — the window chips and the territory list in one
/// modal, opened from the plate's eyebrow.
///
/// One sheet rather than two, because unify §1.10 gives this product one modal
/// container and forbids stacking: a territory sheet opened from inside a
/// window sheet is the thing that rule exists to stop. The chips are
/// [TorchFilterRail] — the same component the overview's rail is — and the
/// rows are [territoryOptions], the same rows the overview's sheet shows.
///
/// A window chip applies and leaves the sheet up, because changing the window
/// is something a manager does two or three times in a row. A territory row
/// applies and closes, because it is the answer to the question they opened
/// the sheet with.
Future<void> showDashboardScope(BuildContext context, WidgetRef ref) async {
  final chosen = await showTorchSheet<String>(
    context,
    builder: (sheetContext) => _ScopeSheet(parentRef: ref),
  );
  applyTerritory(ref, ref.read(dashboardFilterProvider), chosen);
}

class _ScopeSheet extends ConsumerWidget {
  const _ScopeSheet({required this.parentRef});

  /// The ref the sheet writes the window through. A sheet is pushed onto the
  /// root navigator, so its own `ref` belongs to a subtree that is torn down
  /// when it closes; the window applies *while the sheet is up*, so it has to
  /// be written through the screen's.
  final WidgetRef parentRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final filter = ref.watch(dashboardFilterProvider);

    return TorchSheet(
      title: l10n.dashFilters,
      subtitle: l10n.dashTerritorySheetBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // The rail bleeds to the sheet's own edges — it carries a gutter at
          // each end of its own, and a gutter inside a gutter is a rail that
          // starts in the middle of the sheet.
          TorchBleed(
            extra: context.skin.space.gutter * 2,
            child: TorchFilterRail(
              semanticsLabel: l10n.dashFilters,
              chips: <Widget>[
                for (final range in DashboardRange.values)
                  TorchFilterChip(
                    key: ValueKey<String>('scope-range-${range.name}'),
                    label: rangeLabel(l10n, range),
                    selected: range == filter.range,
                    onSelected: () => parentRef
                        .read(dashboardFilterProvider.notifier)
                        .set(filter.copyWith(range: range)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: TiqSpace.s4),
          Eyebrow(l10n.dashTerritory),
          const SizedBox(height: TiqSpace.s2),
          territoryOptions(context, ref, filter, context),
        ],
      ),
    );
  }
}
