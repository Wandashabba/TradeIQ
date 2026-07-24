import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_controller.dart';
import '../theme/theme_mode_controller.dart';
import '../theme/tiq_colors.dart';
import 'agent_motion.dart' show reduceMotion;
import 'bottom_nav_bar.dart';
import 'nav_destinations.dart';

/// At and above this width the console keeps its persistent sidebar; below
/// it the sidebar disappears entirely and the floating bottom bar takes over.
/// Two modes, no half-collapsed rail, no drawer.
const double _railBreakpoint = 1080;

/// How much room the floating bar needs: 64px of bar + 12px of float. Body
/// content is padded by this so nothing scrolls to a stop underneath it.
const double _bottomBarClearance = 76;

/// Wraps every manager screen in the console shell: a persistent navigation
/// rail on desktop (managers are on Flutter web); below [_railBreakpoint] the
/// rail gives way to [TiqBottomNavBar] floating over the body.
class ManagerScaffold extends ConsumerWidget {
  const ManagerScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
  });

  final String title;
  final Widget body;

  /// Page-level actions rendered in the top bar (e.g. Export, Run rules).
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < _railBreakpoint;

    void logout() => ref.read(sessionControllerProvider.notifier).logout();

    final colors = context.colors;
    final mode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: colors.plane,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(title),
        actions: [
          ...?actions,
          IconButton(
            key: const ValueKey('theme-toggle'),
            icon: Icon(
              mode == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              size: 18,
            ),
            tooltip: mode == ThemeMode.dark
                ? 'Switch to light theme'
                : 'Switch to dark theme',
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 18),
            tooltip: 'Log out',
            onPressed: logout,
          ),
          const SizedBox(width: 4),
        ],
      ),
      // At compact width the FAB is lifted above the floating bar so the two
      // never overlap.
      floatingActionButton: compact && floatingActionButton != null
          ? Padding(
              padding: const EdgeInsets.only(bottom: _bottomBarClearance),
              child: floatingActionButton,
            )
          : floatingActionButton,
      body: compact
          ? Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding:
                        const EdgeInsets.only(bottom: _bottomBarClearance),
                    child: body,
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: TiqBottomNavBar(activeRoute: location),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _NavRail(location: location, onLogout: logout),
                VerticalDivider(width: 1, color: colors.line),
                Expanded(child: body),
              ],
            ),
    );
  }
}

class _NavRail extends StatelessWidget {
  const _NavRail({required this.location, required this.onLogout});

  final String location;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 232,
      color: colors.surface1,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                children: [
                  for (final group in NavGroup.values) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 5),
                      child: Text(
                        group.heading,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.9,
                          color: colors.ink3,
                        ),
                      ),
                    ),
                    for (final d in destinationsIn(group))
                      _NavRow(
                        destination: d,
                        selected: location == d.route ||
                            location.startsWith('${d.route}/'),
                        onTap: () => context.go(d.route),
                      ),
                  ],
                ],
              ),
            ),
            Divider(height: 1, color: colors.line),
            _RailFoot(onLogout: onLogout),
          ],
        ),
      ),
    );
  }
}

class _NavRow extends StatefulWidget {
  const _NavRow({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavRow> createState() => _NavRowState();
}

class _NavRowState extends State<_NavRow> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    // The active row is a rule plus a weight change — not a filled pill. It
    // reads as position, which is what it means.
    final colors = context.colors;
    final destination = widget.destination;
    final selected = widget.selected;
    // The hover/pressed wash sits UNDER the selected state: the current
    // destination keeps its surface2 fill (and brand rule) no matter what the
    // pointer is doing. Only unselected rows answer it.
    final wash = _pressed
        ? colors.surface3
        : _hovered
            ? colors.surface2
            : Colors.transparent;
    final row = AnimatedContainer(
      duration: reduceMotion(context)
          ? Duration.zero
          : const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? colors.surface2 : wash,
        border: Border(
          left: BorderSide(
            color: selected ? colors.brand : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(10, 7, 16, 7),
      child: Row(
        children: [
          Icon(
            destination.icon,
            size: 15,
            color: selected ? colors.series1 : colors.ink3,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              destination.label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? colors.ink1 : colors.ink2,
              ),
            ),
          ),
        ],
      ),
    );

    return InkWell(
      // Key preserved from the drawer implementation — navigation tests and
      // anything else keyed on a destination keep working.
      key: ValueKey('nav-${destination.route}'),
      onTap: widget.onTap,
      // The wash is painted by the row's own decoration (above) — ink on the
      // ancestor Material would be buried under the rail's surface1 fill.
      onHover: (hovered) => setState(() => _hovered = hovered),
      onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      child: row,
    );
  }
}

class _RailFoot extends ConsumerWidget {
  const _RailFoot({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final role = ref.watch(sessionControllerProvider).value?.role ?? '';
    final avatar = Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surface3,
        border: Border.all(color: colors.lineStrong),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Icon(
        Icons.person_outline,
        size: 14,
        color: colors.ink2,
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              role.isEmpty ? 'Signed in' : _humanRole(role),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.ink1,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 15),
            color: colors.ink3,
            tooltip: 'Log out',
            onPressed: onLogout,
          ),
        ],
      ),
    );
  }

  static String _humanRole(String role) => switch (role) {
        'field_agent' => 'Field agent',
        'manager' => 'Manager',
        'admin' => 'Administrator',
        _ => role,
      };
}
