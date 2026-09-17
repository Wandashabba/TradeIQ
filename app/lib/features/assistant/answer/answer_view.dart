import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/lumen_palette.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/glass.dart';
import '../data/chat_controller.dart';
import 'answer_markdown.dart';
import 'answer_motion.dart';

/// The inks and type an answer is set in, read once per build.
class AnswerInks {
  AnswerInks(BuildContext context)
      : glass = context.colors.glass,
        ink = context.colors.glass ? context.lumen.ink : context.colors.ink1,
        muted =
            context.colors.glass ? context.lumen.inkMuted : context.colors.ink3,
        accent = context.colors.glass
            ? context.lumen.accentInk
            : context.colors.brand,
        warn = context.colors.warn,
        codeWash =
            context.colors.glass ? context.lumen.track : context.colors.surface2;

  final bool glass;
  final Color ink;
  final Color muted;
  final Color accent;
  final Color warn;
  final Color codeWash;

  TextStyle get body => TextStyle(fontSize: 14, height: 1.55, color: ink);

  /// The one sentence a manager should be able to stop at.
  TextStyle get headline => TextStyle(
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.25,
        color: ink,
      );
}

/// Inline runs as spans. [boldColor] lets the headline lift its emphasis into
/// the accent, as the mockup does for the fact the sentence turns on.
List<InlineSpan> inlineSpans(
  String text, {
  required bool streaming,
  required TextStyle base,
  required AnswerInks inks,
  Color? boldColor,
}) {
  return [
    for (final run in parseInline(text, streaming: streaming))
      TextSpan(
        text: run.text,
        style: base.copyWith(
          fontWeight: run.bold
              ? (boldColor != null ? FontWeight.w700 : FontWeight.w600)
              : null,
          fontStyle: run.italic ? FontStyle.italic : null,
          color: run.bold && boldColor != null ? boldColor : null,
          fontFamily: run.code ? LumenGlass.mono : null,
          fontSize: run.code ? (base.fontSize ?? 14) * 0.9 : null,
          backgroundColor: run.code ? inks.codeWash : null,
        ),
      ),
  ];
}

const _caretSpan = WidgetSpan(
  alignment: PlaceholderAlignment.middle,
  child: StreamingCaret(),
);

/// One block of prose. [caret] appends the streaming caret to its last line.
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
  final bool headline;
  final bool caret;

  @override
  Widget build(BuildContext context) {
    final inks = AnswerInks(context);

    Text rich(String text, TextStyle style, {Color? boldColor, bool end = true}) =>
        Text.rich(
          TextSpan(children: [
            ...inlineSpans(
              text,
              streaming: streaming,
              base: style,
              inks: inks,
              boldColor: boldColor,
            ),
            if (caret && end) _caretSpan,
          ]),
          style: style,
        );

    switch (block.kind) {
      case AnswerBlockKind.paragraph:
        return headline
            ? rich(block.text, inks.headline, boldColor: inks.accent)
            : rich(block.text, inks.body);
      case AnswerBlockKind.heading:
        final style = TextStyle(
          fontSize: block.level <= 3 ? 15 : 13.5,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: inks.ink,
        );
        return Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Semantics(header: true, child: rich(block.text, style)),
        );
      case AnswerBlockKind.bullets:
      case AnswerBlockKind.numbered:
        final numbered = block.kind == AnswerBlockKind.numbered;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < block.items.length; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: numbered ? 22 : 16,
                      child: Text(
                        numbered ? '${i + 1}.' : '•',
                        style: numbered
                            ? inks.body.copyWith(
                                fontFamily: LumenGlass.mono,
                                fontSize: 12.5,
                                color: inks.muted,
                              )
                            : inks.body.copyWith(color: inks.accent),
                      ),
                    ),
                    Expanded(
                      child: rich(
                        block.items[i],
                        inks.body,
                        end: i == block.items.length - 1,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      case AnswerBlockKind.quote:
        return InsightCallout(
          kicker: block.kicker,
          body: block.text,
          streaming: streaming,
          caret: caret,
        );
      case AnswerBlockKind.code:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: inks.codeWash,
            borderRadius: BorderRadius.circular(LumenGlass.radiusChip),
          ),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: block.text),
              if (caret) _caretSpan,
            ]),
            style: LumenGlass.figure(
              size: 12.5,
              color: inks.ink,
              weight: FontWeight.w400,
            ).copyWith(height: 1.45),
          ),
        );
    }
  }
}

/// A blockquote, drawn as the answer's insight: the cause named with its
/// figures, set apart so it cannot be skimmed past.
class InsightCallout extends StatelessWidget {
  const InsightCallout({
    super.key,
    required this.body,
    this.kicker,
    this.streaming = false,
    this.caret = false,
  });

