import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/lumen_glass.dart';
import '../theme/tiq_colors.dart';
import 'agent_motion.dart' show reduceMotion;
import 'nav_menu_sheet.dart';
import '../theme/lumen_palette.dart';

/// One slot on the floating bar. `route == null` means the Menu slot, which
/// opens the sheet instead of navigating.
typedef _Slot = ({String? route, String label, IconData icon});

/// The "what needs me now" loop plus the everything-else Menu — fixed by
/// design (spec: set A). The full destination list lives in the Menu sheet.
const _slots = <_Slot>[
  (route: '/dashboard', label: 'Home', icon: Icons.home_outlined),
  (route: '/tasks', label: 'Tasks', icon: Icons.task_alt),
  (route: '/alerts', label: 'Alerts', icon: Icons.warning_amber_outlined),
  (route: '/agents/activity', label: 'Map', icon: Icons.location_on_outlined),
  (route: null, label: 'Menu', icon: Icons.menu),
];

/// The floating pill bar — ManagerScaffold shows it below 1080px in place of
/// the sidebar. One structure, two treatments via the `navBar*` [TiqColors]
/// slots: in Lumen Glass a single half-white pane over a 28px blur with a lit
/// rim and the handoff's uppercase mono labels; in dark blurred instrument
/// navy at 92%.
class TiqBottomNavBar extends StatelessWidget {
  const TiqBottomNavBar({super.key, required this.activeRoute});

  /// The router's matched location; the pill sits under the slot whose route
  /// matches (prefix-aware, so `/tasks/42` still lights up Tasks).
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
    final colors = context.colors;
    final glass = colors.glass;
    final activeIndex = _activeIndex;
    final radius = BorderRadius.circular(glass ? LumenGlass.radiusHero : 26);
    final pillRadius = BorderRadius.circular(
      glass ? LumenGlass.radiusButton : 21,
    );
    final sigma = glass ? LumenGlass.blurBar : 14.0;

    return Container(
      height: glass ? 62 : 64,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: glass
            ? const [LumenGlass.shadowBar]
            : const [
                BoxShadow(
                  color: Color(0x2914161C), // rgba(20,22,28,.16)
                  offset: Offset(0, 6),
                  blurRadius: 22,
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.navBarBg,
              borderRadius: radius,
              border: Border.all(color: colors.navBarLine),
            ),
            child: Stack(
              children: [
                if (glass)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(-0.8, -1),
                            end: Alignment(0.4, 0.6),
                            colors: [
                              context.lumen.white(0xB3),
                              Color(0x00FFFFFF),
                            ],
                            stops: [0, 0.48],
                          ),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.all(glass ? 7 : 5),
                  child: Stack(
                    children: [
                      // The pill is one widget that SLIDES between slots rather
                      // than a per-slot fill that pops — movement carries the
                      // "you went somewhere" meaning. Hidden when the active
                      // route lives only in the Menu sheet.
                      if (activeIndex != null)
                        AnimatedAlign(
                          alignment: Alignment(
                            -1 + 2 * activeIndex / (_slots.length - 1),
                            0,
                          ),
                          duration: reduceMotion(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          child: FractionallySizedBox(
                            widthFactor: 1 / _slots.length,
                            heightFactor: 1,
                            child: Container(
                              key: ValueKey(
                                'bottom-nav-pill-${_slots[activeIndex].route}',
                              ),
                              decoration: BoxDecoration(
                                color: colors.navActivePillBg,
                                borderRadius: pillRadius,
                                border: glass
                                    ? Border.all(color: context.lumen.pillRim)
                                    : null,
                                boxShadow: glass
                                    ? const [LumenGlass.shadowPill]
                                    : null,
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
                                active: i == activeIndex,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SlotButton extends StatelessWidget {
  const _SlotButton({required this.slot, required this.active});

  final _Slot slot;
  final bool active;

  @override
  Widget build(BuildContext context) {
    // Icon + label on EVERY slot — never colour alone (#144).
    final colors = context.colors;
    final glass = colors.glass;
    // Night lifts the inactive slots to ink2: navInactiveInk (#AEACC8) reads
    // only 4.2:1 once the 12% white bar composites over surface3, the palest
    // ground it can float over — bottom_nav_bar_test.dart measures the pair.
    final color = active ? colors.navActiveInk : colors.navInactiveInk;
    final route = slot.route;
    return InkWell(
      key: ValueKey('bottom-nav-${route ?? 'menu'}'),
      borderRadius: BorderRadius.circular(glass ? LumenGlass.radiusButton : 21),
      onTap: () {
        if (route == null) {
          showNavMenuSheet(context);
        } else {
          context.go(route);
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(slot.icon, size: glass ? 18 : 20, color: color),
          SizedBox(height: glass ? 3 : 2),
          Text(
            glass ? slot.label.toUpperCase() : slot.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: glass
                ? TextStyle(
                    fontFamily: LumenGlass.mono,
                    fontSize: 10,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: color,
                  )
                : TextStyle(
                    fontSize: 10.5,
                    height: 1,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: color,
                  ),
          ),
        ],
      ),
    );
  }
}
