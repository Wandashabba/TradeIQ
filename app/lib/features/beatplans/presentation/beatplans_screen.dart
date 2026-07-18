import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../../../core/widgets/worklist.dart';
import '../data/beatplans_repository.dart';
import 'beat_plan_form_screen.dart';

/// Beat plans as a worklist: what is scheduled, what is running, what is done.
class BeatPlansScreen extends ConsumerWidget {
  const BeatPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final beatPlans = ref.watch(beatPlansListProvider);
    final role = ref.watch(sessionControllerProvider).value?.role;
    // Planning is a manager/admin action; a field agent only executes plans.
    final canBuild = role == 'manager' || role == 'admin';
    return ManagerScaffold(
      title: 'My Beat Plans',
      floatingActionButton: canBuild
          ? FloatingActionButton(
              key: const ValueKey<String>('beatplan-create-fab'),
              tooltip: 'New beat plan',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const BeatPlanFormScreen(),
                ),
              ),
              child: const Icon(Icons.add),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AsyncSection<List<BeatPlan>>(
            value: beatPlans,
            label: 'beat plans',
            onRetry: () => ref.invalidate(beatPlansListProvider),
            builder: (list) => PanelCard(
              title: '${list.length} ${list.length == 1 ? 'plan' : 'plans'}',
              subtitle: 'Tap a plan to work its stops',
              padded: false,
              child: list.isEmpty
                  ? const EmptyState(
                      message: 'No beat plans',
                      hint: 'A plan is a day of outlet stops in visit order.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final plan in list) _BeatPlanRow(plan: plan),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A plan in flight is the one a manager can still act on; a missed one is the
/// one that cost a visit. Both outrank a plan that is merely scheduled.
StatusLevel _levelFor(String status) => switch (status) {
      'completed' => StatusLevel.good,
      'in_progress' => StatusLevel.warning,
      'missed' || 'cancelled' => StatusLevel.critical,
      _ => StatusLevel.neutral,
    };

String _statusWord(String status) => switch (status) {
      'scheduled' => 'Scheduled',
      'in_progress' => 'In progress',
      'completed' => 'Completed',
      'missed' => 'Missed',
      'cancelled' => 'Cancelled',
      _ => status,
    };

class _BeatPlanRow extends StatelessWidget {
  const _BeatPlanRow({required this.plan});

  final BeatPlan plan;

  @override
  Widget build(BuildContext context) {
    return WorklistRow(
      key: ValueKey<String>('beatplan-${plan.id}'),
      title: plan.name,
      // The plan code is what the stops endpoint keys on — mono token, so a
      // manager can quote it straight back at the API or a support ticket.
      meta: Row(
        children: [
          CodeToken(plan.id),
          const SizedBox(width: 6),
          const Text('·'),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              plan.scheduledDate,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      level: _levelFor(plan.status),
      statusLabel: _statusWord(plan.status),
      resolved: plan.status == 'completed',
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => BeatPlanDetailScreen(planId: plan.id),
        ),
      ),
    );
  }
}

class BeatPlanDetailScreen extends ConsumerWidget {
  const BeatPlanDetailScreen({super.key, required this.planId});

  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(beatPlanDetailProvider(planId));
    return Scaffold(
      backgroundColor: context.colors.plane,
      appBar: AppBar(title: const Text('Beat Plan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AsyncSection<BeatPlanDetail>(
            value: detail,
            label: 'beat plan',
            onRetry: () => ref.invalidate(beatPlanDetailProvider(planId)),
            builder: (data) => PanelCard(
              title: data.plan.name,
              subtitle: data.plan.scheduledDate,
              trailing: StatusChip(
                label: _statusWord(data.plan.status),
                level: _levelFor(data.plan.status),
              ),
              padded: false,
              // The tiles paint their ink on the nearest Material ancestor —
              // give them a transparent one *inside* the panel, or their
              // splashes land behind the panel's own background.
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      key: const ValueKey<String>('adherence'),
                      title: Text(
                        '${data.stopsVisited} / ${data.stopsTotal} stops',
                      ),
                      subtitle: Text(
                        '${(data.adherenceRate * 100).toStringAsFixed(0)}% adherence',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: context.colors.ink3,
                        ),
                      ),
                    ),
                    Divider(height: 1, color: context.colors.line),
                    for (final stop in data.stops)
                      CheckboxListTile(
                        key: ValueKey<String>('stop-${stop.id}'),
                        title: Text('Stop ${stop.sequence}'),
                        subtitle: Align(
                          alignment: Alignment.centerLeft,
                          child: CodeToken(stop.outletId),
                        ),
                        value: stop.visited,
                        onChanged: (v) async {
                          await ref
                              .read(beatPlansRepositoryProvider)
                              .markStopVisited(planId, stop.id, v ?? false);
                          ref.invalidate(beatPlanDetailProvider(planId));
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
