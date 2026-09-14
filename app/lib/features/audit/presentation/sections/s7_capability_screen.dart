import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/lumen_glass.dart';
import '../../../../core/theme/tiq_colors.dart';
import '../../../../core/widgets/agent_kit.dart';
import '../../../../core/widgets/glass.dart';
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
    final headcount = AgentField(
      label: 'Staff headcount confirmed',
      child: TextField(
        key: const ValueKey('headcount'),
        controller: _headcount,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(hintText: 'Reps on the floor'),
      ),
    );
    final training = <Widget>[
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
    ];
    final quiz = AgentField(
      label: 'Quiz score (0-100)',
      child: TextField(
        key: const ValueKey('quiz'),
        controller: _quiz,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(hintText: '0-100'),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (colors.glass) ...[
          // Glass: each question on its own no-blur tile. AgentField pads its
          // own bottom, so a field tile trims its padding back to match.
          _Tile(bottom: 0, children: [headcount]),
          const SizedBox(height: 10),
          _Tile(bottom: 8, children: training),
          const SizedBox(height: 10),
          _Tile(bottom: 0, children: [quiz]),
          const SizedBox(height: 16),
        ] else ...[
          headcount,
          ...training,
          const SizedBox(height: 16),
          quiz,
        ],
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

/// One question group as a no-blur glass tile (the section scrolls).
class _Tile extends StatelessWidget {
  const _Tile({required this.children, this.bottom = 14});

  final List<Widget> children;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return GlassPane(
      kind: GlassKind.tile,
      blur: false,
      radius: LumenGlass.radiusCard,
      padding: EdgeInsets.fromLTRB(16, 14, 16, bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
