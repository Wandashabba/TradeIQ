import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../../auth/session_controller.dart';
import '../../design/motion_budget.dart';
import '../../theme/theme_mode_controller.dart';
import '../../theme/torchlight/tiq_skin.dart';
import '../nav_destinations.dart';
import 'button/buttons.dart';
import 'marks.dart';
import 'row/row.dart';
import 'section_rule.dart';
import 'sheet.dart';

/// THE MENU — the console's DESTINATIONS, as the one modal container.
///
/// Every destination the manager has, grouped by the verb it serves, and under
/// them the housekeeping that has nowhere else to live on a phone: the app's
/// brightness, the password, and the way out.
///
/// ## IT IS NOT AN OVERFLOW ANY MORE — 2 October 2026
///
/// It was "every destination that does not fit the four slots", reached from
/// the nav pill's fourth tab. There is no pill: the bottom of every console
/// screen is one bar, and the grid button at its leading end opens this
/// (through `showFloorDestinations`, which adds two lead rows). So this sheet
/// is no longer the leftovers — **it is the whole list**, and it is reached by
/// the same gesture from all 29 console screens rather than from one tab on
/// 27 of them.
///
/// Two things follow and both are in the copy. `menuSubtitle` read "Everything
/// the four tabs do not hold" and now reads "Everywhere you can go from here",
/// because the old sentence became false rather than merely dated. And the
/// list is no longer edited against what the four slots already carry: The
/// Floor and Tasks are in it on their own merits, which is why
/// `showFloorDestinations` puts them at the top under "Where you were".
///
/// It reads [managerDestinations] rather than keeping a second list — a
/// destination added there appears here at once. **It is the only reader of
/// that list in `lib/`**; see the note under "What the list actually feeds"
/// below, because the list's own doc comment says otherwise and is wrong.
///
/// ## It folds shut — 2 October 2026
///
/// > *"Lets go for D and decrease font size and make fit nicely on phone"* —
/// > the owner, shown ten mockups of this sheet and picking the accordion.
///
/// There are **24 destinations** (Operate 9, Insight 8, Configure 7). Flat,
/// every one of them was a 68dp card and the sheet was **2,132dp** of content
/// behind a 743dp window — measured, not estimated, by
/// `menu_sheet_fold_test.dart`, which prints both numbers and is the reason
/// they are quotable. A manager opening the menu to reach Users scrolled past
/// nineteen things first.
///
/// So the three groups collapse to **one row each**. At rest the sheet is
/// three group rows, two housekeeping rows and the way out; tapping a group
/// opens it in place, and the group holding the route you are on is open when
/// the sheet appears.
///
/// **One group at a time.** The sheet exists to be short, and that is the
/// whole of the argument: with several groups open a manager can rebuild the
/// 2,132dp scroll by accident, and the thing this sheet is for — picking one
/// destination — never needs two groups side by side. Comparing groups is a
/// use nobody has; a sheet that stays short is one everybody has.
///
/// **"This app" stays flat.** A fourth fold would be consistent and it would
/// bury Sign out, which is the one irreversible thing in here, two taps deep
/// behind a row that does not say so. Findability beats consistency for the
/// control you reach for when something is wrong, so the brightness, the
/// password and the way out stay where they were, under their own marker, at
/// the bottom where they have always been.
///
/// **The icons are drawn.** Every [NavDestination] has carried an `icon` all
/// along and this sheet rendered none of them, which is why the flat list read
/// as an undifferentiated stack you had to *read* rather than scan. They cost
/// no new data and they are the largest legibility gain available here.
///
/// **No counts were invented.** The number on a group row is
/// `destinationsIn(group).length` — a `const` list's length, already in hand.
/// There is no per-destination badge, because every one of those would be a
/// network call bolted to a navigation sheet.
///
/// ## Amber: none
///
/// A menu commits nothing. The sheet declares no claims, and while it is up
/// every amber on the route beneath it is extinguished (unify §1.10), so the
/// nav tab under the scrim drops to its ink form.
///
/// The fold gave this sheet two new states that *want* to be lit and are not:
/// the open group and the row you are standing on. Both are drawn in **weight,
/// ink and fill** — `body.strong` over `body`, `ink1` over `ink2`, a `surface`
/// box where the siblings have none. The census stays at **0 lit objects in
/// both skins, collapsed and expanded**, which leaves the whole 2/1 budget
/// unspent; see `menu_sheet_test.dart`. Weight costs nothing and survives
/// greyscale, which amber does not.
///
/// ## What the list actually feeds
///
/// `nav_destinations.dart` says "the sidebar, the floating bottom bar's Menu
/// sheet, and the router guard all read THIS list". Two thirds of that is
/// untrue as of 2 October 2026 and the comment has been corrected there:
///
/// * **The sidebar does not exist.** `ManagerScaffold`'s `_NavRail` did read
///   the list, and was deleted in `9985dd6b` ("retire eight dead widget
///   files", 25 September 2026). Manager nav is now
///   `consoleNavSlots` in `console_frame.dart` — four hardcoded slots.
/// * **The router guard has never read it.** `app_router.dart` keeps its own
///   `const managerOnly` set of 19 routes against this list's 24, and
///   `git log -S managerDestinations` on that file is empty. Seven
///   destinations here are unguarded (`/assistant`, `/beatplans`,
///   `/dashboard/overview`, `/leaderboard`, `/messages`, `/orders`,
///   `/outlets`), three of them deliberately per that file's own comment and
///   the rest unexplained. **Not fixed here** — a role-guard change is not a
///   menu redesign — but it is written down now instead of being implied
///   false.
///
/// ## It is one sheet, not two
///
/// This replaces `nav_menu_sheet.dart`'s glass sheet **and** the plain
/// `showConsoleMenu` that the Torchlight console frame shipped with. The two
/// had drifted into different menus for the same nav: the glass one carried
/// the theme toggle and Sign out and the Torchlight one carried neither, so a
/// manager whose route had been migrated could no longer sign out of the app
/// from their phone. That is the third capability this project has lost to a
/// migration, and the reason there is now one function and a test that presses
/// Sign out.
///
/// [lead] is put above the grouped destinations, and exists for exactly one
/// caller: The Floor, which gave up its nav pill on 30 September 2026 so the
/// composer could have the bottom of the screen, and puts the two slots it lost
/// here with their own live numbers on them. It is **not** a second destination
/// list — everything below it is still `managerDestinations`. It does **not**
/// fold: it is contextual, it is already two rows, and it carries live figures
/// that are the reason it was put in front of the list in the first place.
Future<void> showTorchMenuSheet(
  BuildContext context, {
  List<Widget> lead = const <Widget>[],
}) {
  // WHERE WE ARE IS READ HERE, AT THE CALL SITE, and handed to the sheet.
  //
  // `showTorchSheet` pushes on the **root** navigator, so the sheet's own
  // context sits outside the `GoRoute` subtree that carries the match — which
  // is the trap `agent_scaffold.dart` documents in full: `GoRouterState.of`
  // throws there rather than missing. This call is still inside the route that
  // is asking for the menu, which is the one place the question has an answer.
  return showTorchSheet<void>(
    context,
    builder: (sheetContext) =>
        _MenuSheet(lead: lead, currentRoute: currentMenuLocation(context)),
  );
}

