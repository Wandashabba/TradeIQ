import 'package:flutter/widgets.dart';

import '../../design/figure_slot.dart';
import '../../theme/torchlight/tiq_skin.dart';

/// THE CONSOLE'S ONLY SECTION MARKER.
///
/// A rule running gutter to gutter with the section's name sitting on it,
/// left, knocked out 12dp either side. No eyebrow, no uppercase kicker, no
/// number badge, no emoji, and **never amber** — it replaced an amber section
/// marker and a numbered eyebrow precisely so it could not become a repeated
/// accent.
///
/// Sentence case, always. `title.m` at 16/600, because the words carry the
/// meaning and the line is there to say where the section starts.
///
/// ```dart
/// SectionRule('Needs a decision', count: 5)
/// SectionRule('Today’s field')
/// SectionRule(
///   'Needs a decision',
///   count: 12,
///   action: SectionRuleAction('See all', onTap: () => context.push('/work')),
/// )
/// ```
///
/// ## Why the rule is `hairline` in Night and `edgeStructure` in Day
///
/// Night's hairline is #3A4B60 at 2.14:1 — visible on a dark ground, and the
/// text carries the meaning anyway. Day's hairline is 1.18:1, which is
/// nothing. Since this is the console's only full-width line, raising it in
/// Day inverts no hierarchy: there is nothing above it to invert.
class SectionRule extends StatelessWidget {
  const SectionRule(
    this.name, {
    super.key,
    this.count,
    this.action,
    this.emptyLine,
  });

  /// Sentence case. Asserted, because "NEEDS A DECISION" is the thing this
  /// component was built to replace.
  final String name;

  /// Follows the name in `figure.s` tabular mono `ink3`, inside the same
  /// knock-out: `Needs a decision 5`.
  final int? count;

  /// A ghost text action at the right end, knocked out 12dp before it.
  final SectionRuleAction? action;

  /// One `body` `ink2` line beneath, for a section that is empty. The rule and
  /// the name still render: a section that vanishes when empty makes a manager
  /// think the feature is gone.
  final String? emptyLine;

  /// The knock-out either side of the text. 16 in Veld, where the border is
  /// 2px and a 12dp gap around a 2px line reads as a join.
  static double knockOutFor(TiqSkin skin) =>
      skin.density == TiqDensity.veld ? TiqSpace.s4 : TiqSpace.s3;

  /// The short stub of rule before the name, so the line reads as *stopping
  /// and restarting* around the words rather than beginning after them.
  static const double leadIn = TiqSpace.s3;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    assert(
      name.toUpperCase() != name || name.length < 3,
      'SectionRule: "$name" is uppercase. The console\'s section marker is '
      'sentence case at title.m — the uppercase kicker is the thing this '
      'component replaced.',
    );

    final ruleColour = skin.brightness == Brightness.dark
        ? skin.palette.hairline
        : skin.palette.edgeStructure;
    final ruleWidth = skin.depth.borderWidth;
    final knockOut = knockOutFor(skin);

    final label = _Label(name: name, count: count);

    return Semantics(
      header: true,
      label: count == null ? name : '$name, $count',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          LayoutBuilder(
            builder: (context, constraints) {
              final wrapped = _labelWraps(context, skin, constraints.maxWidth);
              // At 2.0x the name wraps and the rule drops BELOW the text block
              // rather than running through it. Afrikaans wraps the same way,
              // and for the same reason: a rule crossing two lines of type is
              // a strike-through.
              if (wrapped) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    label,
                    const SizedBox(height: TiqSpace.s2),
                    _Rule(colour: ruleColour, thickness: ruleWidth),
                    if (action != null) ...<Widget>[
                      const SizedBox(height: TiqSpace.s2),
                      action!,
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  SizedBox(
                    width: leadIn,
                    child: _Rule(colour: ruleColour, thickness: ruleWidth),
                  ),
                  SizedBox(width: knockOut),
                  Flexible(child: label),
                  SizedBox(width: knockOut),
                  Expanded(
                    child: _Rule(colour: ruleColour, thickness: ruleWidth),
                  ),
                  if (action != null) ...<Widget>[
                    SizedBox(width: knockOut),
                    action!,
                  ],
                ],
              );
            },
          ),
          if (emptyLine != null) ...<Widget>[
            const SizedBox(height: TiqSpace.s3),
            Text(
              emptyLine!,
              style: skin.text.body.style(color: skin.palette.ink2),
            ),
          ],
        ],
      ),
    );
  }

  /// Measure, do not guess at a text-scale threshold. The question is whether
  /// the name plus its count plus the knock-outs still leave a usable run of
  /// rule; below that the inline form is a label with a dash after it.
  bool _labelWraps(BuildContext context, TiqSkin skin, double maxWidth) {
    if (!maxWidth.isFinite) return false;
    final scaler =
        MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    final painter = TextPainter(
      text: TextSpan(
        text: count == null ? name : '$name $count',
        style: skin.text.titleM.style(color: skin.palette.ink1),
      ),
      textDirection: Directionality.of(context),
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    final knockOut = knockOutFor(skin);
    // MEASURE the action too, at the live scaler and in the caller's own
    // language. A fixed reservation was the bug: "Add a scheme" at 2.0x is
    // roughly three times TiqSpace.s11, so a short section name never wrapped,
    // the inline Row kept the action, and the action ran 168dp off the right
    // of a 360dp phone. A constant cannot know how long a verb is in
    // Afrikaans.
    var actionRoom = 0.0;
    final verb = action?.label;
    if (verb != null) {
      final actionPainter = TextPainter(
        text: TextSpan(
          text: verb,
          style: skin.text.label.style(color: skin.palette.ink2),
        ),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      actionRoom = actionPainter.width + knockOut;
      actionPainter.dispose();
    }
    // The rule needs a visible run after the text or it is not a rule.
    return width + leadIn + knockOut * 2 + actionRoom + TiqSpace.s7 > maxWidth;
  }
}

/// The ghost text action a section rule may carry at its right end.
class SectionRuleAction extends StatelessWidget {
  const SectionRuleAction(this.label, {super.key, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: skin.space.tapTarget),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              label,
              style: skin.text.label.style(color: skin.palette.ink2),
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.name, required this.count});

  final String name;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Flexible(
          child: Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: skin.text.titleM.style(color: skin.palette.ink1),
          ),
        ),
        if (count != null) ...<Widget>[
          const SizedBox(width: TiqSpace.s2),
          // Tabular mono, like every other figure in the app — a count in the
          // prose face beside a column of mono numbers is the inconsistency
          // FigureSlot exists to end.
          FigureSlot(
            value: count,
            role: skin.text.figureS,
            color: skin.palette.ink3,
          ),
        ],
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.colour, required this.thickness});

  final Color colour;
  final double thickness;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: thickness,
    child: ColoredBox(color: colour),
  );
}
