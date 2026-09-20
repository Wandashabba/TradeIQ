import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/torchlight/tiq_skin.dart';
import 'agent_motion.dart' show reduceMotion;
import 'torchlight/menu_sheet.dart';
import '../../l10n/l10n.dart';

/// One slot on the floating bar. `route == null` means the Menu slot, which
/// opens the sheet instead of navigating.
///
/// [label] is the English name and the key [_slotLabel] switches on, never
/// the string that reaches the screen — same arrangement as
/// `NavDestination.labelIn`, and for the same reason: a `const` record cannot
/// hold a lookup against localisations that do not exist until there is a
/// `BuildContext`.
///
/// [activeIcon] is a **different silhouette**, not the same glyph on a
/// different ground: it is half of what tells a reader which slot is theirs
/// once the labels are gone at large text, and all of it once the screen is
/// greyscale. The Menu slot has no active form because it is never active.
typedef _Slot = ({
  String? route,
  String label,
  IconData icon,
  IconData activeIcon,
});

/// The slot's name in [l10n]'s language.
///
/// The bar keeps "Home" where the rail and the menu sheet say "The Floor":
/// five slots share a phone's width at 10.5px on one line, and the long name
/// is the menu's job, where there is room to read it.
String _slotLabel(AppLocalizations l10n, _Slot slot) => switch (slot.route) {
  '/dashboard' => l10n.navHome,
  '/tasks' => l10n.navTasks,
  '/alerts' => l10n.navAlerts,
  '/agents/activity' => l10n.navMap,
  null => l10n.menuTitle,
  _ => slot.label,
};

/// The "what needs me now" loop plus the everything-else Menu — fixed by
/// design (spec: set A). The full destination list lives in the Menu sheet.
const _slots = <_Slot>[
  (
    route: '/dashboard',
    label: 'Home',
    icon: Icons.home_outlined,
    activeIcon: Icons.home,
  ),
  (
    route: '/tasks',
    label: 'Tasks',
    icon: Icons.task_alt,
    activeIcon: Icons.assignment_turned_in,
  ),
  (
    route: '/alerts',
    label: 'Alerts',
    icon: Icons.warning_amber_outlined,
    activeIcon: Icons.warning,
  ),
  (
    route: '/agents/activity',
    label: 'Map',
    icon: Icons.location_on_outlined,
    activeIcon: Icons.location_on,
  ),
  (route: null, label: 'Menu', icon: Icons.menu, activeIcon: Icons.menu),
];

/// The gap between a slot's label and the slot's own edge. The label has to
/// clear it on both sides or the bar drops every label at once.
const double _labelGutter = 8;

/// The active slot's underbar: 3dp of ink-1 under the label.
const double _underbarHeight = 3;

/// The floating pill bar — ManagerScaffold shows it below 1080px in place of
/// the sidebar.
///
/// ## It paints no amber, and it claims none
///
/// The bar used to read `navActiveInk`, which `TiqColors.fromSkin` maps to
/// `flame600`. Under the themes `main.dart` actually ships that was wrong
/// twice over. In Day it was **invisible** — #FFB162 on Palladian well is
/// 1.30:1, and `navActivePillBg` is the bar's own colour, so the pill painted
/// nothing and the active slot was a pale peach word nobody could read. And
/// in every skin it was an amber that **no route had claimed**: amber is
/// granted through `TorchScope` and never painted, and this is the one piece
/// of chrome that is on screen the whole time on seven live manager routes,
/// so it was an amber no census could see.
///
/// ManagerScaffold is still the Lumen console shell and has no `TorchShell`
/// above it to hold a scope, so the bar cannot claim. It therefore does not
/// paint: the active slot is **ink-1 plus three independent shapes** — a
/// filled silhouette in place of the outlined one, a 600 weight, and a 3dp
/// underbar that slides between slots. All four survive greyscale, and the
/// ink clears AA in Night, Day and Veld (`bottom_nav_bar_test.dart` measures
/// all three against the themes `main.dart` ships, which is the step the
/// original tests missed: they pumped `AppTheme.dark()`/`AppTheme.light()`).
///
/// ## It costs one opaque fill
///
/// No `BackdropFilter`, no `BoxShadow`, no gradient. The bar is the one widget
/// that is never off screen, and a sigma-14 blur on it is a full-screen
/// `saveLayer` on every frame of every scroll on a mid-range Android. An
/// opaque `well` and a 1px `edgeStructure` outline separate it from the body —
/// the same answer `TorchNavPill` gives, for the same reason.
class TiqBottomNavBar extends StatelessWidget {
  const TiqBottomNavBar({super.key, required this.activeRoute});

  /// The router's matched location; the underbar sits under the slot whose
  /// route matches (prefix-aware, so `/tasks/42` still lights up Tasks).
  final String activeRoute;