/// The current location, or null if nobody can say.
///
/// `GoRouter.of` reads `InheritedGoRouter`, which the delegate puts **above**
/// the navigator, so this answers from inside a route and from a modal pushed
/// over one alike. It still catches: a widget test may pump [MenuSheetBody]
/// with no router at all, and a menu that throws because it could not find out
/// which row to embolden would be a navigation sheet broken by a decoration.
@visibleForTesting
String? currentMenuLocation(BuildContext context) {
  try {
    return GoRouter.of(context).state.uri.path;
  } on Object {
    return null;
  }
}

/// The destination [location] is sitting on, by **longest** matching route.
///
/// Longest rather than first, because `/dashboard/overview` starts with
/// `/dashboard` and the answer there is Execution overview, not The Floor. A
/// sub-route counts as its parent — `/contests/42` is Contests — which is what
/// makes the right group open when a manager opens the menu from a detail
/// screen. Null for a location that is not a destination at all, such as
/// `/account/password`: nothing opens, and guessing would be worse than
/// nothing.
@visibleForTesting
NavDestination? menuDestinationFor(String? location) {
  if (location == null || location.isEmpty) return null;
  NavDestination? best;
  for (final d in managerDestinations) {
    final matches = location == d.route || location.startsWith('${d.route}/');
    if (!matches) continue;
    if (best == null || d.route.length > best.route.length) best = d;
  }
  return best;
}

/// The sheet's body — public to the library so a test can pump it directly
/// rather than through a nav bar and a scrim.
@visibleForTesting
class MenuSheetBody extends StatelessWidget {
  const MenuSheetBody({
    super.key,
    this.lead = const <Widget>[],
    this.currentRoute,
  });

  /// See [showTorchMenuSheet].
  final List<Widget> lead;

