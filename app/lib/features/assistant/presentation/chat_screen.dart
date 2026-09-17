import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/lumen_palette.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../answer/answer_markdown.dart';
import '../answer/answer_motion.dart';
import '../answer/answer_view.dart';
import '../answer/web_sources.dart';
import '../answer/working_steps.dart';
import '../data/chat_controller.dart';
import '../view_specs/view_spec_registry.dart';

/// The conversational surface.
///
/// Phase 0 is **read-only and manager-only**: it answers questions about sales,
/// stock, visibility, competition and execution, and it cannot change anything.
/// The empty state says so in as many words, because an assistant that silently
/// declines the first thing you ask it teaches you not to ask again.
class AssistantChatScreen extends ConsumerStatefulWidget {
  const AssistantChatScreen({super.key});

  @override
  ConsumerState<AssistantChatScreen> createState() => _AssistantChatScreenState();
}

class _AssistantChatScreenState extends ConsumerState<AssistantChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    ref.read(chatControllerProvider.notifier).send(text);
    _scrollToEnd();
  }

  void _scrollToEnd() {
    // After the frame, so the list has laid out the message we just added.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider);
    // Tokens arrive many times a second; following them keeps the newest text
    // on screen without the user chasing it.
    ref.listen(chatControllerProvider, (_, _) => _scrollToEnd());

    return ManagerScaffold(
      title: 'Ask TradeIQ',
      body: Column(
        children: [
          Expanded(
            child: state.messages.isEmpty
                ? const _EmptyState()
                : ListView.separated(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: state.messages.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, i) =>
                        _MessageView(message: state.messages[i]),
                  ),
          ),
          _Composer(
            controller: _input,
            sending: state.sending,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  /// Suggestions are the four pillars plus execution, in the manager's own
  /// words. They are not decoration: a blank chat box is the hardest possible
  /// first move, and these are what the tools are actually good at.
  static const _examples = [
    'How has my team been performing this month?',
    'Which outlets keep running out of stock?',
    'What is our share of shelf year to date?',
    'Show me any visits that look suspicious.',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Ask about sales, stock, visibility or competition',
              textAlign: TextAlign.center,
              style: colors.glass
                  ? LumenGlass.title(size: 20, color: context.lumen.ink)
                  : TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.ink1,
                    ),
            ),
            SizedBox(height: colors.glass ? 8 : 6),
            Text(
              'I can read your data and explain it. I cannot change anything yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: colors.glass ? 12.5 : 12,
                color: colors.glass ? context.lumen.inkMuted : colors.ink3,
              ),
            ),
            const SizedBox(height: 20),
            for (final example in _examples)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ExampleChip(text: example),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExampleChip extends ConsumerWidget {
  const _ExampleChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    void ask() => ref.read(chatControllerProvider.notifier).send(text);

    if (colors.glass) {
      // A glass pill. The ink sits on a transparent Material inside the pane,
      // so the press is painted over the glass rather than buried beneath it.
      return GlassPane(
        kind: GlassKind.pill,
        radius: 999,
        shadow: false,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: ask,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                text,
                style: TextStyle(fontSize: 12.5, color: context.lumen.ink),
              ),
            ),
          ),
        ),
      );
    }

    return InkWell(
      onTap: ask,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          border: Border.all(color: colors.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 12.5, color: colors.ink2),
        ),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (message.role == ChatRole.user) {
      return colors.glass ? _glassUser(context.lumen) : _flatUser(colors);
    }

    // Parsed on every build: tokens arrive many times a second, and the parse
    // is a single linear pass over one answer's worth of text.
    final parsed = parseAnswer(message.text, streaming: message.streaming);
    // Blocks slide in only while the turn is live. A finished answer rebuilt
    // by scrolling it back into view is simply there.
    final animate = message.streaming;

    final steps = message.tools.isEmpty
        ? null
        : ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: RichAnswer.maxProseWidth),
            child: WorkingSteps(
              tools: message.tools,
              streaming: message.streaming,
              animate: animate,
            ),
          );

    final artifacts = [
      for (final artifact in arrangeAnswerArtifacts(message.artifacts))
        Arrive(
          key: ValueKey('artifact-${artifact.id}'),
          enabled: animate,
          // Expandable here and only here: the inline card is deliberately
          // impoverished, and Expand is how the filter controls and the table
          // twin are reached without putting a date picker in every chat
          // bubble.
          child: ArtifactView(artifact: artifact, expandable: true),
        ),
    ];

    // **A reply that used none of the answer conventions renders exactly as
    // replies always have**: one selectable run of text, then its artifacts.
    // Only a reply that wrote markdown or follow-ups takes the rich layout.
    final rich = message.error == null &&
        (parsed.hasMarkdown || parsed.followUps.isNotEmpty);

    final Widget body;
    if (rich) {
      body = RichAnswer(
        parsed: parsed,
        streaming: message.streaming,
        artifacts: artifacts,
        animate: animate,
      );
    } else {
      body = colors.glass
          ? _glassPlain(context.lumen, artifacts)
          : _flatPlain(colors, artifacts);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The steps sit above the answer: their whole job is to explain a
        // pause before there is any text to show, and afterwards to say what
        // the answer was built from.
        if (steps != null) ...[steps, const SizedBox(height: 10)],
        body,
        // Where the answer's outside facts came from, after the answer — a
        // turn that errored has no answer to cite.
        if (message.sources.isNotEmpty && message.error == null) ...[
          const SizedBox(height: 10),
          Arrive(
            key: const ValueKey('web-sources-arrive'),
            enabled: animate,
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: RichAnswer.maxProseWidth),
              child: WebSources(sources: message.sources),
            ),
          ),
        ],
      ],
    );
  }

  Widget _flatUser(TiqColors colors) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surface2,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message.text,
          style: TextStyle(fontSize: 13.5, height: 1.4, color: colors.ink1),
        ),
      ),
    );
  }

  /// A plain reply's text. Selectable once it is finished; while it streams,
  /// the same text and style carry the caret at their end.
  Widget _plainText(TextStyle style) {
    if (!message.streaming) return SelectableText(message.text, style: style);
    return SelectionArea(
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: message.text),
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: StreamingCaret(),
          ),
        ]),
        style: style,
      ),
    );
  }

  Widget _flatPlain(TiqColors colors, List<Widget> artifacts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.error != null)
          _ErrorNote(message: message.error!)
        else ...[
          if (message.text.isNotEmpty)
            _plainText(
              TextStyle(fontSize: 13.5, height: 1.5, color: colors.ink1),
            ),
          // A turn that has called a tool but produced no text yet: without
          // this the screen looks frozen between tool_end and the first token.
          if (message.text.isEmpty && message.streaming)
            const _ThinkingDots(),
        ],
        for (final artifact in artifacts) ...[
          const SizedBox(height: 10),
          artifact,
        ],
      ],
    );
  }

  /// Lumen Glass: the manager's turn is the action glass in its own ink; the
  /// assistant's is a tile — a list item, so unblurred. Anything the turn drew
  /// lands below its bubble as its own panel, never a pane inside a pane.
  Widget _glassUser(LumenPalette lumen) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: GlassPane(
          kind: GlassKind.action,
          radius: LumenGlass.radiusCard,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            message.text,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: lumen.actionInk,
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassPlain(LumenPalette lumen, List<Widget> artifacts) {
    final thinking = message.text.isEmpty && message.streaming;
    final answer = message.error != null || message.text.isNotEmpty || thinking;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A turn that is only an artifact gets no empty bubble above it.
        if (answer)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: GlassPane(
              kind: GlassKind.tile,
              blur: false,
              radius: LumenGlass.radiusCard,
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.error != null)
                    _ErrorNote(message: message.error!)
                  else ...[
                    if (message.text.isNotEmpty)
                      _plainText(
                        TextStyle(fontSize: 13.5, height: 1.5, color: lumen.ink),
                      ),
                    if (thinking) const _ThinkingDots(),
                  ],
                ],
              ),
            ),
          ),
        for (final artifact in artifacts) ...[
          const SizedBox(height: 10),
          artifact,
        ],
      ],
    );
  }
}

