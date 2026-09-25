import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/torch_scope.dart';
import '../../../core/network/human_error.dart';
import '../../../core/theme/torchlight/agent_skin.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/skin_controls.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../core/widgets/torchlight/sync_status.dart';
import '../../../core/widgets/agent_location_banners.dart';
import '../../../l10n/l10n.dart';
import '../../outlets/data/outlets_repository.dart';

/// THE STORE PICKER — the way into a visit that is not on today's plan.
///
/// ```text
///   Select an Outlet              [ 12 held on this phone ]
///   Tap a store to start a visit
///   ── Which stores ────────────────────────────
///   ( My territories ✓ ) ( All stores )
///   7 in your territories · tap All stores to see every shop
///   ── Stores ──────────────────────────────────
///   ▏ Kasi Corner Spaza                          ›
///   ▏ KC-0412
///   ▏ Sunrise Spaza                              ›
///   [ ☾ ]  [        Add a store        ]
/// ```
///
/// ## The honesty line stays
///
/// The list defaults to the agent's own territories, so it has to **say** so
/// and say how many it is showing. A narrowed list that looks like the whole
/// list is how somebody concludes a store is missing from the system and
/// phones an administrator about a filter. Both scopes are always reachable,
/// because territory data is imperfect and an agent covering a colleague's
/// patch must not need an administrator to check in.
///
/// ## Amber
///
/// Not a tab root — the agent came here to pick one store and leave — so the
/// nav takes no slot and the thumb zone carries the one commit. "Add a store"
/// is a **secondary**: creating an outlet is the rare path, and the expected
/// next move on this screen is tapping a store that already exists. A row is
/// not a commit action and never lights, so this route paints **zero** amber
/// objects on every skin, which is the honest reading of a list.
///
/// The coordinates the old rows printed under each name are gone. Five decimal
/// places of latitude is not something an agent reads standing in a doorway,
/// it went through `toStringAsFixed` in a widget, and the store code is the
/// identifier that actually appears on paperwork.
class VisitOutletPickerScreen extends ConsumerWidget {
  const VisitOutletPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const TorchlightRoute(child: _Picker());
  }
}

class _Picker extends ConsumerWidget {
  const _Picker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final onlyMine = ref.watch(onlyMyTerritoriesProvider);
    final outlets = ref.watch(assignedOutletsProvider);

    return outlets.when(
      loading: () => const _PickerFrame(
        phase: 'loading',
        children: <Widget>[_PickerSkeleton()],
      ),
      error: (error, stack) => _PickerFrame(
        phase: 'error',
        children: <Widget>[
          ErrorState(
            message: TorchErrorMessage(
              kind: TorchErrorKind.unknown,
              headline: l10n.pickerLoadErrorTitle,
              // The app's one voice: a 500 and a parse failure must not read
              // to an agent as a connectivity problem.
              body: humanErrorMessage(error, l10n),
              offersRetry: true,
            ),
            action: TorchSecondaryButton(
              key: const ValueKey<String>('retry-outlets'),
              label: l10n.pickerRetry,
              onPressed: () => ref.invalidate(assignedOutletsProvider),
            ),
          ),
          const SizedBox(height: TiqSpace.s5),
          // What the failure did not touch, said at `meta` under the error —
          // an agent who cannot load the store list is otherwise left
          // wondering about the captures on the phone.
          Text(
            l10n.pickerLoadErrorBody,
            style: context.skin.text.meta.style(
              color: context.skin.palette.ink3,
            ),
          ),
        ],
      ),
      data: (list) => _PickerFrame(
        phase: list.isEmpty ? 'empty' : 'loaded',
        children: <Widget>[
          SectionRule(l10n.pickerScopeHeading),
          const SizedBox(height: TiqSpace.s4),
          _ScopeControl(
            onlyMine: onlyMine,
            count: list.length,
            onChanged: (value) =>
                ref.read(onlyMyTerritoriesProvider.notifier).set(value),
          ),
          const SizedBox(height: TiqSpace.s7),
          if (list.isEmpty)
            EmptyState(
              headline: l10n.pickerEmptyTitle,
              drawing: EmptyDrawing.shelf,
              body: onlyMine
                  ? l10n.pickerEmptyBodyMine
                  : l10n.pickerEmptyBodyAll,
            )
          else ...<Widget>[
            SectionRule(l10n.pickerStoresHeading, count: list.length),
            const SizedBox(height: TiqSpace.s4),
            _OutletList(outlets: list),
          ],
        ],
      ),
    );
  }
}

/// The frame every state of this route wears.
class _PickerFrame extends ConsumerWidget {
  const _PickerFrame({required this.phase, required this.children});

  final String phase;
  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final skin = context.skin;

