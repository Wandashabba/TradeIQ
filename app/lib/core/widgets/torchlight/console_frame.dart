import 'package:flutter/widgets.dart';

import '../../design/torch_scope.dart';
import '../../theme/torchlight/tiq_skin.dart';
import '../../../features/assistant/answer/ask_light.dart' show AskLight;
import 'chrome/chrome.dart';
import 'console_desk.dart';
import 'sheet.dart';

/// THE CONSOLE'S FRAME, for every manager route that is not The Floor.
///
/// It is the three things §12.6 asks a migrating screen to do, in one place:
/// the route's [TorchScope] with its declared claims, the [TorchShell] in its
/// console profile, and — since 2 October 2026 — **the ask bar**.
///
/// ## MODEL 1: ONE OBJECT AT THE BOTTOM, AND THE PILL IS GONE
///
/// > *"it becomes very weird especially knowing that the app is a search
/// > based, I don't know how to navigate with this one please help make it
/// > seamless"* — the owner, on the four-tab pill.
///
/// The diagnosis was never styling. **The bottom of the screen meant two
/// different things.** The Floor had a composer and no pill; the 27 routes
/// framed here had a pill and no composer; Ask had both. So the way you
/// navigated changed depending on where you were standing, on a product whose
/// primary verb is *ask*.
///
/// Now every console screen ends in the same row:
///
/// ```text
///   [ grid ]  [ the ask field …………………… ]  [ send ]
/// ```
///
/// The grid opens [showFloorDestinations] through [ConsoleAskBar] — the sheet
/// that already existed and that The Floor's plate control already opened, now
/// carrying the folding menu, so navigation is one gesture and it is the same
/// gesture everywhere. This is arrangement **C** from the seam note on
/// `FloorScaffold`, which named it and shipped **B** instead. C's claim there
/// that it is "a change to the band widget alone" was true of The Floor only;
/// extending it to the console is the larger part and it is this file.
///
/// ## What it costs, stated rather than buried
///
/// **There is no longer a persistent "you are here" indicator.** The active
/// tab was one, and it is gone. That is correct for a chat-first app — a tab
/// strip that is 3/4 wrong at all times is a poor use of 64dp — and it is a
/// real loss, which now rests entirely on each screen's own
/// [TorchAppHeader] title. Every route framed here passes one.
///
/// ## The amber arithmetic, re-run
///
/// The nav's active tab was **slot 1 whenever the nav rendered**, and it is
/// gone, so [navRenders] is false and the allocator no longer adds
/// [TorchScope.navActiveTabId] at rung 0. In its place this frame declares
/// Send at rung 1. Measured, per skin, on these routes:
///
/// | frame | before | after | budget |
/// |---|---|---|---|
/// | console · Night · loaded | 1 (nav tab) | 1 (Send) | 2 |
/// | console · Night · loading / empty / error | 1 (nav tab) | 1 (Send) | 2 |
/// | console · Day · any phase | 0 | **1** (Send) | 1 |
/// | console · beneath a sheet | 0 | 0 | — |
///
/// **Night is unchanged in count and better in kind** — the grant moved off
/// chrome and onto the one control on the screen that commits something — and
/// the free content grant is still one. **Day goes 0 → 1, and that is an
/// honest increase**: the nav tab was never amber on a light ground
/// ([TorchDenial.notAmberOnLightGround]) and a primary commit block is. It is
/// inside the budget of one and it is the first amber those 27 screens have
/// ever painted on paper. The reduction the change was expected to produce
/// lands on **Ask**, not here: Ask carried the nav tab *and* Send, so it goes
/// 2 → 1 on Night and gets a grant back.
///
/// ## The one screen where the bottom is still two objects
///
/// Messages declares `TorchPrimaryButton.claim(messageSendClaimId)` for its
/// own team-message composer. Two primary commits on one route is an
/// over-claim on Day and the ladder is right about that: the expected next
/// move when you have written a message is to send **that**. So the ask bar's
/// Send claims rung 1 only on a route that declares no primary of its own —
/// see [_claims] — and on Messages it takes `AskLight.send`'s
/// granted-but-unlit form instead. It still sends, and the grid still
/// navigates; it is simply not the screen's light while a draft is standing.
///
/// ## While a sheet is up
///
/// Every amber beneath it goes out: [TorchSheetAware] is what wires that, so
/// Send drops to its ink form and the sheet's own scope owns the frame.
class ConsoleFrame extends StatelessWidget {
  const ConsoleFrame({
    super.key,
    required this.phase,
    required this.children,
    this.header,
    this.claims = const <TorchClaim>[],
    this.scrollController,
    this.band,
    this.askHint,
    this.desk,
  });

  /// `loading`, `loaded`, `empty`, `filtered-empty`, `error`. Resolution
  /// happens once per route × phase, never per frame.
  final String phase;

  /// The body. Gutter-padded by the shell; a row list opts back out through
  /// `TorchBleed`.
  final List<Widget> children;

  final Widget? header;

  /// Almost always empty — see the class comment.
  final List<TorchClaim> claims;

  final ScrollController? scrollController;

