import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';
import '../button/icon_button.dart';
import '../button/tertiary_button.dart';
import 'chip_wrap.dart';

/// THE HEADER. No `AppBar`, no elevation, no fill that changes on scroll.
///
/// A region on the ground colour, gutter-aligned, carrying at most four things:
/// a back button, a title, a line of facts, and **exactly one** trailing icon
/// button — which is why [trailing] is typed as a single [TorchIconButton] and
/// not as a list. On a tab root that one button is the skin cycle.
///
/// ## Everything here is capped, and that is what makes the 40% rule true
///
/// unify §4: "Headers cap at 40% of the viewport, then scroll." The cap is not
/// a runtime branch that measures the header and re-parents it — it is four
/// caps that between them make the header small enough:
///
/// * the **title** wraps to two lines and then truncates;
/// * the **facts** line is capped at two lines and then tail-truncates (an
///   Afrikaans subtitle at 2.0× was measured taking 130dp of a 640dp viewport);
/// * the **flag chips** stop after two rows and hand the rest to an expander;
/// * and the header scrolls with the body, so an *expanded* chip list — the one
///   state the caps deliberately do not cover — simply scrolls.
///
/// `chrome_scale_test.dart` asserts the resulting height against
/// 40% of a 640dp viewport, in Afrikaans, at 2.0×. The ceiling is a tested
/// property rather than a runtime measurement, which means it cannot be true in
/// the widget and false on the screen.
///
/// The facts are joined by middots on screen and read as a sentence by a screen
/// reader — nobody wants to hear "middot" four times.
///
/// **Amber: none.** The header hosts a screen's chrome; it never lights
/// anything.
class TorchAppHeader extends StatefulWidget {
  const TorchAppHeader({
    super.key,
    required this.title,
    this.facts = const <String>[],
    this.back,
    this.trailing,
    this.flagChips = const <Widget>[],
    this.moreLabel = _defaultMore,
    this.fewerLabel = 'Show fewer',
  });

  final String title;

  /// "Spaza", "Tembisa Ext 12", "1,2 km", "last visit 12 Aug". Joined by
  /// middots in Night and Day; stacked in Veld, where a middot-joined line
  /// under glare is one long word.
  final List<String> facts;

  /// A real pop, never a route replacement. Its label names the destination —
  /// "Back to Today", never "Back" — which [TorchIconButton] already requires.
  final TorchIconButton? back;

  /// **Exactly one**, or none. On a tab root this is the skin cycle.
  final TorchIconButton? trailing;

  /// Flag chips. The chips themselves are the mark set's component; this is the
  /// slot they go in, and the two-row cap and the expander are the header's.
  final List<Widget> flagChips;

  /// "and 2 more".
  final String Function(int hidden) moreLabel;

  final String fewerLabel;

  static String _defaultMore(int hidden) => 'and $hidden more';

  /// The header's minimum height: 96dp, 72 on the console.
  static double minHeightFor(TiqSkin skin) =>
      skin.density == TiqDensity.console ? 72 : 96;

  @override
  State<TorchAppHeader> createState() => _TorchAppHeaderState();
}

class _TorchAppHeaderState extends State<TorchAppHeader> {
  final ValueNotifier<int> _hidden = ValueNotifier<int>(0);
  bool _expanded = false;

  @override
  void dispose() {
    _hidden.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final veld = skin.mode == SkinMode.veld;

    return Container(
      constraints: BoxConstraints(minHeight: TorchAppHeader.minHeightFor(skin)),
      decoration: veld
          ? BoxDecoration(
              // Veld replaces every hairline with a 2px border, and the one
              // place the header needs a boundary is where it meets the body.
              border: Border(
                bottom: BorderSide(
                  color: p.edgeStructure,
                  width: skin.depth.borderWidth,
                ),
              ),
            )
          : null,
      padding: EdgeInsets.only(bottom: veld ? skin.space.intraBlock : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (widget.back != null)
            // Inset −12 so the glyph, not its 48dp box, sits on the gutter.
            Transform.translate(
              offset: const Offset(-TiqSpace.s3, 0),
              child: widget.back,
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Semantics(
                  header: true,
                  // A NODE, not an annotation. Without `container` this is a
                  // bare annotation that merges into the nearest enclosing
                  // node — and the nearest enclosing node is the back button's
                  // own, because that is a non-container annotation too and
                  // the two are siblings under a plain Column. The result was
                  // one control labelled "Back to welcome\nSign in": a reader
                  // heard the way out and the name of the screen as a single
                  // button, on every Torchlight route that has a back arrow.
                  container: true,
                  child: Text(
                    widget.title,
                    style: skin.text.titleL.style(color: p.ink1),
                    // Two lines, then the tail goes. The third line is what
                    // pushes an Afrikaans header at 2.0× past the 40%
                    // ceiling — 60dp of a 640dp fold — and that arithmetic is
                    // asserted in chrome_scale_test.dart rather than trusted.
                    // (Middle truncation, which reads better on a name than a
                    // tail does, arrives with the person row in Phase 3; it is
                    // a text-layout primitive, not a header feature.)
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (widget.trailing != null) ...<Widget>[
                SizedBox(width: skin.space.intraBlock),
                widget.trailing!,
              ],
            ],
          ),
          if (widget.facts.isNotEmpty) ...<Widget>[
            const SizedBox(height: TiqSpace.s2),
            _Facts(facts: widget.facts),
          ],
          if (widget.flagChips.isNotEmpty) ...<Widget>[
            SizedBox(height: skin.space.intraBlock),
            TorchChipWrap(
              chips: widget.flagChips,
              hiddenCount: _hidden,
              maxRows: _expanded ? null : 2,
            ),
            ValueListenableBuilder<int>(
              valueListenable: _hidden,
              builder: (context, hidden, _) {
                if (hidden == 0 && !_expanded) return const SizedBox.shrink();
                // Not a fixed 44dp box: the expander is a tertiary action and
                // it already carries the 48dp target floor, which at 2.0× it
                // grows past. A pinned 44 would clip its own underline.
                return Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TorchTertiaryButton(
                    label: _expanded
                        ? widget.fewerLabel
                        : widget.moreLabel(hidden),
                    onPressed: () => setState(() => _expanded = !_expanded),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _Facts extends StatelessWidget {
  const _Facts({required this.facts});

  final List<String> facts;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    // Read as a sentence, not as punctuation.
    final spoken = facts.join(', ');

    if (skin.mode == SkinMode.veld) {
      return Semantics(
        label: spoken,
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final fact in facts)
              Text(
                fact,
                style: skin.text.body.style(color: p.ink2),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      );
    }

    return Semantics(
      label: spoken,
      excludeSemantics: true,
      child: Text(
        facts.join(' · '),
        style: skin.text.label.style(color: p.ink2),
        // Two lines, then the tail goes. A subtitle is facts, and the facts a
        // reader needs first are the ones at the front of the line.
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
