import 'package:flutter/widgets.dart';

import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/trade_iq_logo.dart';

/// THE WORDMARK — the one piece of brand the way in carries, on the splash and
/// above the sign-in form.
///
/// It is a mark and a word, not a picture behind text. The aisle footage that
/// used to sit under the sign-in form was covered by an opaque panel within
/// 90dp of the top of it, so what it actually bought was a strip of dark
/// texture beside a back arrow and a contrast question under every label
/// underneath. The splash keeps the footage, where it is the whole screen and
/// nothing is written on it; sign-in keeps the mark.
///
/// **Amber: none.** A wordmark is a word, and unify §4 lists "word" among the
/// things Burning Flame is never. The IQ is set in ink-2 against TRADE in
/// ink-1 — a weight-and-ink pairing that survives greyscale, which the old
/// blue did not.
class EntryBrand extends StatelessWidget {
  const EntryBrand({super.key, this.monogram = 46, this.compact = false});

  /// The monogram's height. The splash shows it large; sign-in shows it at the
  /// top of a form that has four more things to fit.
  final double monogram;

  /// Lays the mark and the word on one line instead of stacking them — what
  /// sign-in uses, so the form starts above the fold at 2.0×.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    // The wordmark is the one place tracking is decorative rather than a
    // legibility decision, so it is stated on the token rather than as a bare
    // TextStyle.
    final token = (compact ? skin.text.titleL : skin.text.display).copyWith(
      trackingPercent: 10,
    );
    final word = Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: 'TRADE',
            style: token.style(color: p.ink1),
          ),
          TextSpan(
            text: 'IQ',
            style: token.style(color: p.ink2),
          ),
        ],
      ),
      textAlign: compact ? TextAlign.start : TextAlign.center,
    );

    // One semantics node for the whole mark: a screen reader that read the
    // monogram's label and then the word said "TradeIQ TRADEIQ".
    //
    // `excludeSemantics` is safe here and only here: everything inside is an
    // image and two text spans, and **nothing in this subtree is tappable**.
    // The kit-wide bug this flag caused (#436 — every button announced itself
    // and did nothing when activated) was a wrapper around a gesture
    // recogniser; there is no gesture in here to swallow.
    return Semantics(
      label: 'TradeIQ',
      excludeSemantics: true,
      child: compact
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TradeIqLogo(size: monogram),
                const SizedBox(width: TiqSpace.s3),
                Flexible(child: word),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TradeIqLogo(size: monogram),
                const SizedBox(height: TiqSpace.s5),
                word,
              ],
            ),
    );
  }
}