  /// A pinned region **above** the ask bar. Messages' team composer is the one
  /// user, and it is the one screen whose bottom is two objects rather than
  /// one — see the class comment.
  ///
  /// The ask bar is always last, because it is the console's chrome and chrome
  /// does not move: a grid button that was sometimes the bottom-left corner
  /// and sometimes 90dp up it would be the original defect in miniature.
  final Widget? band;

  /// ── THE HINT, AND WHY THERE ARE ONLY TWO OF THEM ──────────────────────
  ///
  /// What the field says it will answer about. Null prints `Ask TradeIQ…`,
  /// which is what **25 of the 27** routes framed here pass.
  ///
  /// Per-screen copy for all 27 was considered and declined. A hint is a
  /// promise about what the assistant can answer, and the assistant's
  /// coverage is not a function of which console screen you happen to be
  /// reading — it is the same tools and the same tenant from everywhere. So a
  /// hint is only worth printing where the screen's subject is a thing a
  /// manager actually asks about in those words, and inventing 27 of them
  /// would be 25 promises the product cannot keep differently.
  ///
  /// Two pass one: Tasks (`Ask about your tasks…`) and Territories
  /// (`Ask about your territories…`) — and the second is not invented either,
  /// it is the exact string `floorComposerHint` already prints on an
  /// unfiltered Floor.
  final String? askHint;

  /// ── THE DESK, ON A ROUTE THAT IS A LIST OF RECORDS ───────────────────
  ///
  /// Null on 23 of the 24 destinations, and **null is not "no desktop
  /// layout"**: above [ConsoleDesk.isDesk] a route with no desk still gets the
  /// rail and one centred column, which is the right shape for a scorecard, a
  /// settings form, a chart dashboard or a chat and costs those screens no
  /// diff at all.
  ///
  /// What passing one buys is the **third pane**. A route that is a list of
  /// records hands over its records, its filter rail and the blocks above the
  /// list; the frame owns the selection, the panes and the motion. See
  /// `console_desk.dart`.
  final ConsoleDeskRecords? desk;

  /// The route's full claim set. See the class comment's table, and the
  /// Messages paragraph for the one condition.
  List<TorchClaim> _claims() {
    final hasOwnPrimary = claims.any(
      (c) => c.kind == TorchClaimKind.primaryCommit,
    );
    return <TorchClaim>[
      ...claims,
      if (!hasOwnPrimary)
        const TorchClaim.primaryCommit(AskLight.sendClaimId),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final askBar = ConsoleAskBar(hint: askHint);
    return TorchSheetAware(
      builder: (context, beneathSheet) => TorchScope(
        skin: skin,
        phase: phase,
        // THE NAV PILL IS GONE FROM THE CONSOLE, and with it the one amber
        // grant that chrome was taking. `tabbedRoute` goes with it: these
        // routes are not tabs any more, they are destinations off one menu.
        navRenders: false,
        tabbedRoute: false,
        beneathSheet: beneathSheet,
        claims: _claims(),
        // ── THE SELECTION LIVES ABOVE THE BREAKPOINT BRANCH ──────────────
        //
        // `ConsoleDeskScope` is outside the `LayoutBuilder` on purpose: the
        // two arms are different widget types, so a window dragged across the
        // threshold unmounts one element tree and mounts the other, and a
        // `State` held inside the branch would lose the selected record on the
        // way past. Mounted at every width, it does not — drag narrow and back
        // and the same record is still open, having asked the network nothing.
        //
        // It costs one `StatefulWidget` on the 23 routes that never select
        // anything, which is one element and no paint.
        child: ConsoleDeskScope(
          builder: (context, selection) => LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              // An unbounded height is not a tall viewport, it is no viewport:
              // the panes are `Expanded` against a free height and there is
              // none to divide. `EntryFrame` guards the same way, for the same
              // reason — degrade to the phone shape rather than to an infinite
              // constraint.
              if (constraints.hasBoundedHeight &&
                  ConsoleDesk.isDesk(skin, size)) {
                return TorchShell(
                  profile: TorchShellProfile.console,
                  desk: ConsoleDeskBody(
                    header: header,
                    askBar: askBar,
                    records: desk,
                    selection: selection,
                    scrollController: scrollController,
                    children: children,
                  ),
                  // The shell's own body list is empty and the desk is the
                  // body. See `TorchShell.desk`.
                  children: const <Widget>[],
                );
              }

              // ── THE PHONE ARM, UNCHANGED ────────────────────────────────
              //
              // Not a narrower desk: the tree this frame built before
              // `console_desk.dart` existed, line for line. `band`, the ask
              // bar, the header, the children and the gutter are all where
              // they were, and `console_desk_test.dart` asserts at 390×844 and
              // 360×640 that no rail and no pane is in the tree at all.
              return TorchShell(
                profile: TorchShellProfile.console,
                header: header,
                scrollController: scrollController,
                band: band == null
                    ? askBar
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          band!,
                          SizedBox(height: skin.space.intraBlock),
                          askBar,
                        ],
                      ),
                children: children,
              );
            },
          ),
        ),
      ),
    );
  }
}
