import 'package:flutter/material.dart' show SelectionArea;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/motion_budget.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/input/filter_chip.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../l10n/l10n.dart';
import '../data/chat_controller.dart';
import 'answer_markdown.dart';
import 'answer_motion.dart';
import 'answer_runs.dart';

/// The readability cap on a column of prose, in ems of the body role.
///
/// 32em is a measure, not a layout: the transcript column can be wider and on
/// a console usually is, but a line of body text that runs the whole of it is
/// a line nobody's eye returns from cleanly.
const double answerProseEms = 32;

/// The prose measure in logical pixels, at this skin's body size.
double answerProseWidth(TiqSkin skin) => skin.text.body.size * answerProseEms;

/// One block of prose.
///
/// **Amber: none.** Not the caret, not a list marker, not an inline emphasis.
/// The old build tinted bold runs in the headline and every list bullet with
/// the accent; a word is never a light source.
class AnswerBlockView extends StatelessWidget {
  const AnswerBlockView({
    super.key,
    required this.block,
    required this.streaming,
    this.headline = false,
    this.caret = false,
  });

  final AnswerBlock block;
  final bool streaming;

  /// Whether this is the answer's one sentence, set at `headline.answer`.
  final bool headline;

  final bool caret;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;

    Widget rich(TextStyle style, String text, {bool end = true}) => Text.rich(
      TextSpan(
        children: <InlineSpan>[
          ...answerSpans(
            answerRuns(text, streaming: streaming),
            skin: skin,
            base: style,
          ),
          if (caret && end)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: StreamingCaret(height: (style.fontSize ?? 14) + 2),
            ),
        ],
      ),
      style: style,
    );

    switch (block.kind) {
      case AnswerBlockKind.paragraph:
        return rich(
          headline
              ? skin.text.headlineAnswer.style(color: p.ink1)
              : skin.text.body.style(color: p.ink1),
          block.text,
        );
      case AnswerBlockKind.heading:
        // Level ≤3 is a real heading; deeper is a label. Both are ink, and
        // both are reachable by heading navigation.
        final style = block.level <= 3
            ? skin.text.titleM.style(color: p.ink1)
            : skin.text.label.style(color: p.ink2);
        return Semantics(header: true, child: rich(style, block.text));
      case AnswerBlockKind.bullets:
      case AnswerBlockKind.numbered:
        return _ListBlock(block: block, streaming: streaming, caret: caret);
      case AnswerBlockKind.quote:
        return AskCallout(
          kicker: block.kicker,
          body: block.text,
          streaming: streaming,
          caret: caret,
        );
      case AnswerBlockKind.code:
        // Horizontal scroll inside its own container: the page body never
        // scrolls sideways, at any width or text scale.
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(TiqSpace.s3),
          decoration: BoxDecoration(
            color: p.well,
            borderRadius: BorderRadius.circular(skin.radii.control),
            border: skin.mode == SkinMode.veld
                ? Border.all(color: p.ink1, width: skin.depth.borderWidth)
                : null,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: rich(skin.text.monoIdent.style(color: p.ink1), block.text),
          ),
        );
    }
  }
}

/// A bulleted or numbered list.
///
/// The marker is a **4dp filled square** in ink-3 — not a dot, not an emoji,
/// never an icon, and never the accent. A numbered list sets its number in
/// `mono.ident`, because a list index is a figure.
class _ListBlock extends StatelessWidget {
  const _ListBlock({
    required this.block,
    required this.streaming,
    required this.caret,
  });

