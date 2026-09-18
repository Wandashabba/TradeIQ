import 'package:flutter/widgets.dart';

import 'row_marks.dart';
import 'soft_row.dart';

/// What a manager can see about work sitting unsent on an agent's phone
/// (#391).
///
/// The console's mirror of [OutboxState], and deliberately a **shorter**
/// enum: the manager does not hold the data, so "waiting for its visit" and
/// "paused" are the phone's business and never reach the console.
enum HeldWorkState {
  /// The normal state of South African field connectivity, and never red. An
  /// amber queue chip here would make load-shedding look like a fault.
  held,

  /// The phone is sending. Oatmeal dots, not an amber pulse.
  sending,

  /// A real next-attempt time.
  retrying,

  /// Over 24 hours, or three failed retries. The one severity-bearing state,
  /// and it is `watch`, not `critical` — the work is not lost, it is late.
  stuck,

  /// The agent's app is on an older version and does not report. Ink-mute, a
  /// barred ring, and not tappable.
  unknown,
}

/// The console's mirror of the outbox row, so a quiet scorecard is never
/// mistaken for a lazy agent (#391).
///
/// A configuration of [SoftRow] at `compact` density — the console's list
/// height — with the Truffle `comparison` square that means *them, unlit* and
/// never a severity.
///
/// It never offers a "force send". The manager does not hold the data, and a
/// button that cannot work is worse than none.
class HeldWorkRow extends StatelessWidget {
  const HeldWorkRow({
    super.key,
    required this.state,
    required this.title,
    required this.stateWord,
    this.meta,
    this.stuckLabel,
    this.onTap,
    this.separator = SoftRowSeparator.auto,
  }) : assert(
         state != HeldWorkState.stuck || stuckLabel != null,
         'HeldWorkRow: the stuck state carries a severity bar and therefore '
         'needs the severity in words.',
       );

  final HeldWorkState state;

  /// "4 visits held on this phone" — a count and a place, never an entity
  /// name.
  final String title;

  /// "Held", "Sending", "Retrying", "Stuck", "Unknown". Sentence case.
  final String stateWord;

  /// "oldest 2 h 14 m · last sent 11:48", already formatted and localised.
  final String? meta;

  /// The severity in words for the stuck state.
  final String? stuckLabel;

  final VoidCallback? onTap;
  final SoftRowSeparator separator;

  bool get _tappable => state != HeldWorkState.unknown && onTap != null;

  @override
  Widget build(BuildContext context) {
    return SoftRow(
      density: SoftRowDensity.compact,
      title: title,
      subtitle: stateWord,
      meta: meta == null ? null : Text(meta!),
      leading: RowMarkTile(mark: _mark, tone: _tone),
      trailing: _tappable ? const SoftRowChevron() : null,
      severity: state == HeldWorkState.stuck
          ? SoftRowSeverity.watch
          : SoftRowSeverity.none,
      severityLabel: stuckLabel,
      enabled: state != HeldWorkState.unknown,
      onTap: _tappable ? onTap : null,
      separator: separator,
      semanticsLabel: <String?>[
        if (state == HeldWorkState.stuck) stuckLabel,
        stateWord,
        title,
        meta,
      ].whereType<String>().join('. '),
    );
  }

  RowMark get _mark => switch (state) {
    HeldWorkState.held => RowMark.square,
    HeldWorkState.sending => RowMark.dots,
    HeldWorkState.retrying => RowMark.circularArrow,
    HeldWorkState.stuck => RowMark.triangle,
    HeldWorkState.unknown => RowMark.barredRing,
  };

  RowMarkTone get _tone => switch (state) {
    // Truffle: "them, unlit". It is the comparison series and the held
    // neutral, and giving it a third meaning is the failure the severity
    // system exists to avoid — so `stuck` takes crimson and nothing else here
    // does.
    HeldWorkState.held => RowMarkTone.comparison,
    HeldWorkState.sending || HeldWorkState.retrying => RowMarkTone.neutral,
    HeldWorkState.stuck => RowMarkTone.severe,
    HeldWorkState.unknown => RowMarkTone.muted,
  };
}
