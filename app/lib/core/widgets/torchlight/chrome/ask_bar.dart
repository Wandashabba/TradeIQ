import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/assistant/answer/ask_phase.dart';
import '../../../../features/assistant/answer/composer.dart';
import '../../../../features/assistant/data/chat_controller.dart';
import '../../../../features/assistant/presentation/chat_screen.dart'
    show askOnlineProvider, askSessionEndedProvider;
import '../../../../features/dashboard/data/floor_repository.dart'
    show floorViewProvider;
import '../../../../features/dashboard/presentation/floor_ask.dart'
    show showFloorDestinations;
import '../../../../l10n/l10n.dart';
import '../../../theme/torchlight/tiq_skin.dart';
import '../button/torch_press.dart';
import '../mark/tiq_mark.dart';

/// ── THE GRID BUTTON: WHERE ELSE YOU CAN GO, FROM ANYWHERE ──────────────
///
/// A ghost disc at the leading end of the ask bar. It opens
/// [showFloorDestinations] — the sheet that already existed and that The
/// Floor's plate control already opened — so the manager's destinations are
/// reached by **one gesture, and the same gesture on every console screen**.
///
/// ## Why it is a ghost and not a filled control
///
/// Send is the route's light, and since 3 October 2026 this key is exactly the
/// same size and shape as it. A filled disc beside a lit disc of identical
/// geometry is two objects competing at the same weight, and the only channel
/// left to tell a control from an action would be hue. A rim beside a block
/// is a control beside an action, in a channel that survives both skins and a
/// reader who cannot separate them by colour. The material is `_StopKey`'s, in
/// the same file as Send and for the same reason — transparent fill,
/// `edgeControl` rim, `torchPressSurface` under the finger. **Amber: none.**
/// It is a control, and controls are never amber (unify §1.6).
///
/// ## 48 drawn, 48 targeted — 3 October 2026
///
/// It was 44 drawn inside a 48 target: the tap-target floor, drawn at full
/// size because unlike the plate's quiet controls this one is not sitting on a
/// photograph and had no mockup weight to come down to. The claim written here
/// was that *"the two ends of the bar have the same reach and the row has one
/// height"*, and the reach was true. **The height was not** — the drawn boxes
/// were 44, 54 and 36 across the row, which is what the owner was looking at
/// when they said the bottom of the screen does not look proportioned.
///
/// Both numbers are [QuestionComposer.barExtent] now. They are kept as two
/// named constants, equal, because the distinction between what is painted and
/// what a finger hits is the one `floor_proportion_test.dart`'s weight table
/// is built on, and a row where the two agree is a fact worth being able to
/// read off.
class TorchAskDestinations extends StatelessWidget {
  const TorchAskDestinations({super.key, required this.onTap});

  final VoidCallback onTap;

  /// The drawn disc — the row's one size.
  static const double extent = QuestionComposer.barExtent;

  /// The square the finger lands in. The same number as [extent] since
  /// 3 October 2026, and Send's.
  static const double target = QuestionComposer.barExtent;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final radius = BorderRadius.circular(extent / 2);

