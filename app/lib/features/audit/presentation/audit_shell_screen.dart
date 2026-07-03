import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import 'sections/s1_outlet_info_screen.dart';
import 'sections/s2_stock_screen.dart';
import 'sections/s3_4_visibility_display_screen.dart';
import 'sections/s5_pricing_promotions_screen.dart';
import 'sections/s6_competitive_screen.dart';
import 'sections/s7_capability_screen.dart';
import 'sections/s8_risks_screen.dart';
import 'sections/s9_action_plan_screen.dart';
import 'sections/s10_scorecard_screen.dart';

class AuditShellScreen extends ConsumerStatefulWidget {
  const AuditShellScreen({super.key});

  @override
  ConsumerState<AuditShellScreen> createState() => _AuditShellScreenState();
}

class _AuditShellScreenState extends ConsumerState<AuditShellScreen> {
  int _step = 0;

  static const List<Widget> _sections = [
    S1OutletInfoScreen(),
    S2StockScreen(),
    S3S4VisibilityDisplayScreen(),
    S5PricingPromotionsScreen(),
    S6CompetitiveScreen(),
    S7CapabilityScreen(),
    S8RisksScreen(),
    S9ActionPlanScreen(),
    S10ScorecardScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Visit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(sessionControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Stepper(
          physics: const NeverScrollableScrollPhysics(),
          currentStep: _step,
          onStepContinue: () {
            if (_step < _sections.length - 1) setState(() => _step += 1);
          },
          onStepTapped: (index) => setState(() => _step = index),
          steps: _sections
              .map(
                (screen) =>
                    Step(title: const SizedBox.shrink(), content: screen),
              )
              .toList(),
        ),
      ),
    );
  }
}