    return TorchScope(
      skin: skin,
      phase: phase,
      navRenders: false,
      tabbedRoute: false,
      // Nothing on this screen is a commit. The rows are the affordance and a
      // row never emits light, so the ladder has nothing to hand out.
      claims: const <TorchClaim>[],
      child: TorchShell(
        profile: TorchShellProfile.agent,
        header: TorchAppHeader(
          title: l10n.pickerTitle,
          facts: <String>[l10n.pickerSubtitle],
          back: TorchIconButton(
            icon: Icons.arrow_back,
            // Never "Back": a destination, so a screen reader says where —
            // and it GOES there. Every way in is a `go('/audit')`, which
            // replaces the stack, so a `pop()` here had nothing to pop and
            // stranded the agent on the picker. The old scaffold's back went
            // to Today; so does this one, and the label says so.
            semanticLabel: l10n.navToday,
            onPressed: () => context.go('/today'),
          ),
          status: const TorchSyncChip(),
        ),
        // Not a tab root, so the skin cycle sits at the leading end of the
        // thumb zone. Never a screen without it — Veld has to be reachable
        // from wherever an agent is standing.
        skinCycle: const AgentSkinCycle(),
        secondary: TorchSecondaryButton(
          key: const ValueKey<String>('add-store'),
          label: l10n.pickerAddStore,
          icon: Icons.add_location_alt_outlined,
          onPressed: () async {
            await context.push('/outlets/create');
            ref.invalidate(assignedOutletsProvider);
          },
        ),
        children: <Widget>[
          // The banner form of the sync status (unify §1.14): it renders only
          // when something genuinely needs the agent, and nothing at all
          // otherwise. Held work stays a chip in the header — a permanent
          // 56dp band on every screen spends the fold.
          const TorchSyncBanner(),
          // Whether the agent is being located has an answer on every agent
          // screen (#153, POPIA) — see AgentLocationBanners.
          const AgentLocationBanners(),
          ...children,
        ],
      ),
    );
  }
}

/// Says which stores are being shown, offers the way out of that, and states
/// how many it is showing.
class _ScopeControl extends StatelessWidget {
  const _ScopeControl({
    required this.onlyMine,
    required this.count,
    required this.onChanged,
  });

  final bool onlyMine;
  final int count;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TorchFilterRail(
          semanticsLabel: l10n.pickerScopeHeading,
          chips: <Widget>[
            TorchFilterChip(
              key: const ValueKey<String>('scope-mine'),
              label: l10n.pickerScopeMine,
              selected: onlyMine,
              onSelected: () => onChanged(true),
            ),
            TorchFilterChip(
              key: const ValueKey<String>('scope-all'),
              label: l10n.pickerScopeAll,
              selected: !onlyMine,
              onSelected: () => onChanged(false),
            ),
          ],
        ),
        const SizedBox(height: TiqSpace.s3),
        // THE HONESTY LINE. A narrowed list must announce that it is narrowed
        // and where the rest are — and it says the count, so "nothing here"
        // and "nothing anywhere" are never the same sentence.
        Text(
          onlyMine
              ? l10n.pickerScopeMineSummary(count)
              : l10n.pickerScopeAllSummary(count),
          style: skin.text.meta.style(color: skin.palette.ink3),
        ),
      ],
    );
  }
}

/// Every store is the same "go here", so no row carries a severity and the
/// row's status channel stays neutral. The whole row is the start-visit
/// affordance — there is no second button on it.
class _OutletList extends StatelessWidget {
  const _OutletList({required this.outlets});

  final List<Outlet> outlets;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    return TorchBleed(
      extra: skin.space.gutter * 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final (i, outlet) in outlets.indexed)
            SoftRow(
              key: ValueKey<String>('outlet-${outlet.id}'),
              title: outlet.name,
              // An outlet name middle-truncates so the branch survives when
              // the chain does not: "Pick n Pay …Vosloorus".
              titleTruncation: SoftRowTruncation.middle,
              subtitle: outlet.code,
              trailing: const SoftRowChevron(),
              separator: i == outlets.length - 1
                  ? SoftRowSeparator.none
                  : SoftRowSeparator.auto,
              semanticsLabel: l10n.pickerStartVisitSemantics(
                outlet.name,
                outlet.code,
              ),
              onTap: () => context.go('/audit/${outlet.id}'),
            ),
        ],
      ),
    );
  }
}

/// The real geometry, empty.
class _PickerSkeleton extends StatelessWidget {
  const _PickerSkeleton();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Skeleton(
      label: context.l10n.pickerTitle,
      slowLine: context.l10n.pickerSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SkeletonShell(height: 56),
          SizedBox(height: skin.space.blockGap),
          const SkeletonRows(count: 6),
        ],
      ),
    );
  }
}
