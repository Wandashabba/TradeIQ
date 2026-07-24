import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'agent_motion.dart' show reduceMotion;
import 'nav_menu_sheet.dart';

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

/// Apple News-style floating pill bar — ManagerScaffold shows it below 1080px
/// in place of the sidebar. Always the light treatment: blurred white over
/// whatever scrolls beneath, hairline border, soft shadow.
class TiqBottomNavBar extends StatelessWidget {
  const TiqBottomNavBar({super.key, required this.activeRoute});

  /// The router's matched location; the blue pill sits under the slot whose
  /// route matches (prefix-aware, so `/tasks/42` still lights up Tasks).
  final String activeRoute;

  static const _accent = Color(0xFF0A6CF0);
  static const _pillFill = Color(0xFFEAF2FF);
  static const _inactiveInk = Color(0xFF5C6470);

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
    final activeIndex = _activeIndex;
    return Container(
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2914161C), // rgba(20,22,28,.16)
            offset: Offset(0, 6),
            blurRadius: 22,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xEBFFFFFF), // rgba(255,255,255,.92)
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xFFE3E5EA)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(5),
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
                            color: _pillFill,
                            borderRadius: BorderRadius.circular(21),
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
    final color =
        active ? TiqBottomNavBar._accent : TiqBottomNavBar._inactiveInk;
    final route = slot.route;
    return InkWell(
      key: ValueKey('bottom-nav-${route ?? 'menu'}'),
      borderRadius: BorderRadius.circular(21),
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
          Icon(slot.icon, size: 20, color: color),
          const SizedBox(height: 2),
          Text(
            slot.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
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