class _ThinkingDots extends StatelessWidget {
  const _ThinkingDots();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: context.colors.ink4,
        ),
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline, size: 15, color: colors.critText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            // Rendered verbatim: the server guarantees this string is
            // user-safe, and never a stack trace or a vendor error.
            message,
            style: TextStyle(fontSize: 12.5, height: 1.4, color: colors.critText),
          ),
        ),
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (colors.glass) return _glass(context.lumen);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !sending,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              style: TextStyle(fontSize: 13.5, color: colors.ink1),
              decoration: InputDecoration(
                hintText: 'Ask about your team, stock, shelf or competitors',
                hintStyle: TextStyle(fontSize: 13, color: colors.ink4),
                filled: true,
                fillColor: colors.surface2,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colors.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colors.line),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: sending ? null : onSend,
            icon: const Icon(Icons.arrow_upward),
            tooltip: 'Send',
            style: IconButton.styleFrom(
              backgroundColor: sending ? colors.surface3 : colors.brand,
              foregroundColor: sending ? colors.ink4 : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The composer as a floating glass bar: the field is borderless inside it,
  /// and Send is the action pill. Sending dims the pill but keeps its arrow in
  /// the action ink, so a blocked send still reads.
  Widget _glass(LumenPalette lumen) {
    const none = InputBorder.none;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: GlassPane(
        kind: GlassKind.bar,
        radius: LumenGlass.radiusHero,
        padding: const EdgeInsets.all(6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !sending,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: TextStyle(fontSize: 13.5, color: lumen.ink),
                decoration: InputDecoration(
                  hintText: 'Ask about your team, stock, shelf or competitors',
                  // inkMuted, not ink4: a hint is words, and ink4 is for marks.
                  hintStyle: TextStyle(fontSize: 13, color: lumen.inkMuted),
                  filled: false,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: none,
                  enabledBorder: none,
                  focusedBorder: none,
                  disabledBorder: none,
                ),
              ),
            ),
            const SizedBox(width: 6),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(LumenGlass.radiusButton),
                boxShadow: sending
                    ? null
                    : [
                        BoxShadow(
                          color: lumen.shadow,
                          blurRadius: 26,
                          offset: const Offset(0, 12),
                        ),
                      ],
              ),
              child: IconButton(
                onPressed: sending ? null : onSend,
                icon: const Icon(Icons.arrow_upward),
                tooltip: 'Send',
                style: IconButton.styleFrom(
                  backgroundColor: lumen.actionFill,
                  disabledBackgroundColor: lumen.actionDisabled,
                  foregroundColor: lumen.actionInk,
                  disabledForegroundColor: lumen.actionInk,
                  side: BorderSide(color: lumen.actionRim),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(LumenGlass.radiusButton),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
