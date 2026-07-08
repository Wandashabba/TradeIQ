import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_controller.dart';
import '../data/visits_repository.dart';
import '../../outlets/data/outlets_repository.dart';
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
  const AuditShellScreen({super.key, required this.outletId});

  final String outletId;

  @override
  ConsumerState<AuditShellScreen> createState() => _AuditShellScreenState();
}

class _AuditShellScreenState extends ConsumerState<AuditShellScreen> {
  int _step = 0;
  bool _checkInStarted = false;
  CheckInResult? _checkInResult;
  DateTime? _checkinTs;
  String? _visitDraftId;

  Future<void> _startCheckIn(double outletLat, double outletLng) async {
    final result = await ref.read(visitsRepositoryProvider).checkIn(
          outletId: widget.outletId,
          outletLat: outletLat,
          outletLng: outletLng,
        );
    if (!mounted) return;
    setState(() {
      _checkInResult = result;
      if (result is CheckInSucceeded) {
        _checkinTs = DateTime.now();
        _visitDraftId = result.visitId;
      }
    });
  }

  Outlet? _findOutlet(List<Outlet> outlets) {
    for (final outlet in outlets) {
      if (outlet.id == widget.outletId) return outlet;
    }
    return null;
  }

  List<Widget> _sections() => [
        S1OutletInfoScreen(checkinTs: _checkinTs),
        S2StockScreen(visitDraftId: _visitDraftId!),
        S3S4VisibilityDisplayScreen(visitDraftId: _visitDraftId!),
        const S5PricingPromotionsScreen(),
        const S6CompetitiveScreen(),
        const S7CapabilityScreen(),
        const S8RisksScreen(),
        const S9ActionPlanScreen(),
        const S10ScorecardScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    final outletsAsync = ref.watch(outletsListProvider);

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
      body: outletsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Failed to load outlet: $err')),
        data: (outlets) {
          final outlet = _findOutlet(outlets);
          if (outlet == null) {
            return const Center(child: Text('Outlet not found'));
          }
          if (!_checkInStarted) {
            _checkInStarted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) => _startCheckIn(outlet.lat, outlet.lng));
            return const Center(child: CircularProgressIndicator());
          }
          return switch (_checkInResult) {
            null => const Center(child: CircularProgressIndicator()),
            CheckInSucceeded() => _buildStepper(),
            CheckInGeofenceFailed(:final distanceMeters) => _buildError(
                'You are ${distanceMeters.round()}m from this outlet. Move within 50m to check in.',
              ),
            CheckInLocationUnavailable(:final message) => _buildError(
                message,
                onRetry: () => setState(() => _checkInStarted = false),
              ),
          };
        },
      ),
    );
  }

  Future<void> _submitVisit() async {
    final id = _visitDraftId;
    if (id == null) return;
    await ref.read(visitsRepositoryProvider).submitVisit(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Visit submitted')),
    );
    context.go('/audit');
  }

  Widget _buildStepper() {
    final sections = _sections();
    return SingleChildScrollView(
      child: Column(
        children: [
          Stepper(
            physics: const NeverScrollableScrollPhysics(),
            currentStep: _step,
            onStepContinue: () {
              if (_step < sections.length - 1) setState(() => _step += 1);
            },
            onStepTapped: (index) => setState(() => _step = index),
            steps: sections.map((screen) => Step(title: const SizedBox.shrink(), content: screen)).toList(),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitVisit,
                child: const Text('Submit visit'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message, {VoidCallback? onRetry}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          if (onRetry != null)
            ElevatedButton(onPressed: onRetry, child: const Text('Retry'))
          else
            ElevatedButton(onPressed: () => context.go('/audit'), child: const Text('Back to outlets')),
        ],
      ),
    );
  }
}
