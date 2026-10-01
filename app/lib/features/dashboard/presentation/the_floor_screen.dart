import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tiq_number.dart' show TiqNumber;
import '../../../core/design/torch_scope.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/console_frame.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/plate/plate.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../l10n/l10n.dart';
import '../../assistant/answer/ask_phase.dart';
import '../../assistant/answer/ask_turn.dart' show AskHeldBand;
import '../../assistant/answer/composer.dart';
import '../../assistant/data/chat_controller.dart';
import '../../assistant/presentation/chat_screen.dart';
import '../../assistant/view_specs/answer_focus.dart';
import '../../territories/data/territories_repository.dart'
    show PlaceImageSource;
import '../../territories/data/territories_view.dart';
import '../data/dashboard_repository.dart';
import '../data/floor_ask_view.dart';
import '../data/floor_repository.dart';
import 'dashboard_filters.dart';
import 'first_run_board.dart';
import 'floor_ask.dart';
import 'standards.dart';

/// THE FLOOR — the manager's home.
///
/// It answers one question on a 360×640dp phone: *what is broken, and who is
/// fixing it?* Everything on it is in service of that sentence, and anything
/// that was not has been cut.
///
/// ```text
///   ╭───────────────╮  the plate: the place in scope, one strip of light,
///   │ (Gauteng ·›) ☰│  the scope chip top-left and Menu top-right, ON the
///   │ 73 ▼19        │  picture; the hero at the foot
///   ╰───────────────╯
///   ╭───────────────╮
///   │ • Overdue  12 │  the briefing: three ONE-LINE cards, no heading
///   ╰───────────────╯
///   ╭───────────────╮
///   │ • OSA     61% │
///   ╰───────────────╯
///   ╭───────────────╮
///   │ • Outlet   6d │
///   ╰───────────────╯
///
///                      ← and then nothing. The gap is the design.
///
///   (Why is 73 down?) (Show …)
///   ╭───────────────╮
///   │ Ask…       ↑  │  the composer, alone at the bottom
///   ╰───────────────╯
/// ```
///
/// ## What this screen is NOT, since 1 October 2026
///
/// It is not a briefing **and** a decision list. The approved arrangement
/// replaces one with the other, and the version that kept both was built off
/// an instruction — *"if something cannot fit above the fold it moves, it does
/// not disappear"* — that the arrangement contradicts. The owner read the
/// result as dense and said so. See [_ScopeNote] for where the list is reached
/// from now, and `floor_taps_test.dart` for the proof that it is.
///
/// Three things went with it and each one is a line of the fold bought back:
/// the `LAST 30 DAYS` kick over the briefing (the window is on the scope chip,
/// on the control that sets it), the `NEEDS A DECISION` marker, and the
/// supporting sentence under each briefing name (spoken, and printed only
/// where there is no figure — see [FloorBrief]).
///
/// **Cards, since 25 September 2026.** unify §1.3 ruled every list row flush
/// and this screen's blocks bare on the ground; the owner overruled it twice
/// looking at the running screen ("I hate this box style"; "it's still very
/// boxy and I don't need that") and the grammar is now a soft card at radius
/// 22 with a gap of ground between. The override is recorded in
/// `docs/design/spec/unify.md` §1.3 and `docs/design/torchlight-aisle.md`.
/// Still true: no shadows, nothing centred, no gradient inside a list row.
///
/// ## The two ambers, counted
///
/// Night allows two lit objects in the composed frame. The nav pill's active
/// tab is slot 1 whenever the nav renders; this route spends slot 2 on the
/// plate's strip light. Everything else that might have asked is unlit **by
/// construction rather than by argument**: the hero's delta is severity
/// crimson, every sparkline's last dot is severity crimson, the section rule
/// has no colour at all, the scope chip is a control and controls are never
/// amber (unify §1.6), and the nav circle is denied by the ladder. When there
/// is no picture the plate's grant goes unspent and the screen renders one
/// amber object — a budget is a ceiling, not a quota.
///
/// ## Unknown is not zero
///
/// A brand-new tenant gets the [FirstRunBoard], not a scoreboard of zeros. A
/// tenant with outlets but no visits in this window gets The Floor with em
/// dashes, sentences and no deltas — never-measured and not-measured-lately
/// are different facts. The distinction comes from the server's `totals`, not
/// from a figure that happens to be 0.
class TheFloorScreen extends ConsumerWidget {
  const TheFloorScreen({super.key});

  /// The [TorchClaim] id the plate's strip light is declared under.
  static const String plateClaimId = 'floor-plate-strip-light';

  /// ── THE PLATE'S TWO HEIGHTS, AS A SHARE OF THE VIEWPORT ──────────────
  ///
  /// Public because they are not an implementation detail of one widget: the
  /// plate's geometry is what `floor_proportion_test.dart` measures and what
  /// `floor_plate_tone_test.dart` has to resolve a [PlateSpec] with in order
  /// to know which band of the picture is clean enough to sample. A test that
  /// re-derives these from `PlateSpec`'s own defaults measures a plate this
  /// screen does not draw — which is exactly how the tone test started
  /// sampling the strip light's own bloom.
  ///
  /// The numbers are the mockup's: its plate is 196px of a 649px screen at
  /// rest and 124px once answered, which is 30.2% and 19.1%. See
  /// [_PlateFor.shrunk] for why it is a share rather than two dp constants.
  static const double plateShareAtRest = 0.30;
  static const double plateShareAnswering = 0.19;

  /// The shortest photographic plate this screen accepts — below
  /// [PlateSpec.floorShortest], because the answering height is below it on
  /// both supported phones and a plate that drops its photograph while a
  /// manager is reading an answer about that territory has dropped the point.
  static const double plateShortest = 120;

  /// What sits under the plate at each of the two heights. The `ground`
  /// [PlateSpec.heightFor] takes: *what the screen needs below the picture*.
  static double plateGroundFor(double viewportHeight, {required bool shrunk}) =>
      viewportHeight * (1 - (shrunk ? plateShareAnswering : plateShareAtRest));

  /// The nav circle's id. It is declared and then *denied*, every time: the
  /// plate takes the one content grant at rung 2 and the circle sits at rung
  /// 4. Naming it anyway is what makes the denial visible in
  /// `TorchAllocation.describe()` rather than invisible in a widget that
  /// quietly never asked.
  static const String navCircleClaimId = 'floor-standing-action';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(floorViewProvider);

