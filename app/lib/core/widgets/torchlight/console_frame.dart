import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../design/torch_scope.dart';
import '../../theme/torchlight/tiq_skin.dart';
import 'chrome/chrome.dart';
import 'menu_sheet.dart';
import 'sheet.dart';

/// WHICH OF THE FOUR SLOTS A CONSOLE ROUTE SITS UNDER.
///
/// Four and no fifth: at 360dp the bar has 252dp once the insets and the
/// circle are drawn, and five slots is 50dp each — under the tap-target floor
/// before the active pill takes its 6dp inset. Unify §1.2 names them
/// **Floor · Work · Ask · Menu**, with Alerts and Tasks merged behind Work and
/// Territories moved into Menu under OPERATE.
enum ConsoleSlot { floor, work, ask, menu }

/// The manager's four destinations, in the ruling's order.
const List<TorchNavSlot> consoleNavSlots = <TorchNavSlot>[
  TorchNavSlot(
    icon: Icons.inventory_2_outlined,
    activeIcon: Icons.inventory_2,
    label: 'Floor',
  ),
  TorchNavSlot(
    icon: Icons.checklist_outlined,
    activeIcon: Icons.checklist,
    label: 'Work',
  ),
  TorchNavSlot(icon: Icons.forum_outlined, activeIcon: Icons.forum, label: 'Ask'),
  TorchNavSlot(icon: Icons.menu, activeIcon: Icons.menu_open, label: 'Menu'),
];

/// THE CONSOLE'S FRAME, for every manager route that is not The Floor.
///
/// It is the three things §12.6 asks a migrating screen to do, in one place:
/// the route's [TorchScope] with its declared claims, the [TorchShell] in its
/// console profile, and the nav pill with the right slot lit.
///
/// ## The amber arithmetic, and why these routes nominate nothing
///
/// A worklist is a tabbed route, so Night's budget is two: the nav's active
/// tab is slot 1 whenever the nav renders, and the content has one grant left.
/// Alerts, Tasks and Alert rules all decline it, and the reason is the same
/// one three times over — **nothing on a worklist is armed**. The selected
/// filter chip is `lifted` here exactly as it is everywhere else (unify §1.6),
/// the severity bars are crimson at two commitment levels, the SLA phrase
/// carries the urgency in words, and the section rule has no colour at all. A
/// budget is a ceiling, not a quota.
///
/// On Day and Veld the ladder has one rung — the primary commit block — and
/// these routes have no primary, so they paint **zero**.
///
/// While a sheet is up (an alert's detail, a task's closure gate) every amber
/// beneath it goes out: [TorchSheetAware] is what wires that, so the nav tab
/// drops to its ink form and the sheet's own scope owns the frame.
class ConsoleFrame extends StatelessWidget {
  const ConsoleFrame({
    super.key,
    required this.phase,
    required this.active,
    required this.children,
    this.header,
    this.claims = const <TorchClaim>[],
    this.scrollController,
  });

  /// `loading`, `loaded`, `empty`, `filtered-empty`, `error`. Resolution
  /// happens once per route × phase, never per frame.
  final String phase;

  final ConsoleSlot active;

  /// The body. Gutter-padded by the shell; a row list opts back out through
  /// `TorchBleed`.
  final List<Widget> children;

  final Widget? header;

  /// Almost always empty — see the class comment.
  final List<TorchClaim> claims;

  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return TorchSheetAware(
      builder: (context, beneathSheet) => TorchScope(
        skin: context.skin,
        phase: phase,
        navRenders: TorchShell.navWillRender(context, hasNav: true),
        tabbedRoute: true,
        beneathSheet: beneathSheet,
        claims: claims,
        child: TorchShell(
          profile: TorchShellProfile.console,
          header: header,
          scrollController: scrollController,
          navPill: TorchNavPill(
            slots: consoleNavSlots,
            activeIndex: active.index,
            onSelect: (index) => _select(context, index),
          ),
          children: children,
        ),
      ),
    );
  }

  static void _select(BuildContext context, int index) {
    switch (ConsoleSlot.values[index]) {
      case ConsoleSlot.floor:
        context.go('/dashboard');
      case ConsoleSlot.work:
        context.go('/tasks');
      case ConsoleSlot.ask:
        context.go('/assistant');
      case ConsoleSlot.menu:
        showTorchMenuSheet(context);
    }
  }
}