  final AnswerBlock block;
  final bool streaming;
  final bool caret;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final numbered = block.kind == AnswerBlockKind.numbered;
    final body = skin.text.body.style(color: p.ink1);
    // The marker column scales with the text, because at 2.0× a fixed 16dp
    // gutter puts a two-digit number under the first word.
    final scale = MediaQuery.textScalerOf(context);
    final markerWidth = scale.scale(numbered ? 24 : 16);
    final square = scale.scale(4).clamp(4.0, 8.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < block.items.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : TiqSpace.s1 + 1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: markerWidth,
                  child: numbered
                      ? Text(
                          '${i + 1}.',
                          style: skin.text.monoIdent.style(color: p.ink3),
                        )
                      : Padding(
                          padding: EdgeInsets.only(
                            top: scale.scale(body.fontSize ?? 14) * 0.55,
                          ),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: SizedBox.square(
                              dimension: square,
                              child: ColoredBox(color: p.ink3),
                            ),
                          ),
                        ),
                ),
                Expanded(
                  child: AnswerBlockView(
                    block: AnswerBlock.paragraph(block.items[i]),
                    streaming: streaming,
                    caret: caret && i == block.items.length - 1,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// "WHAT EXPLAINS IT" — the one cause the answer turns on.
///
/// **No container at all.** The old build drew this as a warn-washed box with
/// a `!` tile in it, which is a colour that reads as a severity on a block
/// that is not one. What sets it apart is the [SectionRule] and the 24dp of
/// clear space either side of it — structure, which survives greyscale, sun, a
/// printed export and a screen reader identically.
///
/// Sentence case, at `title.m`, per unify §1.17: every screen-level section
/// marker on this surface is the knocked-out rule, and the uppercase eyebrow
/// is legal in three places and this is not one of them.
class AskCallout extends StatelessWidget {
  const AskCallout({
    super.key,
    required this.body,
    this.kicker,
    this.streaming = false,
    this.caret = false,
  });

  /// The model's own bold first line, when it wrote one. It replaces the
  /// standing name — still sentence case, still on the rule.
  final String? kicker;

  final String body;
  final bool streaming;
  final bool caret;

  /// The longest kicker that goes on the rule. Past this the standing name is
  /// used, because a rule is a marker and a marker is not a sentence.
  static const int kickerLimit = 32;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final own = kicker?.trim();
    final name = own != null && own.isNotEmpty && own.length <= kickerLimit
        ? own
        : context.l10n.askCallout;

    return Column(
      key: const ValueKey<String>('ask-callout'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SectionRule(name),
        SizedBox(height: skin.space.intraBlock),
        if (body.isNotEmpty || caret)
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: answerProseWidth(skin)),
            child: AnswerBlockView(
              block: AnswerBlock.paragraph(body),
              streaming: streaming,
              caret: caret,
            ),
          ),
      ],
    );
  }
}

/// Three next questions, one tap each — and never the answer, so never amber.
///
/// They are the **filter chip** component (unify §1.6): one selected
/// vocabulary across chips and choices, and a chip that is never selected
/// here. Three amber chips would be the repeated fill the law bans outright.
class FollowUpChips extends ConsumerWidget {
  const FollowUpChips({
    super.key,
    required this.questions,
    this.enabled = true,
  });

  final List<String> questions;

  /// False while a turn streams or while offline. A disabled chip stays
  /// visible: hiding it would hide the fact that there is something to ask.
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sending = ref.watch(chatControllerProvider.select((s) => s.sending));
    final live = enabled && !sending;
    return Wrap(
      spacing: TiqSpace.s2,
      runSpacing: TiqSpace.s2,
      children: <Widget>[
        for (final question in questions.take(maxFollowUps))
          TorchFilterChip(
            key: ValueKey<String>('follow-up-$question'),
            label: question,
            selected: false,
            // The corner arrow says "this asks something", and it is the
            // mark's own silhouette rather than a tinted glyph.
            semanticsLabel: live
                ? l10n.askFollowUpSemantic(question)
                : '${l10n.askFollowUpSemantic(question)}, '
                      '${l10n.askFollowUpDisabled}',
            onSelected: live
                ? () => ref.read(chatControllerProvider.notifier).send(question)
                : null,
          ),
      ],
    );
  }
}

/// The text caret at the end of an answer still being written.
///
/// A 2dp ink-2 bar, blinking at 1000ms, inside its own `RepaintBoundary` so a
/// blink cannot repaint a forty-block answer. In Veld it is 3dp, solid
/// veld-ink, and it does **not** blink — it is simply present until the turn
/// ends, because motion is off out there and a caret is not information.
class StreamingCaret extends StatefulWidget {
  const StreamingCaret({super.key, this.height = 16});

  final double height;

  @override
  State<StreamingCaret> createState() => _StreamingCaretState();
}

