import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';

/// The uppercase kicker: 11/700, tracking **+4%**, wrapping to two lines.
///
/// ## Where it is legal
///
/// Three places, and unify §1.17 closes the list: a stat tile's label, a
/// hero or plate figure's label, and a block label inside a panel ("WORST
/// FIRST"). **Every screen-level section marker is something else** — the
/// knocked-out rule at `title.m` in sentence case. "WHAT EXPLAINS IT",
/// "SOURCES" and "TRY ONE OF THESE" were eyebrows and are not any more.
///
/// ## Why the tracking moved
///
/// +8% to +4% (unify §1.4). Uppercase plus tracking is the most space-hungry
/// setting in the system, and the eyebrow is a stat tile's only label channel.
/// At +8% the Afrikaans "BESKIKBAARHEID OP RAK" took a third line on a 360dp
/// phone at 1.0× — the setting that was supposed to make the label compact was
/// costing the tile 14dp of fold.
///
/// ## Why it uppercases here and not at the call site
///
/// So that the *string* stays sentence case. `text.toUpperCase()` at the call
/// site puts the uppercase in the data, where it reaches a screen reader (which
/// spells it out), a search index and the PDF exporter. Here it is a
/// presentation of a sentence-case string, and [Semantics] below hands the
/// original to anything that reads.
class Eyebrow extends StatelessWidget {
  const Eyebrow(
    this.text, {
    super.key,
    this.color,
    this.maxLines = 2,
    this.textAlign = TextAlign.start,
  });

  /// Sentence case, in the caller's language. Uppercased for display only.
  final String text;

  /// Defaults to ink-2 — the label is secondary text, and it stays at full
  /// ink in every state of the tile including no-data, because the label is
  /// still true when the figure is not.
  final Color? color;

  /// Two. A third line is the signal that the string is too long, not that the
  /// tile should grow again.
  final int maxLines;

  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Text(
        text.toUpperCase(),
        style: skin.text.eyebrow.style(color: color ?? skin.palette.ink2),
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
      ),
    );
  }
}