    return view.when(
      loading: () => const _FloorFrame(
        phase: 'loading',
        hasPlatePhoto: false,
        children: <Widget>[_FloorSkeleton()],
      ),
      error: (error, stack) => _FloorFrame(
        phase: 'error',
        hasPlatePhoto: false,
        children: <Widget>[
          _FloorError(onRetry: () => ref.invalidate(floorViewProvider)),
        ],
      ),
      data: (data) {
        if (data.phase == FloorPhase.firstRun) {
          return const FirstRunBoard();
        }
        return _Floor(view: data);
      },
    );
  }
}

/// The frame every state of this route wears, so a skeleton, an error and the
/// real thing are the same screen in three conditions rather than three
/// screens.
class _FloorFrame extends StatelessWidget {
  const _FloorFrame({
    required this.phase,
    required this.hasPlatePhoto,
    required this.children,
    this.claims = const <TorchClaim>[],
    this.band,
  });

  final String phase;
  final bool hasPlatePhoto;
  final List<Widget> children;

  /// What the route's current phase declares, **before** the plate's own
  /// claim is added. See the census table on [TheFloorScreen].
  final List<TorchClaim> claims;

  /// The composer, pinned above the safe area. Null on the loading and error
  /// states: there is nothing to ask about a screen whose figures did not
  /// arrive, and a composer over a skeleton is a promise the route cannot keep.
  final Widget? band;

  @override
  Widget build(BuildContext context) {
    return TorchScope(
      skin: context.skin,
      phase: phase,
      // THE NAV PILL IS GONE FROM THIS ROUTE, and with it the one amber grant
      // that chrome was taking. See the arithmetic on [TheFloorScreen].
      navRenders: false,
      tabbedRoute: false,
      claims: <TorchClaim>[
        ...claims,
        // Declared only when there is something to light. The allocator is
        // told the truth about the frame rather than handed a claim the
        // widget will then decline to spend.
        if (hasPlatePhoto)
          const TorchClaim.plateStripLight(TheFloorScreen.plateClaimId),
      ],
      // THE PLATE IS A CARD AND NO LONGER THE TOP EDGE. It ran full-bleed to
      // y=0 until 25 September 2026, and `bleedTop` is what took the shell's
      // 24dp console inset away to let it. The owner's reference insets the
      // plate and rounds it, so the inset comes back for every state — a card
      // hard against the status bar is a card with one edge missing.
      child: FloorScaffold(
        bleedTop: false,
        showNavPill: false,
        band: band,
        children: children,
      ),
    );
  }
}

/// The scroll frame: [TorchShell] in its console profile, with the manager's
/// four nav slots and the standing action beside them.
///
/// The Floor carries **no app header**. The plate is the header: the scope
/// chip at the top of it names the territory and the window and opens the
/// scope sheet — everything a title bar would have said, and the one thing a
/// title bar could not do. A 56dp title row above a picture that already says
/// where you are is the fold spent twice. (It used to run full-bleed to the top edge as
/// well; since 25 September 2026 it is an inset card and the shell's own
/// console inset is the air above it.)
///
/// The consequence is named rather than hidden: the skin cycle lives in the
/// header's single trailing slot on a tab root, and this route has no header
/// to put it in. On The Floor it belongs in the Menu destination, which is
/// where the manager's overflow lives — see the follow-up for the Menu sheet.
///
/// ## The nav is the console's nav, not a copy of it
///
/// This frame exists because The Floor cannot use [ConsoleFrame] — it has no
/// app header, and the plate has to run full-bleed to the top edge. What it
/// must **not** do is own a second copy of the bar. It did: a private slot
/// list, `activeIndex: 0`, `onSelect: onSelectSlot ?? (_) {}` with no caller
/// ever passing `onSelectSlot`, and `onPressed: () {}` on the circle. The
/// manager's home screen shipped with four destinations and a standing action
/// that pressed, buzzed, scaled to 0.98 and did nothing — the one defect a
/// widget test of the pill in isolation can never see.
///
/// So the slots come from [consoleNavSlots] and the press goes through
/// [consoleNavSelect], exactly as every other console route's do.
class FloorScaffold extends StatelessWidget {
  const FloorScaffold({
    super.key,
    required this.children,
    this.onSelectSlot,
    this.onStandingAction,
    this.bleedTop = true,
    this.showNavPill = true,
    this.band,
  });

  final List<Widget> children;

  /// ── THE BOTTOM-REGION SEAM ────────────────────────────────────────────
  ///
  /// The composer and the nav pill both want the bottom of the screen, and
  /// which one wins was a product decision rather than an engineering one. The
  /// owner took **B** on 30 September 2026: the destinations move behind a
  /// control on the plate, and the bottom belongs to the composer alone.
  ///
  /// These two fields are where that decision lives, and they are the whole of
  /// it — every other arrangement considered is a change to this one call site:
  ///
  /// * **A — both, stacked.** `showNavPill: true` with a `band`. The shell
  ///   already composes the band above the pill, so A needs no other change.
  ///   It is **not** shippable as drawn: the pill's active tab takes one of
  ///   Night's two grants, leaving one for content, and the answered state
  ///   wants two (the plate's strip light and the answer's focus object). See
  ///   the census on [TheFloorScreen].
  /// * **B — what shipped.** `showNavPill: false` with a `band`, and
  ///   [FloorDestinationsButton] on the plate's top band beside the scope chip.
  /// * **C — the pill IS the composer.** `showNavPill: false` with a `band`
  ///   whose composer carries a leading grid button; the button opens
  ///   [showFloorDestinations], which already exists and is what B's plate
  ///   control opens. C is a change to the band widget alone.
  ///
  /// Whether the nav pill renders. False on The Floor proper since the
  /// composer took the bottom of the screen; true for [FirstRunBoard], which
  /// has no composer and is still a tab root.
  final bool showNavPill;

  /// Pinned above the safe area, below the scroll view. The composer.
  final Widget? band;

  /// Whether the body starts at the top edge. True for every state whose first
  /// child is the plate; see [_FloorFrame].
  final bool bleedTop;

  /// Overrides the console's own routing. Null is the real app: the bar goes
  /// where [consoleNavSelect] says, which is the only place it may go.
  final ValueChanged<int>? onSelectSlot;

  /// Overrides what the `+` circle opens. Null is the real app.
  final VoidCallback? onStandingAction;

