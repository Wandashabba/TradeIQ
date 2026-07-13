import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../data/beatplans_repository.dart';
import 'beat_plan_form_screen.dart';

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
      body: beatPlans.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load beat plans: $err'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(beatPlansListProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) => _BeatPlanCard(plan: list[index]),
        ),
      ),
    );
  }
}

class _BeatPlanCard extends StatelessWidget {
  const _BeatPlanCard({required this.plan});

  final BeatPlan plan;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(plan.name),
        subtitle: Text('${plan.status} · ${plan.scheduledDate}'),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => BeatPlanDetailScreen(planId: plan.id),
          ),
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
      appBar: AppBar(title: const Text('Beat Plan')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load beat plan: $err'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(beatPlanDetailProvider(planId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) => ListView(
          children: [
            ListTile(
              key: const ValueKey<String>('adherence'),
              title: Text('${data.stopsVisited} / ${data.stopsTotal} stops'),
            ),
            for (final stop in data.stops)
              CheckboxListTile(
                key: ValueKey<String>('stop-${stop.id}'),
                title: Text('Stop ${stop.sequence}'),
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
    );
  }
}
