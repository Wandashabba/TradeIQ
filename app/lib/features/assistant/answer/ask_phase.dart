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
  /// No transcript. The teaching screen — and **Send is armed**, since
  /// 1 October 2026. See [claims].
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
  /// then Night's count is the nav's active tab alone and Day's is zero —
  /// which is correct, because nothing is armed.
  ///
  /// ## [firstRun] IS AN ARMED PHASE — 1 October 2026
  ///
  /// > *"the send button is amber"* — the owner, on the third screenshot of
  /// > The Floor, against a render in which it was an outlined disc.
  ///
  /// It was outlined because it was **disabled with an empty composer**, and
  /// `AskLight.send` is right to refuse amber to a disabled control: *"a
  /// disabled button wearing the screen's one light would be the lie the
  /// amber law exists to prevent."* The sign-in screen met this exact wall on
  /// 30 September 2026 and the resolution is recorded in `login_screen.dart`:
  /// the button is **live from the first frame**, and pressing it before it
  /// can do its real job does something useful instead of nothing. *"That is
  /// an action, which is what earns it the amber."*
  ///
  /// **A composer is the same case, and what "what is missing" means for it is
  /// the only thing that differs.** The login form has two fields, so the
  /// press buys a diagnosis — *which* one, in field order. A composer has one
  /// field, visibly empty, directly beside the button; naming it would be
  /// restating what the empty trough already says better by being empty. So
  /// the press does the other half of what login's does: it **puts the cursor
  /// in the trough and raises the keyboard**. Press Send with nothing typed
  /// and you are typing. See `QuestionComposer`.
  ///
  /// ## Why the light stops here and not at [landed]
  ///
  /// [firstRun] is the only phase where the screen has nothing to read yet, so
  /// asking is unambiguously the expected next move — which is what rung 1
  /// means. Once an answer is on screen the expected next move is to read it,
  /// and rung 3 lights the one object the server named as the reading.
  /// Extending the grant to [landed] and [landedFocus] would take that light
  /// off the answer to put it on a button, and the hand-off in [AskLight]'s
  /// own note already settles which way round that goes.
  ///
  /// **Nothing blinks.** The transition this adds is at-rest → typing, and
  /// both are now lit, so the one frame that used to go dark no longer does.
  /// The typing → landed transition is unchanged and was always a real event.
  ///
  /// THE CENSUS ARITHMETIC, which is the part worth checking rather than
  /// trusting — per phase, per skin, counted in `the_floor_test.dart` and
  /// `ask_amber_census_test.dart`:
  ///
  /// | frame | before | after | budget |
  /// |---|---|---|---|
  /// | Floor · Night · at rest | 1 (strip) | **2** (Send + strip) | 2 |
  /// | Floor · Night · at rest, no picture | 0 | **1** (Send) | 2 |
  /// | Floor · Day · at rest | 0 | **1** (Send) | 1 |
  /// | Floor · Night · typing | 2 | 2 | 2 |
  /// | Floor · Night · answered | 2 (strip + bar) | 2 | 2 |
  /// | Floor · Night · offline | 1 (strip) | 1 | 2 |
  /// | Ask · Night · first run | 1 (nav tab) | **2** (nav + Send) | 2 |
  /// | Ask · Day · first run | 0 | **1** (Send) | 1 |
  ///
  /// Every row is inside its budget and the two the owner predicted — Night
  /// at rest 1 → 2, Day at rest 0 → 1 — are the two that moved on The Floor.
  /// **The answered frame does not move**, which is the row that decided the
  /// shape of this change: the grant is scoped to [firstRun] precisely so the
  /// answer keeps the one amber bar the mockup draws under it.
  List<TorchClaim> get claims => switch (this) {
    // ONE CLAIM, TWO PHASES, SAME RUNG, SAME ID — and [armed] is the same
    // predicate, so the declaration and the widget cannot come apart. The
    // allocator sees the same claim whether the trough is empty or not, which
    // is what makes "Send is lit" a property of the screen rather than of the
    // keystroke, and what stops the light blinking on the first character.
    AskPhase.firstRun || AskPhase.typing => const <TorchClaim>[
      TorchClaim.primaryCommit(AskLight.sendClaimId),
    ],
    AskPhase.landedFocus => const <TorchClaim>[
      TorchClaim.chartFocus(AskLight.focusClaimId),
    ],
    AskPhase.thinking => const <TorchClaim>[
      TorchClaim.livePulse(AskLight.pulseClaimId),
    ],
    AskPhase.writing ||
    AskPhase.landed ||
    AskPhase.errored ||
    AskPhase.offline ||
    AskPhase.sessionEnded => const <TorchClaim>[],
  };

  /// Whether the composer can commit. Offline and a dead session both disable
  /// it, and a disabled Send is never amber in any skin.
  ///
  /// It outranks [armed]: an offline Send is not live-and-validating, it is
  /// genuinely unable to do the thing, and the held band above the composer is
  /// already saying why. A lit Send over an offline band would be the lie this
  /// whole mechanism is about.
  bool get canSend =>
      this != AskPhase.offline && this != AskPhase.sessionEnded;

  /// Whether this phase declares the route's rung-1 grant — i.e. whether Send
  /// is **lit**, subject to the allocator still granting it.
  ///
  /// ## It is NOT the same question as [canSend], and that is deliberate
  ///
  /// [canSend] is whether the button **presses**. [armed] is whether it is
  /// **amber**. They were one boolean until 1 October 2026 and conflating them
  /// is what produced the render the owner rejected: Send was disabled because
  /// nothing was typed, so it could not be amber, so the screen's one action
  /// was an outlined disc on a frame whose whole purpose is to be asked a
  /// question.
  ///
  /// Splitting them gives each the right answer:
  ///
  /// * **Press: always, whenever the connection allows.** One rule at every
  ///   phase. A manager who learns "tap the arrow and start typing" on the
  ///   briefing still has it after the first answer lands — which they would
  ///   not if the press followed the light.
  /// * **Light: only where asking is the expected next move.** At rest and
  ///   while typing. Once an answer is on screen, rung 3 lights the object the
  ///   server named as the reading, and `AskLight.send`'s existing
  ///   granted-but-**unlit** form — `lifted` fill, ink-1 glyph, `edgeControl`
  ///   rim — is what Send wears there. That form has always existed for
  ///   exactly this case and this is the first control to use it as designed.
  ///
  /// Note what [armed] is therefore **not**: a disabled look. A pressable
  /// control that is not carrying the route's light is an ordinary control,
  /// and it is drawn as one.
  bool get armed =>
      canSend && (this == AskPhase.firstRun || this == AskPhase.typing);
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