  @override
  Widget build(BuildContext context) {
    return TorchShell(
      profile: TorchShellProfile.console,
      // The plate IS the header, so it starts at the top edge. Without this
      // the shell's 24dp console inset put a band of ground above a
      // photograph the design runs full-bleed, and spent 24dp of a 640dp fold
      // on nothing. `PlateSpec.heightFor` has always measured the full
      // viewport "including the status bar, because the plate runs full-bleed
      // to the top edge" — this is the other half of that sentence.
      bleedTop: bleedTop,
      band: band,
      navPill: !showNavPill
          ? null
          : TorchNavPill(
              slots: consoleNavSlots,
              activeIndex: ConsoleSlot.floor.index,
              onSelect:
                  onSelectSlot ?? (index) => consoleNavSelect(context, index),
            ),
      navCircle: !showNavPill
          ? null
          : TorchNavCircle(
              claimId: TheFloorScreen.navCircleClaimId,
              // The circle is the role's standing action and it is *never* lit on
              // this route: the ladder denies rung 4 once the plate has taken the
              // one content grant. Declaring `expected` honestly and letting the
              // allocator say no is the point — a circle that decided for itself
              // would be a third light.
              expected: false,
              icon: Icons.add,
              expectedIcon: Icons.add,
              semanticLabel: 'Raise a task or assign a visit',
              expectedSemanticLabel: 'Raise a task or assign a visit',
              onPressed:
                  onStandingAction ?? () => showFloorStandingAction(context),
            ),
      children: children,
    );
  }
}

/// THE STANDING ACTION'S TWO VERBS.
///
/// **THE FLOOR ITSELF NO LONGER OPENS THIS**, since 30 September 2026. The
/// circle sat *in* the nav row and left with it when the composer took the
/// bottom of the screen; the two verbs are two rows in
/// [showFloorDestinations] now, leading to the same two routes. This sheet is
/// still live for [FirstRunBoard], which has no composer, keeps its nav pill
/// and keeps its circle.
///
/// The circle's own label has always promised "Raise a task or assign a
/// visit", and `surface-manager.json` says in as many words that tapping it
/// opens exactly that pair. It opened nothing. A circle that names two verbs
/// and performs neither is worse than no circle: it teaches a manager that
/// the chrome on this screen is decoration.
///
/// One sheet, two rows, both to destinations that already exist. It is
/// deliberately *not* a third nav destination and deliberately not a form:
/// raising a task from a blank page is not a thing this product does — a task
/// is raised against a finding, and the finding is on the Work queue.
///
/// **Amber: none.** A menu commits nothing, and while it is up every amber on
/// the route beneath goes out (unify §1.10).
Future<void> showFloorStandingAction(BuildContext context) {
  return showTorchSheet<void>(
    context,
    builder: (sheetContext) => const FloorStandingActionSheet(),
  );
}

/// The sheet's body — public so a test can pump it without a scrim.
class FloorStandingActionSheet extends StatelessWidget {
  const FloorStandingActionSheet({super.key});

  @override
  Widget build(BuildContext context) {
    void leaveFor(String route) {
      Navigator.of(context).pop();
      context.go(route);
    }

    return TorchSheet(
      title: 'Raise a task or assign a visit',
      subtitle: 'Two ways to put somebody on a problem.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SoftRow(
            key: const ValueKey<String>('floor-standing-raise-task'),
            density: SoftRowDensity.compact,
            title: 'Raise a task',
            subtitle: 'Against a finding on the work queue',
            trailing: const SoftRowChevron(),
            onTap: () => leaveFor('/tasks'),
          ),
          SoftRow(
            key: const ValueKey<String>('floor-standing-assign-visit'),
            density: SoftRowDensity.compact,
            title: 'Assign a visit',
            subtitle: 'Send an agent to an outlet today',
            trailing: const SoftRowChevron(),
            onTap: () => leaveFor('/dispatch'),
          ),
        ],
      ),
    );
  }
}

/// THE FLOOR, ASKING. The landing screen, with the composer on it.
class _Floor extends ConsumerStatefulWidget {
  const _Floor({required this.view});

  final FloorView view;

  @override
  ConsumerState<_Floor> createState() => _FloorState();
}

