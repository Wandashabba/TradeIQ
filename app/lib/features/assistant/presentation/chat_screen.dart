import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/design/motion_budget.dart';
import '../../../core/design/torch_scope.dart';
import '../../../core/theme/torchlight/console_skin.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/input/filter_chip.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../l10n/l10n.dart';
import '../answer/answer_markdown.dart';
import '../answer/answer_motion.dart';
import '../answer/answer_notes.dart';
import '../answer/answer_view.dart';
import '../answer/ask_light.dart';
import '../answer/ask_phase.dart';
import '../answer/ask_turn.dart';
import '../answer/composer.dart';
import '../answer/web_sources.dart';
import '../answer/working_steps.dart';
import '../data/chat_controller.dart';
import '../view_specs/answer_focus.dart';
import '../view_specs/instrument_panel.dart';
import '../view_specs/outside_band.dart';
import '../view_specs/view_spec_registry.dart';
import 'ask_first_run.dart';
import 'ask_history_sheet.dart';

/// Whether the app believes it can reach the assistant.
///
/// **A seam with no producer yet.** There is no connectivity channel in this
/// app — no `connectivity_plus`, no platform stream — so nothing sets this
/// false in production today and the offline state is reached only by a test
/// or by an override. It is declared rather than omitted because the state is
/// designed, built and asserted: the day a connectivity signal lands, this is
/// the one line that changes, and nothing else moves.
///
/// It is deliberately **not** derived from the last turn's error. "Could not
/// reach the assistant" is already rendered as that turn's error block, and a
/// band saying the same thing above the composer would be the product telling
/// a manager twice.
final askOnlineProvider = Provider<bool>((ref) => true);

/// Whether the manager's session has ended under her.
///
/// Derived from the real thing — the session controller losing its token,
/// which is what `onUnauthorized` does on any 401. Today the router's
/// `refreshListenable` usually navigates to `/login` before this band can be
/// read; when it does, the band is simply never seen, which is exactly
/// today's behaviour rather than a regression. The state exists so that
/// "held work visible behind it" (#380) has somewhere to land.
final askSessionEndedProvider = Provider<bool>((ref) {
  final session = ref.watch(sessionControllerProvider);
  return session.hasValue && session.value!.token == null;
});

/// ASK TRADEIQ.
///
/// ```text
///   Ask TradeIQ                     [ 6 questions ]   [ ☾ ]
///   ─────────────────────────────────────────────────────
///                                 ┌──────────────────┐
///                                 │ how is Tumo…     │   the question
///                                 └──────────────────┘
///   ● Checked 5 sources · 2.1s                    ⌄       the provenance
///   Three Gauteng North outlets lost on-shelf             the headline
///   availability faster than the territory did.
///   ┌─────────────────────────────────────────────┐
///   │ ON-SHELF AVAILABILITY              61%      │       the panel
///   │ ─────────────────────────────────────────── │
///   │ WORST FIRST                                 │
///   │ Shoprite Klipfontein  ▬▬▬▬▬▬▬▬▬     34%     │
///   └─────────────────────────────────────────────┘
///   ── Sources 5 ────────────────────────────────
///   [ ↳ which outlets recovered? ]
///   Ask a question
///   [ ____________________________________ ]  [ ↑ ]        the composer
///   [ nav pill ]
/// ```
///
/// Darkness is the room; the answer is the light. One sentence, one panel,
/// one lit object — and the light is **counted**, not asserted.
///
/// ## The amber census, per phase
///
/// | phase | Night | Day / Veld | which |
/// |---|---|---|---|
/// | first run | 1 | 0 | the nav tab; Send is disabled |
/// | thinking | 2 | 0 | the nav tab, the running step |
/// | writing | 1 | 0 | the nav tab — the amber goes out before the turn ends |
/// | landed, focus | 2 | 0 | the nav tab, one bar or one series |
/// | landed, tiles only | 1 | 0 | the nav tab; four numbers are the reading |
/// | typing | 1 | 1 | Send — the keyboard took the nav, and its grant with it |
/// | error, offline, session ended | 1 | 0 | the nav tab |
///
/// ## What the shell does and does not carry
///
/// A tab root, so the nav pill renders and there is **no thumb zone**: the
/// composer is a `TorchShell.band`, a pinned sibling of the scroll view that
/// clears the keyboard itself. There is **no nav circle** on this route — the
/// manager's circle is "raise a task / assign a visit", there is nothing here
/// to raise one about, and a route-local override would give one control two
/// meanings. History is a header chip rather than a second trailing icon
/// button, because the header's rule is exactly one and the top-right corner
/// is the worst reachable point on a 6.5in phone.
class AssistantChatScreen extends StatelessWidget {
  const AssistantChatScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const ConsoleTorchlightRoute(child: _Ask());
}