class _StreamingCaretState extends State<StreamingCaret>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionBudget.of(context).still) {
      _blink.stop();
      _blink.value = 0;
    } else if (!_blink.isAnimating) {
      _blink.repeat();
    }
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final veld = skin.mode == SkinMode.veld;
    final bar = Container(
      key: const ValueKey<String>('streaming-caret'),
      width: veld ? 3 : 2,
      height: veld ? widget.height + 4 : widget.height,
      margin: const EdgeInsets.only(left: 2),
      color: veld ? skin.palette.ink1 : skin.palette.ink2,
    );
    // ExcludeSemantics: the caret is decoration. That the answer is still
    // being written is the rail's live region's job, and saying it twice is
    // how a screen reader user learns to ignore both.
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: MotionBudget.of(context).still
            ? bar
            : AnimatedBuilder(
                animation: _blink,
                // steps(1): fully on for the first half, off for the second.
                builder: (context, child) =>
                    Opacity(opacity: _blink.value < 0.5 ? 1 : 0, child: child),
                child: bar,
              ),
      ),
    );
  }
}

/// The whole prose of a rich answer, around the artifacts it drew.
///
/// Order: the **headline** first and it never moves — artifacts mount *below*
/// it, so a landing chart cannot push the sentence the manager is reading —
/// then the panel, then everything else the model wrote, then the notice, then
/// the follow-ups.
class RichAnswer extends StatelessWidget {
  const RichAnswer({
    super.key,
    required this.parsed,
    required this.streaming,
    required this.artifacts,
    required this.animate,
    this.trailing = const <Widget>[],
    this.followUpsEnabled = true,
  });

  final ParsedAnswer parsed;
  final bool streaming;

  /// Already-built artifact blocks, in the order the panel holds them.
  final List<Widget> artifacts;

  /// Whether blocks slide in as they mount (a live turn).
  final bool animate;

  /// The incomplete notice and the outside-data band, between the prose and
  /// the follow-ups — the order in which they are useful.
  final List<Widget> trailing;

  final bool followUpsEnabled;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final blocks = parsed.blocks;
    final hasHeadline = parsed.headline != null;
    final lead = hasHeadline ? blocks.sublist(0, 1) : blocks;
    final rest = hasHeadline ? blocks.sublist(1) : const <AnswerBlock>[];
    final caretOnLead = streaming && rest.isEmpty;
    final caretOnRest = streaming && rest.isNotEmpty;

    Widget prose(List<AnswerBlock> group, int offset, {required bool caret}) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: answerProseWidth(skin)),
        child: SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (var i = 0; i < group.length; i++) ...<Widget>[
                if (i > 0) SizedBox(height: _gapBefore(group[i], skin)),
                Arrive(
                  key: ValueKey<String>(
                    'block-${offset + i}-${group[i].kind.name}',
                  ),
                  enabled: animate,
                  // Words are legible the frame they land; only the block's
                  // place eases in.
                  fromOpacity: 0.35,
                  offset: 8,
                  duration: const Duration(milliseconds: 320),
                  child: AnswerBlockView(
                    block: group[i],
                    streaming: streaming,
                    headline: hasHeadline && offset + i == 0,
                    caret: caret && i == group.length - 1,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final children = <Widget>[
      if (lead.isNotEmpty) prose(lead, 0, caret: caretOnLead),
      for (final card in artifacts) card,
      if (rest.isNotEmpty) prose(rest, 1, caret: caretOnRest),
      ...trailing,
      if (parsed.followUps.isNotEmpty)
        Arrive(
          key: const ValueKey<String>('followups'),
          enabled: animate,
          child: FollowUpChips(
            questions: parsed.followUps,
            enabled: followUpsEnabled,
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < children.length; i++) ...<Widget>[
          if (i > 0) SizedBox(height: skin.space.blockGap),
          children[i],
        ],
      ],
    );
  }

  static double _gapBefore(AnswerBlock block, TiqSkin skin) =>
      switch (block.kind) {
        // 16dp before a heading, 24 before the callout, 8 between paragraphs.
        AnswerBlockKind.heading => TiqSpace.s4,
        AnswerBlockKind.quote => skin.space.blockGap,
        _ => TiqSpace.s2,
      };
}