/// The composer's state, and it is **the same state machine Ask runs**.
///
/// Every field below exists on `_AskState` for a reason that is written out
/// there, and none of those reasons stop being true because the transcript now
/// has a plate above it. The one-way hand-off in particular is load-bearing
/// here: when the trough takes text, the landed answer's focus object drops its
/// bloom permanently for that turn, which is what keeps the amber count at two
/// while the plate's strip light is also lit.
class _FloorState extends ConsumerState<_Floor> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  bool _typed = false;
  bool _handedOff = false;
  bool _following = true;
  int _turns = 0;
  bool _scheduled = false;

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
    final atTail =
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 24;
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

  void _pinToTail() {
    if (_scheduled || !_following) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || !_scroll.hasClients || !_following) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  /// Back to the briefing. The conversation is a session, not an archive —
  /// the same thing `AskStartOverSheet` does on the Ask route, without the
  /// sheet, because there is no header here to hang a history chip in and one
  /// tertiary button above the transcript is cheaper than a modal.
  void _clear() {
    ref.read(chatControllerProvider.notifier).clear();
    _input.clear();
    setState(() {
      _typed = false;
      _handedOff = false;
      _following = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final skin = context.skin;
    final state = ref.watch(chatControllerProvider);
    final online = ref.watch(askOnlineProvider);
    final sessionEnded = ref.watch(askSessionEndedProvider);
    final measured = view.phase == FloorPhase.measured;

    if (state.messages.length != _turns) {
      _turns = state.messages.length;
      _pinToTail();
    } else if (state.sending) {
      _pinToTail();
    }

    final last = state.messages.isEmpty ? null : state.messages.last;
    final answer = last?.role == ChatRole.assistant ? last : null;
    final toolRunning = answer != null && answer.tools.any((t) => t.ok == null);
    final focusTarget = answer == null
        ? null
        : AnswerFocusTarget.resolve(answer);

    final phase = resolveAskPhase(
      transcriptEmpty: state.messages.isEmpty,
      streaming: state.sending,
      toolRunning: toolRunning,
      typed: _typed,
      lastTurnErrored: answer?.error != null,
      hasFocusObject: focusTarget != null,
      handedOff: _handedOff,
      online: online,
      sessionEnded: sessionEnded,
    );

    // THE PLATE SHRINKS RATHER THAN LEAVES, and this boolean is the whole of
    // that move. See [_PlateFor] for the arithmetic.
    final asking = state.messages.isNotEmpty;

    // ── WHERE YOU ARE, AND WHERE ELSE YOU CAN GO — ON THE PICTURE ───────
    //
    // Top-left and top-right of the plate, which is the approved arrangement
    // and the thing the rejected screen got wrong. It put the pair on the
    // GROUND directly under the plate once a question had been asked, and a
    // bar of controls under a photographic header is a second header: the
    // screen read as two stacked ones, which is the first thing the owner
    // named.
    //
    // `spaceBetween` rather than a gap, because the two controls answer two
    // different questions and the mockup separates them to the two corners.
    // The chip stays `Flexible` and the button does not: a territory name is
    // arbitrarily long and `Menu` is four characters, so the band gives its
    // slack to the half that can use it.
    final controls = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Flexible(
          child: PlateScopeChip(
            key: const ValueKey<String>('floor-scope-chip'),
            scope: view.territoryName,
            window: view.windowLabel,
            filtered: view.isFiltered,
            onTap: () => showDashboardScope(context, ref),
            // The printed line is two facts joined by a separator, which a
            // screen reader spells as a caption. The control has to say what
            // it does.
            semanticsLabel:
                '${view.territoryName}, ${view.windowLabel}. '
                'Change the territory or the window.',
          ),
        ),
        const SizedBox(width: TiqSpace.s2),
        // ONE SIZE AT EVERY WIDTH, since 1 October 2026. The `compact` flag
        // and its 380dp threshold are gone with the printed word — the mockup
        // has no label at any width, so there is no longer a narrow phone to
        // special-case. See [FloorDestinationsButton].
        FloorDestinationsButton(
          key: const ValueKey<String>('floor-destinations'),
          onTap: () => showFloorDestinations(context, view),
        ),
      ],
    );

    return _FloorFrame(
      phase: '${measured ? 'loaded' : 'window-empty'}-${phase.name}',
      hasPlatePhoto: true,
      claims: phase.claims,
      // ON THE GROUND, NOT ON THE SCROLL VIEW. `TorchShell` gives its `band`
      // no material of its own — Ask's composer sits at the foot of a
      // transcript that has usually stopped scrolling by then, so nothing
      // showed through it and nobody noticed. This screen's list runs past the
      // fold on every populated frame, and without this the decision rows read
      // through the chip row like a printing fault. `pinned` already does
      // exactly this a few lines up in the same build method.
      band: ColoredBox(
        color: skin.palette.ground,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // THE SUGGESTIONS ARE THE AT-REST ROW ONLY. Once a turn has landed
            // the answer prints its own follow-ups inline, from the server's
            // `followUps` fence — two chip rows saying different things eight
            // dp apart is the screen asking a manager which one to believe.
            if (!asking) ...<Widget>[
              FloorSuggestionChips(
                suggestions: floorSuggestions(view),
                onAsk: _send,
                enabled: phase.canSend,
              ),
              SizedBox(height: skin.space.intraBlock),
            ],
            QuestionComposer(
              controller: _input,
              phase: phase,
              onSend: _send,
              onStop: () => ref.read(chatControllerProvider.notifier).stop(),
              onChanged: _onChanged,
              lastTurnErrored: answer?.error != null,
              // What the composer says it will ask about, from the scope the
              // plate above it is already showing.
              hint: floorComposerHint(view),
              band: _heldBand(context, phase),
            ),
          ],
        ),
      ),
      children: <Widget>[
        // 1. THE PLATE — the territory, the score, and the one strip of light.
        _FloorPlate(
          view: view,
          shrunk: asking,
          topSlot: asking ? null : controls,
        ),
        SizedBox(height: skin.space.blockGap),

        if (!asking) ...<Widget>[
          // 2. THE BRIEFING — what moved, in three one-line cards off the
          //    figures this screen already had. No heading over it.
          //
          //    AND THEN NOTHING. The space between the briefing and the chip
          //    row is the design, not a gap waiting to be filled: the list of
          //    decisions that used to stand here is on the Work queue, one tap
          //    from line one. See the note on [TheFloorScreen].
          FloorBriefingBlock(
            briefs: floorBriefing(view, ref.read(nowProvider)()),
          ),

          // THE ONE THING THE BRIEFING CANNOT SAY FOR ITSELF, and only in the
          // two states where it cannot. Renders nothing on a healthy screen.
          _ScopeNote(view: view),
        ] else ...<Widget>[
          // THE WAY BACK TO THE BRIEFING. A screen that can be asked a
          // question and not un-asked it is the same trap a scope with no
          // Clear is, and this route has carried that argument since the
          // territory filter landed.
          Align(
            alignment: Alignment.centerLeft,
            child: TorchTertiaryButton(
              key: const ValueKey<String>('floor-clear-answers'),
              label: 'Back to the briefing',
              semanticLabel: 'Back to the briefing. Clears this conversation.',
              onPressed: _clear,
            ),
          ),
          SizedBox(height: skin.space.intraBlock),
          for (var i = 0; i < state.messages.length; i++) ...<Widget>[
            if (i > 0) SizedBox(height: skin.space.blockGap),
            AnswerFocusScope(
              key: ValueKey<int>(i),
              focus: state.messages[i].focus,
              target: i == state.messages.length - 1 ? focusTarget : null,
              child: AskTurnView(
                message: state.messages[i],
                previous: i >= 2 ? state.messages[i - 2] : null,
                phase: phase,
                onAsk: _send,
              ),
            ),
          ],
        ],
      ],
    );
  }

  /// The offline or session-ended band, pinned above the composer's label —
  /// the same two states Ask has, on the same component.
  Widget? _heldBand(BuildContext context, AskPhase phase) {
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

/// THE DECISION LIST IS NOT ON THIS SCREEN, since 1 October 2026.
///
/// It was `NEEDS A DECISION` and five ranked rows under the briefing, and the
/// approved arrangement replaces one with the other rather than stacking both.
/// The screen had grown to a plate, a heading, three two-line cards, a second
/// heading, five rows, a more-row, a chip row and a composer — and the owner's
/// word for what they asked for is *simplistic*.
///
/// **Nothing became unreachable, and the three ways in are all above the
/// fold:**
///
/// 1. The briefing's first line — `Overdue work · 12` — opens `/tasks`, which
///    is the full worklist the five rows were a preview of. It carries the
///    same count, off the same `FloorView.decisions`, so the preview and the
///    list can still not disagree.
/// 2. The briefing's third line is the worst single outlet by name, and it
///    opens that decision's own route — which is exactly where tapping its row
///    went.
/// 3. `Menu` on the plate opens the destinations sheet, whose Work row prints
///    the live count beside it.
///
/// `floor_taps_test.dart` presses all three.
///
/// What is left here is the one thing the briefing genuinely cannot say about
/// itself: that the list it is counting was not scoped, because the chosen
/// territory's outlets did not arrive. The overdue line is **withheld** in
/// that state rather than zeroed (see `floorBriefing`), and a briefing one
/// line shorter with nothing said about why is the absence failing quietly.
///
/// It renders nothing at all on a healthy screen, which is most of them.
class _ScopeNote extends ConsumerWidget {
  const _ScopeNote({required this.view});

  final FloorView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = context.skin;
    final note = switch (view.scope) {
      FloorScope.pending => 'Finding the outlets in ${view.territoryName}…',
      FloorScope.failed =>
        'The outlet list for ${view.territoryName} did not load, so overdue '
            'work is not counted here. The figures above are still this '
            'territory’s.',
      _ => null,
    };
    if (note == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: skin.space.blockGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(note, style: skin.text.body.style(color: skin.palette.ink2)),
          // The coverage request is the only thing that failed, so the retry
          // is the coverage request — not the route, whose figures are fine.
          if (view.scope == FloorScope.failed)
            TorchTertiaryButton(
              key: const ValueKey<String>('floor-retry-scope'),
              label: 'Retry loading this territory’s outlets',
              onPressed: () =>
                  ref.invalidate(territoryCoverageProvider(view.territoryId!)),
            ),
        ],
      ),
    );
  }
}

