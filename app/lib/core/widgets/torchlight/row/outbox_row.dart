import 'package:flutter/widgets.dart';

import '../../../design/figure_slot.dart';
import '../../../design/tiq_number.dart';
import '../../../theme/torchlight/tiq_skin.dart';
import 'row_marks.dart';
import 'soft_row.dart';

/// What one queued capture is doing (#382).
///
/// Every member has its own **silhouette** and its own **word**, and the two
/// together are what a greyscale screenshot, a deuteranope and a screen reader
/// get. Colour appears on exactly one of them — [stuck] — and it appears
/// beside a triangle, a severity bar and the words.
enum OutboxState {
  /// Waiting for signal. The normal state of South African field connectivity
  /// and never styled as an error.
  queued,

  /// Bytes are moving. Oatmeal dots — **never an amber pulse**.
  sending,

  /// A failed attempt with a real next-attempt time, not "will retry soon".
  retrying,

  /// Gone up. Still tappable, because the point of the outbox is that held
  /// work can always be looked at.
  sent,

  /// The server said no, or the session ended, or it is too big. The one
  /// severity-bearing state.
  stuck,

  /// Blocked on the visit above it. An ordering dependency, explicitly not a
  /// fault, and not tappable — tapping it can do nothing.
  waitingForVisit,
}

/// One queued capture, alive: what it is, what it is doing, how big it is, and
/// a way in (#382).
///
/// This is a **configuration of [SoftRow]**, not a second row component. It
/// chooses a density, a mark, a severity and three strings, and hands them to
/// the same widget every other list in the app uses. Nothing here paints a
/// fill, an edge or a rule of its own.
///
/// The size is the **decoded** payload, which is what `SyncQueueItems.
/// payloadBytes` stores: the base64 length overstates a photo by about a
/// third, and the figure exists so an agent on a 1 GB bundle can decide
/// whether to send now. A number that is wrong in the direction that matters
/// is worse than no number.
///
/// ```dart
/// OutboxRow(
///   state: OutboxState.retrying,
///   title: l10n.outboxShelfPhoto(outlet.name),
///   stateWord: l10n.outboxRetrying,
///   sentence: l10n.outboxRetryingAt(nextAttempt),
///   payloadBytes: item.payloadBytes,
///   ageLine: l10n.outboxQueuedAt(item.queuedAt),
///   onTap: () => showOutboxItemSheet(context, item),
/// )
/// ```
class OutboxRow extends StatelessWidget {
  const OutboxRow({
    super.key,
    required this.state,
    required this.title,
    required this.stateWord,
    required this.sentence,
    required this.ageLine,
    this.payloadBytes,
    this.stuckLabel,
    this.onTap,
    this.separator = SoftRowSeparator.auto,
  }) : assert(
         state != OutboxState.stuck || stuckLabel != null,
         'OutboxRow: a stuck row carries a severity bar, so it needs the '
         'severity in words — the bar is crimson and the word is the channel '
         'that survives greyscale and a screen reader.',
       );

  final OutboxState state;

  /// What the item is, in the agent's words and never the entity type:
  /// "Shelf photo · Kasi Corner Spaza", not "VisitSectionPhotoDto".
  final String title;

  /// The state in one or two words, already localised. Sentence case, at the
  /// `label` role — **not** an eyebrow: unify §1.17 legalises the uppercase
  /// eyebrow in exactly three places and a queue row's trailing word is not
  /// one of them.
  final String stateWord;

  /// The state as a sentence: "Waiting for signal", "Retrying at 14:20",
  /// "The server said no (422)". The real next-attempt time and the real
  /// stored error, never a euphemism.
  final String sentence;

  /// "queued 14:03", "sent 08:04" — already localised and already formatted.
  final String ageLine;

  /// Decoded payload size. Null renders nothing rather than a zero: an unknown
  /// size is not a size of zero.
  final int? payloadBytes;

  /// The severity in words for the stuck state — "Needs you".
  final String? stuckLabel;

  final VoidCallback? onTap;
  final SoftRowSeparator separator;

  bool get _tappable => state != OutboxState.waitingForVisit && onTap != null;

