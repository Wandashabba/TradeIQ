import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';

const _kpiLabels = [
  'Numeric Distribution',
  'Weighted Distribution',
  'OSA %',
  'Execution Score',
  'Price Compliance %',
  'Visibility Compliance %',
  'Share of Shelf',
  'Perfect Store Rate',
];

class DashboardShellScreen extends ConsumerWidget {
  const DashboardShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(sessionControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: _kpiLabels
              .map((label) => Card(
                    child: Center(
                      child: Text(label, textAlign: TextAlign.center),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}