/// Back to every territory, from anywhere on The Floor.
///
/// One caller now: the plate's own `All territories` button, which stands
/// beside the health line whenever a territory is chosen. There used to be a
/// second under the section marker, for the filtered-and-empty case; the
/// marker went with the decision list and the plate's button is on screen in
/// every state that one was, one block higher up.
void clearFloorTerritory(WidgetRef ref) =>
    applyTerritory(ref, ref.read(dashboardFilterProvider), allTerritoriesToken);

/// THE AVAILABILITY CARD IS GONE FROM THIS SCREEN, and the figure is not.
///
/// It was label, figure, one supporting line and a sparkline, and its own
/// `onTap` went to `/dashboard/overview`. The briefing above now carries the
/// same `snapshot.current.osaPct` against the same published 95, as line two,
/// and its card opens the same route — so the reading stayed on the fold and
/// got shorter.
///
/// What went with the card is the **sparkline** and the two supports
/// (`Coverage 79% · Price compliance 91%`). Both live on the overview the card
/// already pointed at, which is one tap from the briefing line that replaced
/// it. Keeping the card as well would have been the defect its own doc named
/// when it deleted the meter and the delta line: *the two that went are the
/// two that were saying the figure twice.* A stat card and a briefing line
/// printing one number eight dp apart is that, again.

/// The plate, wired to the territory in scope.
class _FloorPlate extends ConsumerWidget {
  const _FloorPlate({
    required this.view,
    required this.shrunk,
    required this.topSlot,
  });

  final FloorView view;

  /// Whether a question has been asked. See [_PlateFor.shrunk].
  final bool shrunk;

  /// The scope chip and the destinations control, or null once the plate has
  /// shrunk — see [_FloorState.build], which renders them under the plate
  /// instead. Passed in rather than built here because the same pair has to
  /// be one object in two places, and two constructions of "the same controls"
  /// is how they drift.
  final Widget? topSlot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // THE PICTURE IS OF THE PLACE, NOT OF A SHELF.
    //
    // It used to be the shelf photograph of the outlet at the top of the
    // decision list, resolved by photo id. Two things were wrong with that and
    // only one of them was cosmetic. The cosmetic one: the seeded photos are
    // four rows of randomly coloured blocks, so the demo dataset opened on
    // noise. The other one: a photograph of a shelf directly above a list of
    // shelf decisions is a photograph a manager can read as evidence for one
    // of them, and it was at best a specimen of a different finding.
    //
    // A view of the territory is plainly context — nobody mistakes a street at
    // sunrise for a stock count — and it earns its place by moving: change the
    // territory and the picture of the place changes with it, which is the
    // scope control demonstrating what it just did.
    //
    // ≤60 kB, LRU-cached, authed bytes. `Image.network` cannot carry the
    // bearer token on web, so bytes is also the only route that works at all.
    final picture = ref.watch(plateImageResolverProvider)(
      ref,
      view.territoryId,
    );

    return _PlateFor(
      view: view,
      shrunk: shrunk,
      topSlot: topSlot,
      image: picture.image,
      // WHAT THE PICTURE IS, CARRIED RATHER THAN ASSUMED. The plate speaks one
      // sentence about it and the sentence has to be true of the bytes above
      // it: see [_PlateFor.imageSentence].
      imageSource: picture.source,
      // THE SCOPE CONTROL, AND NOW IT LOOKS LIKE ONE.
      //
      // It was the eyebrow: the words `GAUTENG NORTH · WEEK 38` were the
      // button, because the owner's reference has no filter chrome on it. The
      // owner then met the running screen — "I wouldn't see it if I'm new on
      // the app" — so it is a chip at the top of the plate, in the app's own
      // chip grammar. The sheet behind it is unchanged: the overview's own
      // `TorchFilterRail` and territory rows, from `dashboard_filters.dart`.
      onClearTerritory: view.isFiltered ? () => clearFloorTerritory(ref) : null,
    );
  }
}

/// Split from [_FloorPlate] so the plate and its hero cluster can be built in
/// a test without a Riverpod container.
class _PlateFor extends StatelessWidget {
  const _PlateFor({
    required this.view,
    required this.image,
    this.shrunk = false,
    this.imageSource,
    this.topSlot,
    this.onClearTerritory,
  });

  final FloorView view;