  @override
  Widget build(BuildContext context) {
    final size = payloadBytes == null
        ? null
        : PayloadSize.of(payloadBytes!);

    return SoftRow(
      density: SoftRowDensity.tall,
      title: title,
      subtitle: sentence,
      meta: _MetaLine(size: size, ageLine: ageLine),
      leading: RowMarkTile(mark: _mark, tone: _tone),
      trailing: _Trailing(word: stateWord, tappable: _tappable),
      severity: state == OutboxState.stuck
          ? SoftRowSeverity.critical
          : SoftRowSeverity.none,
      severityLabel: stuckLabel,
      onTap: _tappable ? onTap : null,
      separator: separator,
      semanticsLabel: <String?>[
        if (state == OutboxState.stuck) stuckLabel,
        stateWord,
        title,
        sentence,
        size?.spoken,
        ageLine,
      ].whereType<String>().join('. '),
    );
  }

  RowMark get _mark => switch (state) {
    OutboxState.queued => RowMark.square,
    OutboxState.sending => RowMark.dots,
    OutboxState.retrying => RowMark.circularArrow,
    OutboxState.sent => RowMark.disc,
    OutboxState.stuck => RowMark.triangle,
    OutboxState.waitingForVisit => RowMark.link,
  };

  RowMarkTone get _tone => switch (state) {
    OutboxState.stuck => RowMarkTone.severe,
    OutboxState.sent => RowMarkTone.settled,
    OutboxState.waitingForVisit => RowMarkTone.muted,
    // Queued, sending and retrying are all Oatmeal. Nothing on a queue row is
    // amber, in any state, on any skin.
    _ => RowMarkTone.neutral,
  };
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.size, required this.ageLine});

  final PayloadSize? size;
  final String ageLine;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    // A `Wrap`, not a `Row`: at 2.0× and in Afrikaans the size and the age go
    // onto two lines instead of the size being squeezed, and nothing is
    // pinned.
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: TiqSpace.s2,
      runSpacing: TiqSpace.s1,
      children: <Widget>[
        if (size != null)
          FigureSlot(
            value: size!.value,
            role: skin.text.axisLabel,
            unit: TiqUnit.worded(size!.unit),
            decimals: size!.decimals,
            color: skin.palette.ink3,
          ),
        Text(ageLine),
      ],
    );
  }
}

class _Trailing extends StatelessWidget {
  const _Trailing({required this.word, required this.tappable});

  final String word;
  final bool tappable;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        // The state word is the second channel that carries every one of the
        // six states without colour. It wraps to two lines like every other
        // label in the system — Afrikaans needs it.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 112),
          child: Text(
            word,
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: skin.text.label
                .copyWith(weight: FontWeight.w600)
                .style(color: skin.palette.ink2),
          ),
        ),
        if (tappable) ...<Widget>[
          SizedBox(height: TiqSpace.s1),
          const SoftRowChevron(),
        ],
      ],
    );
  }
}

/// A decoded byte count, split into the figure and the unit word.
///
/// Kept as a value rather than a string so the digits can go through
/// [FigureSlot] into JetBrains Mono with tabular figures and the unit can stay
/// in Onest, which is the whole point of the figure primitive. The locale's
/// decimal separator then comes from `TiqNumber` — "1,4 MB" in Afrikaans,
/// "1.4 MB" in English — rather than from a `toStringAsFixed` in a widget.
@immutable
class PayloadSize {
  const PayloadSize({
    required this.value,
    required this.unit,
    required this.decimals,
  });

  /// Bytes below 1 kB are reported as kB with no decimals: nobody makes a
  /// decision on 400 bytes, and "0,0 MB" beside a photo reads as a bug.
  factory PayloadSize.of(int bytes) {
    final safe = bytes < 0 ? 0 : bytes;
    if (safe < 1024 * 1024) {
      return PayloadSize(
        value: (safe / 1024).ceil(),
        unit: 'kB',
        decimals: 0,
      );
    }
    return PayloadSize(
      value: safe / (1024 * 1024),
      unit: 'MB',
      decimals: 1,
    );
  }

  final num value;
  final String unit;
  final int decimals;

  /// What a screen reader says. The row's own label carries this rather than
  /// letting the reader spell "1,4 MB" as punctuation.
  String get spoken => '${value.toStringAsFixed(decimals)} $unit';
}