  /// The location to treat as current. Null — the default — opens no group and
  /// emboldens no row, which is the resting frame a collapsed-state test wants.
  final String? currentRoute;

  @override
  Widget build(BuildContext context) =>
      _MenuSheet(lead: lead, currentRoute: currentRoute);
}

class _MenuSheet extends ConsumerStatefulWidget {
  const _MenuSheet({this.lead = const <Widget>[], this.currentRoute});

  final List<Widget> lead;
  final String? currentRoute;

  @override
  ConsumerState<_MenuSheet> createState() => _MenuSheetState();
}

class _MenuSheetState extends ConsumerState<_MenuSheet> {
  /// The one open group, or null for all shut. Single-valued **by type**: the
  /// invariant that keeps this sheet short is not a rule somebody has to
  /// remember, it is that there is nowhere to put a second group.
  NavGroup? _open;

  @override
  void initState() {
    super.initState();
    // Opened on the group holding the route beneath the sheet. A manager who
    // opens the menu from Users is almost always going somewhere else in
    // Configure, and in any case being shown where you are standing is how a
    // list of twenty-four becomes orientating rather than a wall.
    _open = menuDestinationFor(widget.currentRoute)?.group;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final mode = ref.watch(themeModeProvider);
    final dark = mode == ThemeMode.dark;
    final here = menuDestinationFor(widget.currentRoute);

    void leaveFor(String route) {
      Navigator.of(context).pop();
      context.go(route);
    }

    return TorchSheet(
      title: l10n.menuTitle,
      subtitle: l10n.menuSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ...widget.lead,
          // The lead used to be followed by a kicker, which separated itself.
          // It is now followed by a card, and two cards with 12dp between them
          // are one list — so the gap that says "that block has ended" has to
          // be drawn rather than implied.
          if (widget.lead.isNotEmpty) SizedBox(height: skin.space.blockGap),
          for (final group in NavGroup.values)
            _GroupFold(
              key: ValueKey<String>('menu-group-${group.name}'),
              group: group,
              open: _open == group,
              here: here,
              onToggle: () => setState(() {
                _open = _open == group ? null : group;
              }),
              onGo: leaveFor,
            ),
          SizedBox(height: skin.space.blockGap),
          SectionRule(l10n.menuThisApp),
          const SizedBox(height: TiqSpace.s3),
          SoftRow(
            key: const ValueKey<String>('menu-theme'),
            density: SoftRowDensity.compact,
            // Names the state it switches TO, never the one it is in — the
            // same rule the skin cycle follows, and for the same reason: a
            // control that announces where it is makes a blind manager press
            // it to find out where it goes.
            title: dark ? l10n.menuThemeLight : l10n.menuThemeDark,
            onTap: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
          SoftRow(
            key: const ValueKey<String>('menu-password'),
            density: SoftRowDensity.compact,
            title: l10n.menuChangePassword,
            trailing: const SoftRowChevron(),
            onTap: () => leaveFor('/account/password'),
          ),
          SizedBox(height: skin.space.blockGap),
          TorchSecondaryButton(
            key: const ValueKey<String>('menu-sign-out'),
            label: l10n.menuSignOut,
            onPressed: () {
              // Pop first, then sign out: the router redirect that follows
              // rebuilds the page under this sheet, and a modal left standing
              // over the sign-in form is a scrim nobody can dismiss.
              Navigator.of(context).pop();
              ref.read(sessionControllerProvider.notifier).logout();
            },
          ),
        ],
      ),
    );
  }
}

/// ONE GROUP — a row that is the group, and its destinations under it.
///
/// The header is a compact [SoftRow]: at rest this sheet is a short stack of
/// cards, and a card is what this product's top-level list objects are. The
/// destinations inside are deliberately **not** cards — flat on the sheet's
/// ground, indented, `body` where the header is `title.m` — because nine more
/// radius-22 cards under a card is nine more top-level rows, which is the one
/// way an accordion can be drawn so that opening it tells you nothing.
class _GroupFold extends StatelessWidget {
  const _GroupFold({
    super.key,
    required this.group,
    required this.open,
    required this.here,
    required this.onToggle,
    required this.onGo,
  });

  final NavGroup group;
  final bool open;

  /// The destination the route beneath the sheet is on, if any.
  final NavDestination? here;

  final VoidCallback onToggle;
  final void Function(String route) onGo;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final destinations = destinationsIn(group);
    final name = navGroupName(l10n, group);

