import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../data/trends_repository.dart';

class TrendsScreen extends ConsumerWidget {
  const TrendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trends'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(sessionControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TrendSection(
              key: const ValueKey('trend-scorecards'),
              heading: 'Scorecard trend',
              provider: scorecardsTrendProvider,
            ),
            const SizedBox(height: 24),
            _TrendSection(
              key: const ValueKey('trend-availability'),
              heading: 'Availability trend',
              provider: availabilityTrendProvider,
            ),
            const SizedBox(height: 24),
            _TrendSection(
              key: const ValueKey('trend-perfect-store'),
              heading: 'Perfect store trend',
              provider: perfectStoreTrendProvider,
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendSection extends ConsumerWidget {
  const _TrendSection({
    super.key,
    required this.heading,
    required this.provider,
  });

  final String heading;
  final FutureProvider<List<TrendPoint>> provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(heading, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ref.watch(provider).when(
              loading: () => const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, stack) => Text('Failed to load: $err'),
              data: (points) => _TrendBars(points: points),
            ),
      ],
    );
  }
}

class _TrendBars extends StatelessWidget {
  const _TrendBars({required this.points});

  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    var max = 1.0;
    for (final point in points) {
      if (point.value > max) max = point.value;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final point in points)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    point.period.length > 10
                        ? point.period.substring(0, 10)
                        : point.period,
                  ),
                ),
                Expanded(
                  child: SizedBox(
                    height: 16,
                    child: FractionallySizedBox(
                      widthFactor: (point.value / max).clamp(0.0, 1.0),
                      alignment: Alignment.centerLeft,
                      child: Container(height: 16, color: Colors.blue),
                    ),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(point.value.toStringAsFixed(0)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
