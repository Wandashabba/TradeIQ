import 'package:flutter/material.dart';

class S1OutletInfoScreen extends StatelessWidget {
  const S1OutletInfoScreen({super.key, this.checkinTs});

  final DateTime? checkinTs;

  @override
  Widget build(BuildContext context) {
    final ts = checkinTs;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('S1 Outlet Information'),
          const SizedBox(height: 8),
          if (ts != null) Text('Checked in at $ts — Geofence: passed'),
        ],
      ),
    );
  }
}
