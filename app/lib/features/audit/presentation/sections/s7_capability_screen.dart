import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tiq_colors.dart';
import '../../../../core/widgets/agent_kit.dart';
import '../../data/capability_repository.dart';

/// S7 — Sales Capability capture: confirmed staff headcount, rep training
/// status, and quiz score. On save the capture is queued for sync
/// (POST /capability).
class S7CapabilityScreen extends ConsumerStatefulWidget {
  const S7CapabilityScreen({super.key, required this.visitDraftId});

  final String visitDraftId;

  @override
  ConsumerState<S7CapabilityScreen> createState() => _S7State();
}

class _S7State extends ConsumerState<S7CapabilityScreen> {
  static const _trainingOptions = {
    'productKnowledge': 'Product knowledge',
    'merchandising': 'Merchandising',
    'posSystems': 'POS systems',
  };

  final _training = {for (final key in _trainingOptions.keys) key: false};
  final _headcount = TextEditingController();
  final _quiz = TextEditingController();
  bool _saved = false;

  @override
  void dispose() {
    _headcount.dispose();
    _quiz.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref
        .read(capabilityRepositoryProvider)
        .saveCapability(
          visitDraftId: widget.visitDraftId,
          capture: CapabilityCapture(
            staffHeadcountConfirmed: int.tryParse(_headcount.text) ?? 0,
            repTrainingStatus: Map<String, bool>.from(_training),
            quizScore: int.tryParse(_quiz.text) ?? 0,
          ),
        );
    if (mounted) setState(() => _saved = true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AgentField(
          label: 'Staff headcount confirmed',
          child: TextField(
            key: const ValueKey('headcount'),
            controller: _headcount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Reps on the floor'),
          ),
        ),
        Text(
          'Rep training completed',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: colors.ink2,
          ),
        ),
        const SizedBox(height: 7),
        for (final entry in _trainingOptions.entries)
          AgentCheck(
            key: ValueKey('training-${entry.key}'),
            label: entry.value,
            value: _training[entry.key] ?? false,
            onChanged: (v) => setState(() => _training[entry.key] = v),
          ),
        const SizedBox(height: 16),
        AgentField(
          label: 'Quiz score (0-100)',
          child: TextField(
            key: const ValueKey('quiz'),
            controller: _quiz,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: '0-100'),
          ),
        ),
        AgentButton(label: 'Save capability', onPressed: _save),
        if (_saved)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Capability saved — queued for sync',
              style: TextStyle(color: colors.ink2),
            ),
          ),
      ],
    );
  }
}