  int? get _activeIndex {
    for (var i = 0; i < _slots.length; i++) {
      final route = _slots[i].route;
      if (route == null) continue;
      if (activeRoute == route || activeRoute.startsWith('$route/')) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final l10n = context.l10n;
    final activeIndex = _activeIndex;
    final docked = skin.mode == SkinMode.veld;
    final radius = docked ? BorderRadius.zero : BorderRadius.circular(26);
    final scaler = MediaQuery.textScalerOf(context);
    final labels = <String>[for (final slot in _slots) _slotLabel(l10n, slot)];
    // The measurement has to use the style the slot renders, so the token is
    // resolved once here and handed down rather than written out twice.
    final activeToken = _labelToken(skin, active: true);

    return LayoutBuilder(
      builder: (context, constraints) {
        // THE MEASUREMENT, not a text-scale threshold. Every localised label,
        // at the real scaler, against the real slot width. Afrikaans is the
        // case that found this: "Waarskuwings" at 10.5/600 needs 126px on a
        // 360dp phone's 64px slot at 1.0×, so the shipped bar rendered
        // "Waarsk…" — and the test that was supposed to catch it asserted
        // `find.text('Waarskuwings')`, which matches the Text widget's data
        // and passes while the phone clips it.
        //
        // When one label will not fit, ALL FIVE go — a bar with two words and
        // three glyphs reads as a rendering fault. The name stays on the
        // semantics node and in the tooltip, so nothing is lost to a screen
        // reader or to a long press.
        final slotWidth = (constraints.maxWidth - 10) / _slots.length;
        var labelsFit = true;
        for (final label in labels) {
          final painter = TextPainter(
            text: TextSpan(
              text: label,
              style: activeToken.style(color: p.ink1),
            ),
            textDirection: Directionality.of(context),
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          if (painter.width > slotWidth - _labelGutter) labelsFit = false;
          painter.dispose();
        }

        return Container(
          height: 64,
          decoration: BoxDecoration(
            color: p.well,
            borderRadius: radius,
            border: Border.all(
              color: p.edgeStructure,
              width: skin.depth.borderWidth,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Stack(
              children: [
                // The underbar is one widget that SLIDES between slots rather
                // than a per-slot mark that pops — movement carries the "you
                // went somewhere" meaning. Hidden when the active route lives
                // only in the Menu sheet.
                if (activeIndex != null)
                  AnimatedAlign(
                    alignment: Alignment(
                      -1 + 2 * activeIndex / (_slots.length - 1),
                      1,
                    ),
                    duration: reduceMotion(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    child: FractionallySizedBox(
                      widthFactor: 1 / _slots.length,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Container(
                          key: ValueKey(
                            'bottom-nav-pill-${_slots[activeIndex].route}',
                          ),
                          height: _underbarHeight,
                          decoration: BoxDecoration(
                            color: p.ink1,
                            borderRadius: BorderRadius.circular(
                              docked ? 0 : _underbarHeight / 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    for (var i = 0; i < _slots.length; i++)
                      Expanded(
                        child: _SlotButton(
                          slot: _slots[i],
                          label: labels[i],
                          showLabel: labelsFit,
                          active: i == activeIndex,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 10.5px, and 600 on the active slot — the skin's own `label` role, resized.
///
/// Declared once so the [TextPainter] that decides whether the labels fit
/// measures the style the slot renders: a measurement against a different
/// family, size or weight is a measurement of nothing.
TiqTypeToken _labelToken(TiqSkin skin, {required bool active}) =>
    skin.text.label.copyWith(
      size: 10.5,
      height: 1,
      weight: active ? FontWeight.w600 : FontWeight.w500,
    );

class _SlotButton extends StatelessWidget {
  const _SlotButton({
    required this.slot,
    required this.label,
    required this.showLabel,
    required this.active,
  });

  final _Slot slot;
  final String label;
  final bool showLabel;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    // Never colour alone (#144): the active slot changes silhouette, weight
    // and grows an underbar as well as lifting to ink-1.
    //
    // Inactive is ink-2 rather than `navInkInactive`: on Day the nav token is
    // #6E6657 on the #E2DBCC well, which is 4.12:1 — under AA for 10.5px
    // text. ink-2 is 9.51 / 7.01 / 9.66 across Night, Day and Veld.
    final ink = active ? p.ink1 : p.ink2;
    final route = slot.route;
    // A meaning-bearing glyph scales with the text, and in the icon-only bar
    // it is the ONLY thing carrying the destination — a reader who asked for
    // 2.0× text and got a 20dp glyph has been given the smallest version of
    // the one signal left. Capped so five of them still fit a 64dp bar.
    final glyph = MediaQuery.textScalerOf(context).scale(20).clamp(20.0, 28.0);

    void go() {
      if (route == null) {
        showTorchMenuSheet(context);
      } else {
        context.go(route);
      }
    }

    return Semantics(
      button: true,
      selected: active,
      label: label,
      // THE ACTION, not only the flag: `excludeSemantics` drops the InkWell's
      // own node, so without `onTap` here this is a control a screen reader
      // can focus and cannot activate — the #436 bug, which is also why the
      // name is on this node and survives the bar going icon-only.
      onTap: go,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: InkWell(
          key: ValueKey('bottom-nav-${route ?? 'menu'}'),
          borderRadius: BorderRadius.circular(21),
          onTap: go,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                active ? slot.activeIcon : slot.icon,
                size: glyph,
                color: ink,
              ),
              if (showLabel) ...[
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  // The measurement upstream guarantees this never fires. It
                  // is here so a bug in the measurement clips one label rather
                  // than throwing a yellow overflow stripe across a shop floor.
                  overflow: TextOverflow.clip,
                  softWrap: false,
                  style: _labelToken(skin, active: active).style(color: ink),
                ),
              ],
              // The underbar's own room, so the glyph and the label sit above
              // it rather than under it.
              const SizedBox(height: _underbarHeight + 2),
            ],
          ),
        ),
      ),
    );
  }
}