  /// ── THE PLATE SHRINKS RATHER THAN LEAVES ──────────────────────────────
  ///
  /// True once a question has been asked. The manager stays in the territory
  /// they are asking about and the score they are asking about stays on screen
  /// while the answer explains it — which is the move that makes this screen
  /// The Floor rather than a chat window with a photograph on top.
  ///
  /// It is expressed as a **share of the viewport**, not as two dp constants,
  /// and the share is the mockup's own: its plate is 196px of a 649px screen
  /// at rest and 124px once answered, which is 30.2% and 19.1%. Two literals
  /// would have been right on the 844dp phone the mockup was drawn at and
  /// wrong on the 640dp one this product still supports — at 640 a fixed 254dp
  /// plate leaves 386dp for a briefing, a chip row and a composer, and the
  /// briefing loses its third line.
  ///
  /// The arithmetic goes through [PlateSpec.heightFor]'s existing `ground`
  /// parameter — *what the screen needs under the plate* — rather than a new
  /// one, because that is exactly what changes: at rest the space under the
  /// plate holds the briefing, and once a question lands it holds an answer.
  ///
  /// ```text
  ///          ground            height     what it is
  ///   844   0.70 × 844 = 591   253dp      at rest
  ///   844   0.81 × 844 = 684   160dp      answering
  ///   640   0.70 × 640 = 448   192dp      at rest
  ///   640   0.81 × 640 = 518   122dp      answering
  /// ```
  ///
  /// [PlateSpec.floorShortest] is 200 — the height under which The Floor's
  /// plate gives up its photograph for a band — and every answering height
  /// above is below it. That constant is The Floor's own and it was written
  /// for a screen whose plate was decoration above a list; on a screen where
  /// the plate is the thing the manager is holding on to while they read an
  /// answer, dropping the photograph is dropping the point. So [shortest] is
  /// passed instead, which is the parameter `PlateSpec` grew on 30 September
  /// 2026 for precisely this class of disagreement.
  ///
  /// The hero figure steps down on its own: `PlateSpec.resolve` takes the
  /// compact face under 260dp and `FigureSlot`'s fitting ladder scales from
  /// there, so the mockup's smaller `73` falls out of the existing arithmetic
  /// rather than being a second set of numbers to keep in step.
  final bool shrunk;

  final ImageProvider<Object>? image;

  /// What [image] is, from the server's `X-Image-Source`. Null when nothing
  /// said — see [imageSentence].
  final PlaceImageSource? imageSource;

  /// THE ONE SENTENCE A READER IS GIVEN ABOUT THE PICTURE, AND IT HAS TO BE
  /// TRUE OF THE PICTURE.
  ///
  /// Two clauses, and only the first one moves:
  ///
  /// * **What it is.** `generated` is an illustration a model drew;
  ///   `supplied` is a photograph the owner handed over. This clause was
  ///   hardcoded to "An illustration of the area" while every seeded picture
  ///   was generated, and went false on 29 September 2026 the moment twelve
  ///   territories got real photographs. A screen reader saying "illustration"
  ///   over a photograph of the Union Buildings is not a smaller error than
  ///   the other way round — it is the same error, and this screen exists to
  ///   refuse it in both directions.
  /// * **What it is not.** *Not from a visit.* This clause does not move,
  ///   because it is not a fact about how the picture was made. It is a fact
  ///   about which table it lives in: `place_images` has no `visitId`, no GPS
  ///   tag and no capture time, and a photograph of Bloemfontein is still not
  ///   a reading of a shelf in it. A real photograph is if anything MORE
  ///   mistakable for evidence than a drawing, so this is the clause that
  ///   earns its place hardest now.
  ///
  /// A source nobody stated gets neither claim. It says the origin is
  /// unstated, which is the only true thing left to say — defaulting to either
  /// word would put an assertion on screen that nothing backs.
  String imageSentence(BuildContext context) {
    final place = view.territoryName;
    return switch (imageSource) {
      PlaceImageSource.generated => context.l10n.plateImageGenerated(place),
      PlaceImageSource.supplied => context.l10n.plateImageSupplied(place),
      null => context.l10n.plateImageUnattributed(place),
    };
  }

  /// Back to all territories in one tap. Null when nothing is filtered —
  /// a Clear that clears nothing is chrome, and this screen has none to
  /// spare.
  final VoidCallback? onClearTerritory;

  /// THE TOP BAND'S CONTROLS, OR NULL ONCE THE PLATE HAS SHRUNK.
  ///
  /// ## Why there is a height at which they are not drawn at all
  ///
  /// `TiqPlate`'s own doc has always said the top slot "never reaches the light
  /// itself, which is the object the amber budget is spent on" — and at the
  /// answering height that stopped being true. The slot is a 44dp tap target
  /// 16dp from the top edge, so it occupies y=16..60 whatever the plate's
  /// height is, while the strip light rides at 0.38h: at 122dp that is y=46,
  /// underneath the chip.
  ///
  /// The amber census is what caught it, and caught it as an over-claim rather
  /// than as an ugly frame: the controls painted over the middle of the strip
  /// light and left its two ends showing, so one lit object was counted as
  /// **two** and the answered state came to three against a budget of two.
  ///
  /// ## The repair is a measured clearance, not a second place to stand
  ///
  /// The first fix put the pair on the ground under the shrunken plate. That
  /// is what the owner rejected as a second header, so it is gone and the rule
  /// is now the one thing that was actually true underneath it: **the controls
  /// ride the picture at every height where they clear the light, and the
  /// plate is never given a top slot at a height where they do not.**
  ///
  /// [PlateSpec.topSlotRoom] is that clearance as a number, and
  /// `floor_proportion_test.dart` measures the drawn control against it on
  /// both supported phones rather than trusting this paragraph. At rest the
  /// plate is 30% of the viewport — 253dp at 844, 192dp at 640 — so the light
  /// is at y=96 and y=73 and a one-line control ending at y=60 clears both.
  /// At 360dp it only clears because [FloorDestinationsButton.compact] drops
  /// the word `Menu`, which is why that fix is load-bearing rather than
  /// cosmetic.
  ///
  /// Nothing is lost while answering. The approved mockup draws the shrunken
  /// plate with no control on it, and `Back to the briefing` — directly above
  /// the transcript, in every answered frame — is one tap back to the state
  /// that has both.
  final Widget? topSlot;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final snapshot = view.snapshot;
    final current = snapshot.current;
    final measured = view.phase == FloorPhase.measured;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final ground = TheFloorScreen.plateGroundFor(
      viewportHeight,
      shrunk: shrunk,
    );
    final spec = PlateSpec.resolve(
      skin: skin,
      viewportHeight: viewportHeight,
      ground: ground,
      shortest: TheFloorScreen.plateShortest,
    );

    final delta = snapshot.of((k) => k.executionScore);
    final n = current.sampleSizes.executionScore;
    final baselineN = snapshot.previous?.sampleSizes.executionScore;
    final lowSample = TiqSample.isLow(MetricKind.score, n);