    final header = Semantics(
      container: true,
      button: true,
      // The flag, not a sentence. `TorchPressable` already announces a fold
      // this way (`semanticsExpanded`), and a platform that has a word for
      // "collapsed" says it better in the reader's own language than a string
      // we would have to translate twice.
      expanded: open,
      label: l10n.menuGroupSemantics(destinations.length, name),
      // THE ACTION, not only the flag — `excludeSemantics` drops the SoftRow's
      // own node, so without this line the row is a label a screen-reader
      // user can focus and cannot press. It is the kit-wide defect
      // `SectionRuleAction` documents.
      onTap: onToggle,
      excludeSemantics: true,
      child: SoftRow(
        key: ValueKey<String>('menu-fold-${group.name}'),
        density: SoftRowDensity.compact,
        // `Operate · 9`. The count sets in the marker's own words, which is
        // `SectionRule`'s grammar for exactly this number and its written
        // answer to the count chip. Sentence case, not the kicker's uppercase:
        // this is a row with a title now rather than a marker on the ground,
        // and uppercase-plus-tracking is the most space-hungry setting in the
        // system on the one change whose brief is "smaller".
        title: '$name · ${destinations.length}',
        trailing: _FoldCaret(open: open),
        onTap: onToggle,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        header,
        _Fold(
          open: open,
          child: Padding(
            padding: const EdgeInsets.only(bottom: TiqSpace.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final destination in destinations)
                  _DestinationRow(
                    key: ValueKey<String>('menu-${destination.route}'),
                    destination: destination,
                    here: destination.route == here?.route,
                    onTap: () => onGo(destination.route),
                  ),
              ],
            ),
          ),
        ),
        // The card's own 12dp sits under the header, so a shut group already
        // has its gap. An open one has spent that gap on its first child and
        // needs it again under its last.
        if (open) const SizedBox(height: TiqSpace.s1),
      ],
    );
  }
}

/// The reveal. [child] is clipped to a growing fraction of its own height,
/// which is the one form of this that looks right in **both** directions: the
/// rows stay mounted while the group shuts, so they slide up under the header
/// instead of blinking out and leaving a gap to close.
class _Fold extends StatefulWidget {
  const _Fold({required this.open, required this.child});

  final bool open;
  final Widget child;

  @override
  State<_Fold> createState() => _FoldState();
}

class _FoldState extends State<_Fold>
    with SingleTickerProviderStateMixin<_Fold> {
  // EAGER, IN `initState`, AND NOT A `late final` INITIALISER. Lazily, the
  // first thing to touch it under reduce-motion is `dispose()` — because the
  // still path never reads it — and `SingleTickerProviderStateMixin` looks up
  // `TickerMode` when the ticker is created, which on a deactivated element is
  // "Looking up a deactivated widget's ancestor is unsafe" in every one of
  // this sheet's tests at once. The duration is a placeholder; the skin's own
  // is applied when the fold actually moves.
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      value: widget.open ? 1 : 0,
      duration: TiqMotion.enter,
    );
  }

  @override
  void didUpdateWidget(_Fold old) {
    super.didUpdateWidget(old);
    if (old.open == widget.open) return;
    final duration = _duration(context);
    if (duration == Duration.zero) {
      // Jump, and do not start a ticker that would run for 200ms painting a
      // frame nobody asked for. A reader who turned motion off is not owed a
      // faster animation, they are owed none.
      _controller.value = widget.open ? 1 : 0;
      return;
    }
    _controller
      ..duration = duration
      // The group is changing state, so it moves on the state curve. One
      // duration for the fold and its caret both: a caret that settles before
      // the rows it describes reads as two animations rather than one object.
      ..animateTo(widget.open ? 1 : 0, curve: TiqMotion.stateCurve);
  }

  /// Zero when this frame is not allowed to move — the skin's own switch, and
  /// the reader's. The same call `TorchSheetSwap` makes.
  static Duration _duration(BuildContext context) =>
      MotionBudget.of(context).still
      ? Duration.zero
      : context.skin.motion.resolve(TiqMotion.enter);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // UNDER REDUCE-MOTION THE FOLD IS THE ROWS BEING THERE OR NOT, and
    // nothing else — not a zero-duration animation, which is a different
    // thing wearing the same clothes. The same call `TorchSheetSwap` makes,
    // for the reason written there.
    if (_duration(context) == Duration.zero) {
      return widget.open ? widget.child : const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        // Shut and settled: the rows are not built at all, which is what makes
        // "the sheet is five rows at rest" a fact about the widget tree rather
        // than a claim about what you can see.
        if (t == 0) return const SizedBox.shrink();
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: t,
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// The row's own chevron, turned a quarter: `>` shut, `v` open.
///
/// One glyph in two states rather than two glyphs, so the thing that moves is
/// the thing that was already there — and it is the same chevron every other
/// row in the product ends with, which is what says "this row does something"
/// before anybody works out what.
class _FoldCaret extends StatelessWidget {
  const _FoldCaret({required this.open});

  final bool open;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return AnimatedRotation(
      turns: open ? 0.25 : 0,
      // The fold's own duration, so the glyph and the rows arrive together.
      duration: _FoldState._duration(context),
      curve: TiqMotion.stateCurve,
      // `ink2`, a step up from the row chevron's `ink3`: this one is the
      // control rather than a hint that the row leads somewhere.
      child: SoftRowChevron(color: skin.palette.ink2),
    );
  }
}

