import 'package:flutter/material.dart';

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

class DashboardShellScreen extends StatelessWidget {
  const DashboardShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manager Dashboard')),
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
