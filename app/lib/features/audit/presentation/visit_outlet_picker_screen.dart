import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/human_error.dart';
import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/agent_kit.dart';
import '../../../core/widgets/agent_scaffold.dart';
import '../../../core/widgets/console.dart' show StatusLevel;
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/pill_segment.dart';
import '../../../core/widgets/worklist.dart';
import '../../../l10n/l10n.dart';
import '../../outlets/data/outlets_repository.dart';

class VisitOutletPickerScreen extends ConsumerWidget {
  const VisitOutletPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onlyMine = ref.watch(onlyMyTerritoriesProvider);
    final outlets = ref.watch(assignedOutletsProvider);
    final l10n = context.l10n;
    return AgentScaffold(
      title: l10n.pickerTitle,
      subtitle: l10n.pickerSubtitle,
      // The primary action lives in the thumb zone, not floating over the list.
      bottomAction: AgentButton(
        label: l10n.pickerAddStore,
        icon: Icons.add_location_alt_outlined,
        secondary: true,
        onPressed: () async {
          await context.push('/outlets/create');
          ref.invalidate(assignedOutletsProvider);
        },
      ),
      body: outlets.when(
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 24),
          children: [
            // The scope control sits above the stores, keyed off the same
            // provider the list reads.
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _ScopeControl(
                onlyMine: onlyMine,
                count: list.length,
                onChanged: (value) =>
                    ref.read(onlyMyTerritoriesProvider.notifier).set(value),
              ),
            ),
            const SizedBox(height: 12),
            // Each store is its own console worklist card; the whole row taps
            // through to the visit — the card IS the start-visit affordance.
            for (final (i, outlet) in list.indexed)
              WorklistCascade(
                index: i,
                child: WorklistRow(
                  title: outlet.name,
                  meta: Text(
                    '${outlet.code} · '
                    '${outlet.lat.toStringAsFixed(5)}, '
                    '${outlet.lng.toStringAsFixed(5)}',
                  ),
                  // Every store is the same "go here" — no per-row severity, so
                  // the row's status channel stays neutral.
                  level: StatusLevel.neutral,
                  onTap: () => context.go('/audit/${outlet.id}'),
                ),
              ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _LoadError(
          error: err,
          onRetry: () => ref.invalidate(assignedOutletsProvider),
        ),
      ),
    );
  }
}

/// Says which stores are being shown, and offers the way out of that — as the
/// console's two-segment pill rather than a 20px switch.
///
/// The list defaults to the agent's own territories, so it has to say so —
/// a filtered list that looks like the whole list is how someone concludes a
/// store is missing from the system. Both segments are always present, because
/// territory data is imperfect and an agent covering someone else's patch
/// needs to reach those stores without finding an administrator first.
///
/// Key change (sub5a Task 3): the old `SwitchListTile` carried a single
/// `only-my-territories` key; a segmented control has two tap targets, so the
/// keys are per-segment — `scope-mine` / `scope-all` — mirroring the console
/// range control's `range-<name>` scheme. The only referencing test (the
/// picker's own) was updated with it.
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
    final colors = context.colors;
    final l10n = context.l10n;
    final control = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            PillSegment(
              key: const ValueKey<String>('scope-mine'),
              label: l10n.pickerScopeMine,
              selected: onlyMine,
              onTap: () => onChanged(true),
              expand: true,
              height: kTapTarget,
            ),
            const SizedBox(width: 8),
            PillSegment(
              key: const ValueKey<String>('scope-all'),
              label: l10n.pickerScopeAll,
              selected: !onlyMine,
              onTap: () => onChanged(false),
              expand: true,
              height: kTapTarget,
            ),
          ],
        ),
        const SizedBox(height: 8),
        // The honesty line: a narrowed list must announce that it is narrowed,
        // and where the rest are.
        Text(
          onlyMine
              ? l10n.pickerScopeMineSummary(count)
              : l10n.pickerScopeAllSummary(count),
          style: TextStyle(fontSize: 12, color: colors.ink3),
        ),
      ],
    );
    if (!colors.glass) return control;
    // Glass: the scope is the list's search bar — one frosted bar above the
    // tiles, the way the handoff floats a search field over its list.
    return GlassPane(
      kind: GlassKind.bar,
      radius: LumenGlass.radiusHero,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 11),
      child: control,
    );
  }
}

/// Loading the outlet list failed. Not a dead end: a restyled state with a
/// thumb-sized retry, never a raw `Text($err)` dump. The detail routes through
/// [humanErrorMessage] so this new surface speaks the app's one voice — a 500
/// or a parse failure must not read to the agent as a connectivity problem.
class _LoadError extends StatelessWidget {
  const _LoadError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.storefront_outlined, size: 34, color: colors.ink3),
        const SizedBox(height: 14),
        Text(
          context.l10n.pickerLoadErrorTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.ink1,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          humanErrorMessage(error),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.5, color: colors.ink2),
        ),
        const SizedBox(height: 20),
        AgentButton(
          key: const ValueKey('retry-outlets'),
          label: context.l10n.pickerRetry,
          onPressed: onRetry,
        ),
      ],
    );
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: colors.glass
            // Glass: the failure sits on a pane, not loose on the ground.
            ? GlassPane(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: content,
              )
            : content,
      ),
    );
  }
}