/// ONE DESTINATION, inside an open group.
///
/// Not a [SoftRow], and that is the whole design of it. A SoftRow is a card,
/// and a card under a card is a sibling; these are flat on the sheet's ground,
/// indented so the label clears its header's, at `body` where the header is
/// `title.m`, in `ink2` where the header is `ink1`. Four channels of
/// subordination and none of them a colour.
///
/// **The row you are on** is `body.strong` on `ink1` in a `surface` box — the
/// same size, more weight, more light, and a silhouette. Weight and fill are
/// free; the amber they stand in for is not, and this sheet's census is zero.
class _DestinationRow extends StatefulWidget {
  const _DestinationRow({
    super.key,
    required this.destination,
    required this.here,
    required this.onTap,
  });

  final NavDestination destination;
  final bool here;
  final VoidCallback onTap;

  /// The indent, which is the header card's own margin. It puts the glyph in
  /// the lane the card spends on its padding and its severity dot, and the
  /// label 14dp to the right of the header's — inside the group's column
  /// rather than beside it.
  static const double indent = TiqSpace.s5;

  /// One step under the kit's 20dp row glyph, because the row it labels is
  /// `body` 13 rather than `title.m` 15. Grown by [MarkScale.glyph], so it
  /// follows the reader's text size like the words beside it.
  static const double glyph = 18;

  @override
  State<_DestinationRow> createState() => _DestinationRowState();
}

class _DestinationRowState extends State<_DestinationRow> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final palette = skin.palette;
    final label = widget.destination.labelIn(l10n);
    final here = widget.here;

    // A WELL, NOT A CARD — and the render is why. `surface` is what a card is
    // filled with, so the row you are standing on came out the same colour and
    // the same width as the group header above it; on Day the two were nearly
    // indistinguishable, which is the exact failure a folded list is supposed
    // to avoid. `well` steps the other way (darker than ground on Day, a
    // shorter step than `surface` on Night), so it reads as a groove the row
    // is sitting IN rather than an object sitting on top. That is also what it
    // means.
    final Color? fill = _pressed
        ? palette.lifted
        : (here ? palette.well : null);
    final Color ink = _pressed
        ? (skin.brightness == Brightness.dark ? palette.ink1 : palette.ground)
        : (here ? palette.ink1 : palette.ink2);

    final line = Row(
      children: <Widget>[
        Icon(
          widget.destination.icon,
          size: MarkScale.glyph(context, _DestinationRow.glyph),
          color: ink,
        ),
        const SizedBox(width: TiqSpace.s3),
        Expanded(
          child: Text(
            label,
            // Two lines is the safety valve, not the plan: nothing in this
            // list wraps at 1.0× or 1.3× at 360dp — `menu_sheet_fold_test`
            // measures every label at both and fails with the one that grew.
            // Afrikaans at 2.0× does wrap, and a wrapped name is better than
            // a clipped one.
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: (here ? skin.text.bodyStrong : skin.text.body).style(
              color: ink,
            ),
          ),
        ),
      ],
    );

    return Semantics(
      container: true,
      button: true,
      // The platform's own word for it, in the reader's own language.
      selected: here,
      label: label,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: _DestinationRow.indent,
            end: _DestinationRow.indent,
            bottom: TiqSpace.s1,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(skin.radii.control),
            ),
            child: ConstrainedBox(
              // THE FLOOR WINS. "Much smaller" and 44dp fought here and 44dp
              // took it. The content wants 36dp at 1.0× — `body` is 13 at
              // 1.55 (20.15dp), the glyph is 18, plus 8dp of padding top and
              // bottom — and the box stands at 44 anyway, because WCAG 2.5.5
              // is not a design axis. `menu_sheet_fold_test.dart` measures
              // all 24 of them at 1.0× and 1.3× and names the one that drops.
              constraints: BoxConstraints(minHeight: skin.space.tapTarget),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TiqSpace.s3,
                  vertical: TiqSpace.s2,
                ),
                child: line,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
