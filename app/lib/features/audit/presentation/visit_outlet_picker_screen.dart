import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/agent_kit.dart';
import '../../../core/widgets/agent_scaffold.dart';
import '../../../core/widgets/console.dart' show StatusLevel;
import '../../../core/widgets/worklist.dart';
import '../../outlets/data/outlets_repository.dart';

class VisitOutletPickerScreen extends ConsumerWidget {
  const VisitOutletPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onlyMine = ref.watch(onlyMyTerritoriesProvider);
    final outlets = ref.watch(assignedOutletsProvider);
    return AgentScaffold(
      title: 'Select an Outlet',
      subtitle: 'Tap a store to start a visit',
      // The primary action lives in the thumb zone, not floating over the list.
      bottomAction: AgentButton(
        label: 'Add a store',
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
        error: (err, _) =>
            _LoadError(onRetry: () => ref.invalidate(assignedOutletsProvider)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _ScopeSegment(
                segmentKey: 'scope-mine',
                label: 'My territories',
                selected: onlyMine,
                onTap: () => onChanged(true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ScopeSegment(
                segmentKey: 'scope-all',
                label: 'All stores',
                selected: !onlyMine,
                onTap: () => onChanged(false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // The honesty line: a narrowed list must announce that it is narrowed,
        // and where the rest are.
        Text(
          onlyMine
              ? '$count in your territories · tap All stores to see every shop'
              : 'All $count stores across this client',
          style: TextStyle(fontSize: 12, color: colors.ink3),
        ),
      ],
    );
  }
}

class _ScopeSegment extends StatelessWidget {
  const _ScopeSegment({
    required this.segmentKey,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String segmentKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // The active pill is otherwise colour-only to a screen reader: selected
    // carries the state, button makes each segment actionable.
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        key: ValueKey<String>(segmentKey),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: kTapTarget,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // Active = solid brand, inactive = surface + hairline. White-on-
            // brand is a self-contained AA pair; neither theme's ink may sit on
            // brand (dark ink1 on brand would fail AA).
            color: selected ? colors.brand : colors.surface1,
            border: Border.all(color: selected ? colors.brand : colors.line),
            borderRadius: BorderRadius.circular(AppColors.radiusPill),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : colors.ink2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Loading the outlet list failed. Not a dead end: a restyled state with a
/// thumb-sized retry, never a raw `Text($err)` dump.
class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_outlined, size: 34, color: colors.ink3),
            const SizedBox(height: 14),
            Text(
              'Could not load your stores',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.ink1,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.5, color: colors.ink2),
            ),
            const SizedBox(height: 20),
            AgentButton(
              key: const ValueKey('retry-outlets'),
              label: 'Try again',
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
