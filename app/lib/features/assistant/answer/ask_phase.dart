import '../../../core/design/torch_scope.dart';
import 'ask_light.dart';

/// WHAT THE ASK ROUTE IS DOING, AND THEREFORE WHAT IS LIT.
///
/// The amber claim set is resolved **per route × phase, at construction** —
/// never per frame — because a grant recomputed while a thumb scrolls is a
/// grant that blinks. This enum is that phase, and [claims] is the whole of
/// the route's declaration.
///
/// It is a pure function of the view model, which is what lets the census test
/// walk every phase in every skin without standing up a screen for each.
enum AskPhase {
  /// No transcript. The teaching screen, and Send is disabled because there is
  /// nothing typed to send.
  firstRun,

  /// A tool is genuinely executing. The one live pulse this surface permits.
  thinking,

  /// Every tool has finished and the tokens have not started — or have, and
  /// no tool ever ran. The amber goes out *before* the turn is finished,
  /// because a breathing amber means "right now" and a model composing a
  /// sentence is not a lookup.
  writing,

  /// A settled answer with a server-named focus object, and an empty trough.
  landedFocus,

  /// A settled answer with nothing to light: tiles only, prose only, or a
  /// focus that has already handed off. Four numbers together are the reading,
  /// and lighting one of them would misdirect.
  landed,

  /// The manager has typed something, so sending it is the expected next move.
  typing,

  /// The last turn failed. Severity abandons the amber band entirely: there is
  /// no amber warning in TradeIQ.
  errored,

  /// No connection. Nothing is queued and Send is disabled — a stale answer to
  /// a live question is worse than none.
  offline,

  /// The session ended. Held, not failed: a token expiring at 14:00 on a
  /// Tuesday is a fact about a clock.
  sessionEnded;

  /// What this phase declares to [TorchScope].
  ///
  /// Read the table in [AskLight]: rung 1 is Send, rung 3 the answer's focus
  /// object, rung 6 the running dot. Every other phase declares nothing, and
  /// then Night's count is the nav's active tab alone and Day's and Veld's is
  /// zero — which is correct, because nothing is armed.
  List<TorchClaim> get claims => switch (this) {
    AskPhase.typing => const <TorchClaim>[
      TorchClaim.primaryCommit(AskLight.sendClaimId),
    ],
    AskPhase.landedFocus => const <TorchClaim>[
      TorchClaim.chartFocus(AskLight.focusClaimId),
    ],
    AskPhase.thinking => const <TorchClaim>[
      TorchClaim.livePulse(AskLight.pulseClaimId),
    ],
    AskPhase.firstRun ||
    AskPhase.writing ||
    AskPhase.landed ||
    AskPhase.errored ||
    AskPhase.offline ||
    AskPhase.sessionEnded => const <TorchClaim>[],
  };

  /// Whether the composer can commit. Offline and a dead session both disable
  /// it, and a disabled Send is never amber in any skin.
  bool get canSend => this != AskPhase.offline && this != AskPhase.sessionEnded;
}

/// Resolve the route's phase.
///
/// Order matters and every step of it is a decision:
///
/// * **A dead session outranks everything**, including a turn still on the
///   wire — nothing else the manager can do will work.
/// * **Offline outranks what is on the screen**, because the question is what
///   she cannot do next, not what she is reading.
/// * **A live turn outranks a typed follow-up.** While an answer streams, Send
///   is Stop and there is no commit action to light.
/// * **Typing outranks a landed answer**, which is the hand-off: the attention
///   moved from reading to asking and the light moves with it.
AskPhase resolveAskPhase({
  required bool transcriptEmpty,
  required bool streaming,
  required bool toolRunning,
  required bool typed,
  required bool lastTurnErrored,
  required bool hasFocusObject,
  required bool handedOff,
  bool online = true,
  bool sessionEnded = false,
}) {
  if (sessionEnded) return AskPhase.sessionEnded;
  if (!online) return AskPhase.offline;
  if (streaming) return toolRunning ? AskPhase.thinking : AskPhase.writing;
  if (typed) return AskPhase.typing;
  if (lastTurnErrored) return AskPhase.errored;
  if (transcriptEmpty) return AskPhase.firstRun;
  return hasFocusObject && !handedOff ? AskPhase.landedFocus : AskPhase.landed;
}