    final figureState = !measured
        ? FigureState.missing
        : lowSample
        ? FigureState.lowSample
        : FigureState.measured;

    return TiqPlate(
      claimId: TheFloorScreen.plateClaimId,
      viewportHeight: viewportHeight,
      // The same two numbers the spec above was resolved with. They are passed
      // twice because `TiqPlate` resolves its own spec for the paint and this
      // one is read for `figureRole`; handing the widget different numbers
      // from the ones the hero was sized against is how a plate ends up with
      // a figure fitted to a height it does not have.
      ground: ground,
      shortest: TheFloorScreen.plateShortest,
      image: image,
      // Null, not the string: the reference has no caption line, so what the
      // picture is goes in [semanticLabel] below.
      caption: null,
      // Never a stock image and never a gradient pretending to be a
      // photograph: a drawing that is visibly a drawing, and a sentence.
      //
      // AND NEVER A GENERATED PICTURE EITHER. This is the one place a made-up
      // image would be easiest to reach for and the one place it is forbidden:
      // a picture standing in for a picture that is missing is an invention
      // presented as a state of the world. The sentence names the scope, so a
      // manager can tell "this territory has no picture" from "everywhere has
      // none".
      fallbackSentence: view.territoryId == null
          ? 'No picture of your territories yet.'
          : 'No picture of ${view.territoryName} yet.',
      // WHAT IT IS, AND THAT IT IS NOT EVIDENCE. A reader of the screen is
      // told which kind of picture this is rather than left to assume — this
      // plate used to carry a shelf from a named outlet, and the sentence that
      // replaced it has to close that reading rather than go quiet. See
      // [imageSentence], which is why the sentence is built from the server's
      // mark instead of being typed here.
      semanticLabel: imageSentence(context),
      // THE SCOPE CONTROL, AT THE TOP OF THE PLATE — visible, 48dp, and
      // carrying the two facts it sets. See [PlateScopeChip].
      // THE TOP BAND CARRIES TWO CONTROLS NOW: where you are, and where else
      // you can go. Both wear a `surface`, so neither is ink on a photograph —
      // see [FloorDestinationsButton] for the measurement that makes that a
      // requirement rather than a preference.
      //
      // The chip is `Flexible` and the button is not: a territory name is
      // arbitrarily long and `Menu` is four characters, so the band gives its
      // slack to the half that can use it. `PlateScopeChip` wraps to two lines
      // rather than ellipsising, which is its own stated rule — a scope you
      // cannot read is a scope you cannot trust.
      topSlot: topSlot,
      hero: PlateHeroCluster(
        // No eyebrow: the chip above prints the territory and the window, and
        // a card that names the territory twice is a card with one line spent
        // on nothing.
        // THE WAY BACK, ON THE ONE ROW THAT HAS SPACE FOR IT. It appears only
        // when a territory is chosen: a Clear that clears nothing is chrome,
        // and this screen has none to spare.
        healthTrailing: onClearTerritory == null
            ? null
            : TorchTertiaryButton(
                key: const ValueKey<String>('floor-plate-clear-territory'),
                label: 'All territories',
                semanticLabel: 'Show all territories',
                onPressed: onClearTerritory,
              ),
        figure: FigureSlot(
          value: measured ? current.executionScore : null,
          // THE HERO SAYS WHETHER 73 IS GOOD NEWS.
          //
          // Territory health is the execution score, and the execution score
          // is measured against a published 75 on the overview this figure
          // opens. Until 28 September 2026 the only thing on the plate that
          // carried a verdict was the delta — which says whether the number
          // *moved*, not whether it is *where it should be*. A score can fall
          // nineteen points and still be fine, and rise two and still be a
          // gap; the two marks answer two questions and the screen was only
          // answering one.
          //
          // The word is in the semantics: the health line and the delta
          // sentence both name the standing, and the hero is `hero.figure` at
          // 72px, which is large text at a 3:1 floor — measured against the
          // worst pixel the plate's scrim can produce on either ground and
          // declared in `tiq_contrast.dart`.
          //
          // NIGHT NO LONGER COLOURS IT, from 29 September 2026, and it is
          // [FigureRank.row] rather than a headline on purpose. §16.2 has
          // ruled since the visit outcome shipped that a hero is ink-1 at
          // every band — "a severity-coded figure at 72px is a hue doing a
          // number's job, and it is the one object on the screen large enough
          // that its colour reads as the whole message" — and the artifact
          // agrees: its hero `72` is bone while the `▼ 19` beside it is
          // crimson. On Day it still takes its verdict's ink, and that is what
          // the two plate-hero pairings in `tiq_contrast.dart` measure.
          //
          // THE STANDING DID NOT GO WITH THE COLOUR. Taking the hue off the
          // hero would have left the plate stating only the *movement* — and
          // the paragraph above is the argument that movement and standing are
          // two different questions. So the health line names the standing in
          // words now; see [_healthLine] below.
          color: standingInk(
            skin,
            measured
                ? againstStandard(current.executionScore, executionScoreTarget)
                : null,
            state: figureState,
          ),
          role: spec.figureRole,
          fit: <TiqTypeToken>[
            spec.figureRole,
            skin.text.heroFigureCompact,
            skin.text.display,
          ],
          // A TERRITORY-HEALTH SCORE IS A WHOLE NUMBER. It is 73 on the
          // scorecard, 73 in the answer, 73 in the report — and it was 72.9
          // here, because with no declared precision `TiqNumber` keeps one
          // place and the server sends a double. The precision is a property
          // of the metric, so the screen declares it; the formatter still
          // prints whatever the server says the moment `decimals` reaches the
          // wire for this figure, and nothing rounds inside the widget.
          decimals: 0,
          state: figureState,
          semanticsLabel: measured
              ? null
              : 'Territory health, no visits in this window',
        ),
        // THE HERO'S DELTA — the half of the hero that says whether the
        // number is moving, and the half that was missing from the running
        // screen. Severity-coloured, never amber.
        //
        // It was absent for one reason and would have gone absent for a
        // second. First, the screen only built a `DeltaData` when
        // `KpiDelta.hasDelta` was true, and that getter is false for a change
        // under 0.05 *and* for the case that actually bites: `previous` is
        // null whenever the comparison window does not exist or its request
        // did not come back, which is every All-time filter and every flaky
        // morning. `DeltaSlot` then renders nothing, and the hero stands
        // alone. Second, a movement of 0.02 pts is a real comparison and it
        // was being thrown away rather than printed flat.
        //
        // So: a delta is built whenever there is a window to compare against,
        // flat included, and the no-comparison case says so in words on the
        // figure's own baseline instead of leaving the hole the mockup fills
        // with `▼ 19`. The suppressed cases keep their own sentences —
        // `DeltaSlot` still removes the delta outright beside an em dash,
        // because a delta never stands beside nothing.
        delta: DeltaSlot(
          data: delta.change == null
              ? null
              : DeltaData(
                  direction: delta.change! >= 0.05
                      ? DeltaDirection.up
                      : delta.change! <= -0.05
                      ? DeltaDirection.down
                      : DeltaDirection.flat,
                  sentiment: delta.change! >= 0.05
                      ? TiqSentiment.good
                      : delta.change! <= -0.05
                      ? TiqSentiment.bad
                      : TiqSentiment.neutral,
                  magnitude: delta.change!.abs(),
                  // NO UNIT. `▼ −19 pts` was the running screen and the owner
                  // read all three of its parts as one: the triangle says
                  // down, so the minus is the same word twice (fixed in
                  // `Delta` itself, for every screen), and `pts` is the unit
                  // of a score printed beside a score — the figure above it
                  // has no suffix either, because a territory-health number
                  // is not measured in anything else. The reading is `▼ 19`.
                  //
                  // The word is not lost, it moves to where a unit belongs on
                  // a mark this small: the semantics label below says "points"
                  // in a sentence, so nothing that reads the screen has to
                  // infer it from a triangle.
                ),
          figureState: figureState,
          sampling: FigureSampling(
            kind: MetricKind.score,
            n: n,
            baselineN: baselineN,
          ),
          compact: true,
          noComparisonNote: measured ? 'no window before this one' : null,
          // Direction word, magnitude, unit, baseline, verdict — in that
          // order, which is `Delta`'s own contract for this string. Colour is
          // never the only carrier and now neither is the triangle.
          semanticsLabel: delta.change == null
              ? null
              : _heroDeltaSentence(context, delta.change!),
        ),
        healthLine: _healthLine(
          skin,
          context.l10n,
          measured
              ? againstStandard(current.executionScore, executionScoreTarget)
              : null,
        ),
        // The decomposition: what the composite figure is made of. A
        // composite number nobody can open is a number you cannot act on.
        onHealthTap: () => context.go('/dashboard/overview'),
      ),
    );
  }

  /// `Territory health` — and, since 29 September 2026, the standing after it.
  ///
  /// The label was `Territory health` alone while the hero carried its verdict
  /// in crimson. Night stopped colouring the hero that day, so the plate would
  /// otherwise have been left stating only the *movement*: the delta says the
  /// score fell nineteen points, which is not the same claim as "it is under
  /// the published 75" and can be true when the other is false.
  ///
  /// So the word moved onto the plate from the semantics label, where it was
  /// already required and where only a screen reader could reach it. It is
  /// `Below the standard` / `Close to the standard` / `On the standard` — the
  /// same three strings every other standing in the console prints, from
  /// [standingWord], so the plate and the overview say a gap the same way.
  ///
  /// It stays ink-2 and it is never coloured. A severity word in severity ink
  /// beside a figure in plain ink is two severity systems on one plate; §16.2
  /// gives the word to the *mark* and the ink to nothing here, and the delta
  /// beside the figure is the mark.
  static Widget _healthLine(
    TiqSkin skin,
    AppLocalizations l10n,
    StatusLevel? standing,
  ) => Text(
    standing == null
        ? 'Territory health'
        : 'Territory health · ${standingWord(l10n, standing)}',
    style: skin.text.label.style(color: skin.palette.ink2),
  );

  /// "Down 19 points against the window before, which is bad."
  ///
  /// Direction word, magnitude, unit, baseline, verdict — [Delta]'s own
  /// stated order for this string. It exists because the printed mark is now
  /// a triangle and a bare number: the word "points" and the word "bad" are
  /// both in here, so neither the unit nor the verdict is carried by a
  /// colour or by a shape alone.
  static String _heroDeltaSentence(BuildContext context, double change) {
    final size = change.abs();
    // The same figure the mark prints, in the reader's own locale: `Delta`
    // passes no `decimals`, so the formatter keeps up to one place and drops a
    // trailing zero, and `TiqNumber.of` is what makes 1,5 a comma in
    // Afrikaans rather than a format string's full stop.
    final magnitude = TiqNumber.of(context).format(size);
    if (change > -0.05 && change < 0.05) {
      return 'Level against the window before.';
    }
    final up = change >= 0.05;
    return '${up ? 'Up' : 'Down'} $magnitude points against the window '
        'before, which is ${up ? 'good' : 'bad'}.';
  }
}