    return Semantics(
      button: true,
      // THE WHOLE OF WHAT A SCREEN READER GETS, because the glyph says nothing
      // to anybody who cannot see it. The wording is
      // [FloorDestinationsButton]'s, which is the control this replaces, plus
      // the one fact that is new: it is now on every screen, so the sentence
      // has to work when you are standing on Webhooks.
      label: 'Go to another screen. Work, territories, reports and settings.',
      onTap: onTap,
      excludeSemantics: true,
      child: TorchPressable(
        onPressed: onTap,
        borderRadius: radius,
        builder: (context, pressed) => SizedBox.square(
          dimension: target,
          child: Center(
            child: Container(
              width: extent,
              height: extent,
              decoration: BoxDecoration(
                color: pressed ? torchPressSurface(skin).fill : null,
                borderRadius: radius,
                border: Border.all(
                  color: p.edgeControl,
                  width: pressed ? 2 : skin.depth.borderWidth,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.grid_view_rounded,
                  size: MarkScale.glyph(context, 18),
                  color: p.ink1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ── THE ASK BAR, ON EVERY CONSOLE SCREEN THAT IS NOT THE FLOOR OR ASK ──
///
/// ```text
///   ╭──╮ ╭───────────────────────────╮ ╭──╮
///   │▦▦│ │ Ask about your tasks…     │ │ ↑│
///   ╰──╯ ╰───────────────────────────╯ ╰──╯
/// ```
///
/// One object, pinned, identical geometry on all 29 console screens. It is
/// [QuestionComposer] with its [QuestionComposer.leading] slot filled —
/// literally the same widget The Floor and Ask put at the bottom of
/// themselves — so "identical" is a property of the code rather than a thing
/// somebody has to keep true across 29 files.
///
/// ## WHERE THE QUESTION GOES, which was the thing most likely to stop this
///
/// It goes to the same place it goes from The Floor, because
/// `ChatController.send` has never taken a route, a scope or a screen:
///
/// ```dart
/// Stream<AssistantEvent> chat({
///   required String message,
///   List<ChatHistoryEntry> history = const [],
///   String? conversationId,
///   CancelToken? cancelToken,
/// })
/// ```
///
/// The wire payload is `{message, conversationId, history}` and nothing else.
/// The Floor's composer is **not** "wired with the dashboard's scope" — the
/// scope appears in the printed *hint* and never on the wire. So a free-form
/// question from Webhooks is the identical request a question from The Floor
/// is, and there is no screen on which Send does nothing.
///
/// What is NOT route-agnostic is where the **answer** is drawn. The transcript
/// lives in one root-scoped [chatControllerProvider] and exactly two screens
/// render it. So this bar sends and then **goes to Ask**, where the turn it
/// just started is already streaming: the provider is not `autoDispose`, the
/// turn is not cancelled by the navigation, and Ask's `ref.watch` picks up the
/// in-flight state on its first frame. One tap from a question on any screen
/// to the answer to it, which is what a search-first app should do with a
/// search box.
///
/// ## Its phase is a property of the screen, not of hidden history
///
/// [transcriptEmpty] is passed `true` **always**. It is not a lie: this screen
/// draws no transcript, so there is nothing on it that has been read. The
/// alternative — reading the shared transcript's length — would make the Send
/// disc's light depend on whether the manager happened to ask something on Ask
/// ten minutes ago, which is invisible from here. [AskPhase.claims] makes
/// exactly this argument for the keystroke; it holds twice as hard for
/// history that is off screen.
///
/// `toolRunning` is passed `false` for the mirror reason: [AskPhase.thinking]
/// declares a live pulse, and a breathing amber dot on a screen with no
/// visible step to breathe about would be a light with nothing under it. A
/// turn in flight resolves to [AskPhase.writing] instead, which declares
/// nothing, disables the trough and draws Stop — the truth, with no new amber.
/// Without that, a second question pressed while a turn ran would hit
/// `ChatController.send`'s `if (state.sending) return` and do nothing, which
/// is the one failure mode this change exists to remove.
class ConsoleAskBar extends ConsumerStatefulWidget {
  const ConsoleAskBar({super.key, this.hint});

  /// What this screen says it will answer about. Null is the honest default
  /// and it is what 25 of the 27 framed screens pass — see `ConsoleFrame`.
  final String? hint;

  @override
  ConsumerState<ConsoleAskBar> createState() => _ConsoleAskBarState();
}

class _ConsoleAskBarState extends ConsumerState<ConsoleAskBar> {
  final TextEditingController _input = TextEditingController();
  bool _typed = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    final typed = text.trim().isNotEmpty;
    if (typed == _typed) return;
    setState(() => _typed = typed);
  }

  void _send() {
    final question = _input.text;
    if (question.trim().isEmpty) return;
    _input.clear();
    setState(() => _typed = false);
    // Send FIRST, then leave. The provider is root-scoped so the order is not
    // load-bearing for the turn surviving — but it is load-bearing for the
    // first frame of Ask, which should already have the question in it rather
    // than show an empty transcript for a frame and then fill.
    ref.read(chatControllerProvider.notifier).send(question);
    context.go('/assistant');
  }

  @override
  Widget build(BuildContext context) {
    final sending = ref.watch(chatControllerProvider).sending;
    final online = ref.watch(askOnlineProvider);
    final sessionEnded = ref.watch(askSessionEndedProvider);

    final phase = resolveAskPhase(
      // All three of these are statements about THIS screen, which draws no
      // transcript. See the class comment.
      transcriptEmpty: true,
      hasFocusObject: false,
      handedOff: false,
      toolRunning: false,
      streaming: sending,
      typed: _typed,
      lastTurnErrored: false,
      online: online,
      sessionEnded: sessionEnded,
    );

    return QuestionComposer(
      key: const ValueKey<String>('console-ask-bar'),
      controller: _input,
      phase: phase,
      onSend: _send,
      onStop: () => ref.read(chatControllerProvider.notifier).stop(),
      onChanged: _onChanged,
      // `Ask TradeIQ…` rather than Ask's own `Team, stock, shelf,
      // competitors`: that list is a teaching hint for the screen whose whole
      // job is the conversation, and on Webhooks it would be the bar
      // volunteering four topics the screen is not about.
      hint: widget.hint ?? context.l10n.askComposerConsoleHint,
      leading: TorchAskDestinations(
        key: const ValueKey<String>('console-destinations'),
        // READ, NOT WATCHED, AND ONLY WHEN THE GRID IS PRESSED. The sheet's
        // two subtitles are live numbers off the dashboard; watching
        // `floorViewProvider` here would put a dashboard request behind every
        // one of 27 screens for a caption. Read at the tap, the common case —
        // a manager who came from The Floor — already has the value cached,
        // and a cold deep-link gets the sheet with its subtitles withheld,
        // which is what `showFloorDestinations` already does for a scope whose
        // coverage request failed.
        onTap: () => showFloorDestinations(
          context,
          ref,
          ref
              .read(floorViewProvider)
              .maybeWhen(data: (v) => v, orElse: () => null),
        ),
      ),
    );
  }
}