class _Ask extends ConsumerStatefulWidget {
  const _Ask();

  @override
  ConsumerState<_Ask> createState() => _AskState();
}

class _AskState extends ConsumerState<_Ask> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  /// The trough holds text. Kept as state rather than read from the
  /// controller during build, so the phase — and therefore the claim set —
  /// changes exactly once when the trough goes from empty to not.
  bool _typed = false;

  /// The hand-off, latched. When the trough first takes text after a turn has
  /// landed, the answer's focus object drops its bloom **once and permanently
  /// for that turn**. Clearing the trough does not light it again: the
  /// attention moved from reading to asking, and a bar that came back alight
  /// when a manager deleted a word would be the flicker the counted budget
  /// exists to prevent.
  bool _handedOff = false;

  /// A turn is following the tail. One upward scroll releases it.
  bool _following = true;

  int _turns = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final atTail = _scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 24;
    if (atTail != _following) setState(() => _following = atTail);
  }

  void _onChanged(String text) {
    final typed = text.trim().isNotEmpty;
    if (typed == _typed) return;
    setState(() {
      _typed = typed;
      if (typed) _handedOff = true;
    });
  }

  void _send([String? text]) {
    final question = text ?? _input.text;
    if (question.trim().isEmpty) return;
    _input.clear();
    setState(() {
      _typed = false;
      _handedOff = false;
      _following = true;
    });
    ref.read(chatControllerProvider.notifier).send(question);
    _pinToTail();
  }

  /// A single `jumpTo` scheduled at most once per frame.
  ///
  /// The old build listened to every controller change and ran a 220ms
  /// `animateTo`, which fires on every token — roughly thirty times a second,
  /// each call cancelling the last. That is deleted: while a turn streams the
  /// list is pinned, not animated, and a smooth scroll is used only when the
  /// manager asks for one.
  bool _scheduled = false;

  void _pinToTail() {
    if (_scheduled || !_following) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || !_scroll.hasClients || !_following) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _openHistory() async {
    final startOver = await showTorchSheet<bool>(
      context,
      builder: (sheetContext) => AskHistorySheet(
        onGoToTurn: (index) => Navigator.of(sheetContext).pop(false),
        // Sheets do not stack: the history sheet closes with its answer and
        // the decision opens after it, rather than on top of it while it is
        // still leaving.
        onStartOver: () => Navigator.of(sheetContext).pop(true),
      ),
    );
    if (startOver == true && mounted) await _openStartOver();
  }

  Future<void> _openStartOver() async {
    final state = ref.read(chatControllerProvider);
    final questions =
        state.messages.where((m) => m.role == ChatRole.user).length;
    await showTorchSheet<void>(
      context,
      builder: (sheetContext) => AskStartOverSheet(
        questions: questions,
        midTurn: state.sending,
        onCarryOn: () => Navigator.of(sheetContext).pop(),
        onStartOver: () {
          Navigator.of(sheetContext).pop();
          ref.read(chatControllerProvider.notifier).clear();
          _input.clear();
          setState(() {
            _typed = false;
            _handedOff = false;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final state = ref.watch(chatControllerProvider);
    final online = ref.watch(askOnlineProvider);
    final sessionEnded = ref.watch(askSessionEndedProvider);

    // Pin the tail whenever the transcript grows, once per frame — not per
    // token, and not through a listener that cancels its own animation.
    if (state.messages.length != _turns) {
      _turns = state.messages.length;
      _pinToTail();
    } else if (state.sending) {
      _pinToTail();
    }

    final last = state.messages.isEmpty ? null : state.messages.last;
    final answer = last?.role == ChatRole.assistant ? last : null;
    final toolRunning =
        answer != null && answer.tools.any((t) => t.ok == null);
    // Resolved once per build from the server's word, and handed to exactly
    // one turn: the claim and the paint read the same target, so they cannot
    // disagree about whether — or where — the answer is lit.
    final focusTarget =
        answer == null ? null : AnswerFocusTarget.resolve(answer);
    final focusArtifact = focusTarget != null;

    final phase = resolveAskPhase(
      transcriptEmpty: state.messages.isEmpty,
      streaming: state.sending,
      toolRunning: toolRunning,
      typed: _typed,
      lastTurnErrored: answer?.error != null,
      hasFocusObject: focusArtifact,
      handedOff: _handedOff,
      online: online,
      sessionEnded: sessionEnded,
    );

    final questions =
        state.messages.where((m) => m.role == ChatRole.user).length;

    return TorchSheetAware(
      builder: (context, beneathSheet) => TorchScope(
        skin: skin,
        phase: phase.name,
        navRenders: TorchShell.navWillRender(context, hasNav: true),
        tabbedRoute: true,
        beneathSheet: beneathSheet,
        claims: phase.claims,
        child: TorchShell(
          profile: TorchShellProfile.console,
          scrollController: _scroll,
          header: TorchAppHeader(
            title: l10n.askTitle,
            trailing: consoleSkinCycleButton(context, ref),
            flagChips: <Widget>[
              // A session, not an archive — and absent entirely while there
              // is nothing to look back at.
              if (questions > 0)
                TorchFilterChip(
                  key: const ValueKey<String>('ask-history-chip'),
                  label: l10n.askHistoryAction,
                  count: questions,
                  selected: false,
                  onSelected: _openHistory,
                ),
            ],
          ),
          navPill: TorchNavPill(
            slots: askNavSlots(l10n),
            activeIndex: 2,
            onSelect: (i) => _go(context, i),
          ),
          band: QuestionComposer(
            controller: _input,
            phase: phase,
            onSend: _send,
            onStop: () => ref.read(chatControllerProvider.notifier).stop(),
            onChanged: _onChanged,
            lastTurnErrored: answer?.error != null,
            band: _band(context, phase),
          ),
          children: state.messages.isEmpty
              ? <Widget>[
                  AskFirstRun(onAsk: _send, enabled: phase.canSend),
                ]
              : <Widget>[
                  for (var i = 0; i < state.messages.length; i++) ...<Widget>[
                    if (i > 0) SizedBox(height: skin.space.blockGap + 8),
                    AnswerFocusScope(
                      key: ValueKey<int>(i),
                      focus: state.messages[i].focus,
                      target: i == state.messages.length - 1
                          ? focusTarget
                          : null,
                      child: _Turn(
                        message: state.messages[i],
                        previous: i >= 2 ? state.messages[i - 2] : null,
                        phase: phase,
                        onAsk: _send,
                      ),
                    ),
                  ],
                ],
        ),
      ),
    );
  }

  /// Floor · Work · Ask · Menu. Four slots, because five do not fit the 360dp
  /// arithmetic, and Ask is the third.
  static List<TorchNavSlot> askNavSlots(AppLocalizations l10n) =>
      <TorchNavSlot>[
        TorchNavSlot(
          icon: Icons.inventory_2_outlined,
          activeIcon: Icons.inventory_2,
          label: l10n.askNavFloor,
        ),
        TorchNavSlot(
          icon: Icons.checklist_outlined,
          activeIcon: Icons.checklist,
          label: l10n.askNavWork,
        ),
        TorchNavSlot(
          icon: Icons.forum_outlined,
          activeIcon: Icons.forum,
          label: l10n.askNavAsk,
        ),
        TorchNavSlot(
          icon: Icons.menu,
          activeIcon: Icons.menu_open,
          label: l10n.askNavMenu,
        ),
      ];

  static void _go(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/dashboard');
      case 1:
        context.go('/tasks');
      case 2:
        context.go('/assistant');
      case 3:
        context.go('/dashboard/overview');
    }
  }

  Widget? _band(BuildContext context, AskPhase phase) {
    final l10n = context.l10n;
    return switch (phase) {
      AskPhase.sessionEnded => AskHeldBand(
        message: l10n.askSessionEnded,
        semanticsLabel: l10n.askSessionEndedSemantic,
        action: l10n.askSignIn,
        onAction: () => context.push('/login'),
      ),
      AskPhase.offline => AskHeldBand(
        message: l10n.askOffline,
        semanticsLabel: l10n.askOffline,
      ),
      _ => null,
    };
  }
}

/// One turn in the transcript.
class _Turn extends ConsumerWidget {
  const _Turn({
    required this.message,
    required this.previous,
    required this.phase,
    required this.onAsk,
  });

  final ChatMessage message;

  /// The same speaker's previous turn, for the repeated-failure line.
  final ChatMessage? previous;

  final AskPhase phase;
  final ValueChanged<String> onAsk;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = context.skin;
    if (message.role == ChatRole.user) {
      return QuestionBubble(text: message.text);
    }

    final animate = message.streaming && !MotionBudget.of(context).still;
    final parsed = parseAnswer(message.text, streaming: message.streaming);
    final figures = AnswerFigures.of(message);
    final writing = message.streaming && message.tools.every((t) => t.ok != null);

    final rich = message.error == null &&
        (parsed.hasMarkdown || parsed.followUps.isNotEmpty);

    final trailing = <Widget>[
      if (message.notice != null) AnswerNotice(notice: message.notice!),
      if (figures.outside.isNotEmpty)
        OutsideDataBand(artifacts: figures.outside, now: DateTime.now()),
    ];

    final body = <Widget>[
      // The rail sits above the answer: its whole job is to explain a pause
      // before there is any text to show, and afterwards to say what the
      // answer was built from.
      //
      // It also stands in the gap before the first event, header only, so a
      // question never sits above a blank space that reads as a dropped send.
      if (message.streaming &&
          (message.tools.isNotEmpty || message.text.isEmpty))
        WorkingSteps(
          tools: message.tools,
          streaming: true,
          animate: animate,
          writing: writing,
          lastEventAt: message.lastEventAt,
          now: ref.read(assistantClockProvider),
          onStop: () => ref.read(chatControllerProvider.notifier).stop(),
        )
      else if (message.tools.isNotEmpty)
        StepsSummaryRow(tools: message.tools),
      if (message.error != null)
        AnswerErrorBlock(
          message: message.error!,
          code: message.errorCode,
          repeated: previous?.error != null,
          onRetry: () => onAsk(_question(context, ref)),
        )
      else if (rich)
        RichAnswer(
          parsed: parsed,
          streaming: message.streaming,
          animate: animate,
          followUpsEnabled: phase.canSend,
          trailing: trailing,
          artifacts: <Widget>[AnswerPanel(figures: figures)],
        )
      else ...<Widget>[
        if (message.text.isNotEmpty) PlainAnswer(message: message),
        AnswerPanel(figures: figures),
        ...trailing,
      ],
      if (message.stopped)
        StoppedLine(onAskAgain: () => onAsk(_question(context, ref))),
      // A turn that errored has no answer to cite, and a turn still being
      // written has not cited yet: sources arrive after the tokens, and a
      // searched turn saying "nothing usable" before they land is false.
      if (message.error == null && !message.streaming)
        WebSources(
          sources: message.sources,
          searched: message.tools.any(
            (t) => AnswerFigures.webTools.contains(t.name),
          ),
        ),
    ];

    return Semantics(
      container: true,
      label: context.l10n.askAnswer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var i = 0; i < body.length; i++) ...<Widget>[
            if (i > 0) SizedBox(height: skin.space.blockGap),
            Arrive(
              key: ValueKey<int>(i),
              enabled: false,
              child: body[i],
            ),
          ],
        ],
      ),
    );
  }

  /// The question this turn answered — what "Try again" and "Ask again" send.
  String _question(BuildContext context, WidgetRef ref) {
    final messages = ref.read(chatControllerProvider).messages;
    final at = messages.indexOf(message);
    for (var i = at - 1; i >= 0; i--) {
      if (messages[i].role == ChatRole.user) return messages[i].text;
    }
    return '';
  }
}

/// Exported so the amber census can name the claim it expects to find.
const String askFocusClaimId = AskLight.focusClaimId;
