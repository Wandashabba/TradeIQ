import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../../../core/widgets/worklist.dart';
import '../data/clients_repository.dart';

class ClientConfigScreen extends ConsumerWidget {
  const ClientConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(clientConfigProvider);

    return ManagerScaffold(
      title: 'Scoring Config',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AsyncSection<ClientConfig>(
            value: config,
            label: 'config',
            onRetry: () => ref.invalidate(clientConfigProvider),
            builder: (cfg) => _ConfigForm(config: cfg),
          ),
        ],
      ),
    );
  }
}

class _ConfigForm extends ConsumerStatefulWidget {
  const _ConfigForm({required this.config});

  final ClientConfig config;

  @override
  ConsumerState<_ConfigForm> createState() => _ConfigFormState();
}

class _ConfigFormState extends ConsumerState<_ConfigForm> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    widget.config.scorecardWeights.forEach((key, value) {
      _controllers[key] = TextEditingController(text: value.toString())
        // The share column has to move as you type, or the weights are just
        // opaque numbers.
        ..addListener(() => setState(() {}));
    });
  }

  Future<void> _submit() async {
    final map = <String, double>{};
    _controllers.forEach((key, controller) {
      map[key] = double.tryParse(controller.text) ?? 0;
    });
    await ref.read(clientsRepositoryProvider).updateWeights(map);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved')),
      );
      ref.invalidate(clientConfigProvider);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double _weightOf(String key) =>
      double.tryParse(_controllers[key]!.text) ?? 0;

  /// The server scores with `weightedSum / weightSum`, so the weights are
  /// *relative* — they do not have to add up to 1. What actually matters is
  /// each dimension's share of the total, which is what we show.
  double get _total => _controllers.keys
      .map(_weightOf)
      .where((w) => w > 0)
      .fold(0.0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    final total = _total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelCard(
          title: 'Scorecard weights',
          subtitle: 'Relative — the server normalises by their total',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Expanded(flex: 5, child: SectionLabel('Dimension')),
                  Expanded(flex: 3, child: SectionLabel('Weight')),
                  Expanded(flex: 3, child: SectionLabel('Share of score')),
                ],
              ),
              const SizedBox(height: 8),
              for (final entry in _controllers.entries)
                _WeightRow(
                  dimension: entry.key,
                  controller: entry.value,
                  weight: _weightOf(entry.key),
                  total: total,
                ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton(
                  key: const ValueKey<String>('save-config'),
                  onPressed: _submit,
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Weights are relative, not percentages: the score is the weighted '
          'average divided by the total weight, so doubling every weight changes '
          'nothing. A dimension weighted 0 is dropped from the score entirely.',
          style: TextStyle(fontSize: 11.5, color: AppColors.ink3, height: 1.5),
        ),
      ],
    );
  }
}

class _WeightRow extends StatelessWidget {
  const _WeightRow({
    required this.dimension,
    required this.controller,
    required this.weight,
    required this.total,
  });

  final String dimension;
  final TextEditingController controller;
  final double weight;
  final double total;

  @override
  Widget build(BuildContext context) {
    final excluded = weight <= 0;
    final share = (excluded || total <= 0) ? 0.0 : (weight / total) * 100;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              _humanise(dimension),
              style: const TextStyle(fontSize: 13, color: AppColors.ink1),
            ),
          ),
          Expanded(
            flex: 3,
            child: TextField(
              key: ValueKey<String>('weight-$dimension'),
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(isDense: true),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              // A dropped dimension is stated in words, not implied by a 0.
              child: excluded
                  ? const StatusChip(label: 'Excluded', level: StatusLevel.warning)
                  : Text(
                      '${share.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink1,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  static String _humanise(String key) {
    final spaced = key.replaceAllMapped(
      RegExp('([a-z])([A-Z])'),
      (m) => '${m[1]} ${m[2]!.toLowerCase()}',
    );
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
}