  final String? kicker;
  final String body;
  final bool streaming;
  final bool caret;

  @override
  Widget build(BuildContext context) {
    final inks = AnswerInks(context);
    final warn = inks.warn;
    final bodyStyle = inks.body.copyWith(fontSize: 13.5);
    final colors = context.colors;
    // The wash is composited over the tile rather than laid on it translucent,
    // so the words sit on an opaque colour whatever is behind the transcript.
    final tile = inks.glass ? context.lumen.tileFill : colors.surface1;

    return Container(
      key: const ValueKey('insight-callout'),
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(warn.withValues(alpha: 0.11), tile),
        border: Border.all(color: warn.withValues(alpha: 0.30)),
        borderRadius: BorderRadius.circular(LumenGlass.radiusControl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: warn.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '!',
                style: LumenGlass.figure(
                  size: 14,
                  color: warn,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (kicker != null && kicker!.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: body.isEmpty ? 0 : 5),
                    child: Text(
                      kicker!.toUpperCase(),
                      key: const ValueKey('insight-callout-kicker'),
                      style: LumenGlass.kickerStyle(color: warn, size: 11)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                if (body.isNotEmpty || caret)
                  Text.rich(
                    TextSpan(children: [
                      ...inlineSpans(
                        body,
                        streaming: streaming,
                        base: bodyStyle,
                        inks: inks,
                      ),
                      if (caret) _caretSpan,
                    ]),
                    style: bodyStyle,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The follow-up questions, one tap each.
class FollowUpChips extends ConsumerWidget {
  const FollowUpChips({super.key, required this.questions});

  final List<String> questions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sending = ref.watch(chatControllerProvider.select((s) => s.sending));
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final question in questions.take(maxFollowUps))
          _FollowUpChip(
            question: question,
            onTap: sending
                ? null
                : () => ref.read(chatControllerProvider.notifier).send(question),
          ),
      ],
    );
  }
}

class _FollowUpChip extends StatelessWidget {
  const _FollowUpChip({required this.question, required this.onTap});

  final String question;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final glass = colors.glass;
    final lumen = context.lumen;
    final enabled = onTap != null;
    final label = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(
            text: '↳ ',
            style: TextStyle(color: glass ? lumen.accentSolid : colors.brand),
          ),
          TextSpan(text: question),
        ]),
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: glass ? lumen.ink : colors.ink2,
        ),
      ),
    );
    final tappable = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: label,
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Ask: $question',
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.6,
        child: glass
            ? GlassPane(
                kind: GlassKind.pill,
                radius: 999,
                shadow: false,
                child: tappable,
              )
            : DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: colors.line),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: tappable,
              ),
      ),
    );
  }
}

/// The whole prose of a rich answer, around the artifacts it drew.
///
/// Order follows the approved design: the working steps, then the **headline**
/// (the first paragraph), then the figures the turn drew, then everything else
/// the model wrote — callout, headings, lists — and finally the follow-ups.
class RichAnswer extends StatelessWidget {
  const RichAnswer({
    super.key,
    required this.parsed,
    required this.streaming,
    required this.artifacts,
    required this.animate,
  });

  final ParsedAnswer parsed;
  final bool streaming;

  /// Already-built artifact cards, in arrival order.
  final List<Widget> artifacts;

  /// Whether blocks slide in as they mount (a live turn).
  final bool animate;

  static const gap = 12.0;
  static const maxProseWidth = 680.0;

  @override
  Widget build(BuildContext context) {
    final blocks = parsed.blocks;
    final hasHeadline = parsed.headline != null;
    final lead = hasHeadline ? blocks.sublist(0, 1) : blocks;
    final rest = hasHeadline ? blocks.sublist(1) : const <AnswerBlock>[];
    // The caret rides the last words written, wherever they sit.
    final caretOnLead = streaming && rest.isEmpty;
    final caretOnRest = streaming && rest.isNotEmpty;

    Widget prose(List<AnswerBlock> group, int offset, {required bool caret}) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxProseWidth),
        child: SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < group.length; i++) ...[
                if (i > 0) SizedBox(height: _gapBefore(group[i])),
                Arrive(
                  key: ValueKey('block-${offset + i}-${group[i].kind.name}'),
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
      if (parsed.followUps.isNotEmpty)
        Arrive(
          key: const ValueKey('followups'),
          enabled: animate,
          child: FollowUpChips(questions: parsed.followUps),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: gap),
          children[i],
        ],
      ],
    );
  }

  static double _gapBefore(AnswerBlock block) => switch (block.kind) {
        AnswerBlockKind.heading => 14,
        AnswerBlockKind.quote => 12,
        _ => 8,
      };
}