class _FloorSkeleton extends StatelessWidget {
  const _FloorSkeleton();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final height = PlateSpec.heightFor(MediaQuery.sizeOf(context).height);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // The skeleton is the real geometry, empty — not a spinner, and not a
        // `well` block at 1.12:1 that nobody can see. Real geometry now means
        // the card's corners too: a square block that resolves into a rounded
        // one is a layout shift dressed as a loading state.
        DecoratedBox(
          decoration: BoxDecoration(
            color: skin.palette.edgeStructure,
            borderRadius: BorderRadius.circular(skin.radii.plate),
          ),
          child: SizedBox(height: height < 200 ? 96 : height),
        ),
        const SizedBox(height: TiqSpace.s5),
        for (var i = 0; i < 3; i++) ...<Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: skin.palette.edgeStructure,
              borderRadius: BorderRadius.circular(skin.radii.card),
            ),
            child: const SizedBox(height: TiqSpace.s9),
          ),
          const SizedBox(height: TiqSpace.s3),
        ],
      ],
    );
  }
}

class _FloorError extends StatelessWidget {
  const _FloorError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Padding(
      padding: EdgeInsets.all(skin.space.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'The floor could not be loaded.',
            style: skin.text.titleM.style(color: skin.palette.ink1),
          ),
          const SizedBox(height: TiqSpace.s3),
          Text(
            'Nothing here is a zero — the figures simply did not arrive.',
            style: skin.text.body.style(color: skin.palette.ink2),
          ),
          const SizedBox(height: TiqSpace.s4),
          Semantics(
            button: true,
            label: 'Retry',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRetry,
              child: SizedBox(
                height: skin.space.tapTarget,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Retry',
                    style: skin.text.label.style(color: skin.palette.ink1),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
