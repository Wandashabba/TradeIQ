import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import '../auth/session_controller.dart';
import '../theme/lumen_glass.dart';
import '../theme/theme_mode_controller.dart';
import '../theme/tiq_colors.dart';
import 'agent_motion.dart' show reduceMotion;
import 'bottom_nav_bar.dart';
import 'glass.dart';
import 'nav_destinations.dart';
import '../theme/lumen_palette.dart';

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
///
/// In Lumen Glass the whole console floats on one lit ground: the top bar and
/// the rail are single panes of glass, and the active destination is a bright
/// glass pill rather than a rule.
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
    final glass = colors.glass;
    final mode = ref.watch(themeModeProvider);

    final layout = compact
        ? Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: _bottomBarClearance),
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
              if (!glass) VerticalDivider(width: 1, color: colors.line),
              Expanded(child: body),
            ],
          );

    return Scaffold(
      backgroundColor: colors.plane,
      extendBodyBehindAppBar: glass,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(title),
        // Glass: the window bar is a pane over the ground — a 42% white fill
        // on its own blur, with a lit rim for its bottom edge.
        backgroundColor: glass ? context.lumen.white(0x6B) : null,
        surfaceTintColor: glass ? Colors.transparent : null,
        shape: glass
            ? Border(bottom: BorderSide(color: context.lumen.white(0xCC)))
            : null,
        flexibleSpace: glass
            ? ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: const SizedBox.expand(),
                ),
              )
            : null,
        actions: [
          ...?actions,
          // Push notification settings (#67).
          IconButton(
            key: const ValueKey('manager-notifications'),
            icon: const Icon(Icons.notifications_none_outlined, size: 18),
            tooltip: 'Notification settings',
            onPressed: () => context.go('/notifications'),
          ),
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
      body: glass
          ? LitGround(
              layout: GroundLayout.console,
              child: Builder(
                // The ground runs under the glass bar; the content starts
                // below it, and no scroll view applies that inset twice.
                builder: (context) => Padding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.paddingOf(context).top,
                  ),
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: layout,
                  ),
                ),
              ),
            )
          : layout,
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
    final glass = colors.glass;

    final column = SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(vertical: glass ? 12 : 10),
              children: [
                for (final group in NavGroup.values) ...[
                  Padding(
                    padding: glass
                        ? const EdgeInsets.fromLTRB(22, 14, 16, 6)
                        : const EdgeInsets.fromLTRB(16, 12, 16, 5),
                    child: Text(
                      navGroupName(context.l10n, group).toUpperCase(),
                      style: glass
                          ? LumenGlass.kickerStyle(
                              color: context.lumen.inkMuted,
                              size: 9.5,
                            )
                          : TextStyle(
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
                      selected:
                          location == d.route ||
                          location.startsWith('${d.route}/'),
                      onTap: () => context.go(d.route),
                    ),
                ],
              ],
            ),
          ),
          if (glass)
            Divider(height: 1, color: context.lumen.white(0xCC))
          else
            Divider(height: 1, color: colors.line),
          _RailFoot(onLogout: onLogout),
        ],
      ),
    );

    if (!glass) {
      return Container(width: 232, color: colors.surface1, child: column);
    }

    // One pane of glass down the left edge: a 34% fill on a 26px blur, lit
    // along its right rim.
    return SizedBox(
      width: 248,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: LumenGlass.blurDark,
            sigmaY: LumenGlass.blurDark,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.lumen.white(0x57),
              border: Border(
                right: BorderSide(color: context.lumen.white(0xB3)),
              ),
            ),
            child: column,
          ),
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
    final colors = context.colors;
    final glass = colors.glass;
    final destination = widget.destination;
    final selected = widget.selected;
    final duration = reduceMotion(context)
        ? Duration.zero
        : const Duration(milliseconds: 150);

    final Widget row;
    if (glass) {
      // The active destination is a bright glass pill with its own rim and
      // shadow; hover lifts an unselected row's glass by a few percent.
      final wash = _pressed
          ? context.lumen.white(0x4D)
          : _hovered
          ? context.lumen.white(0x33)
          : Colors.transparent;
      row = AnimatedContainer(
        duration: duration,
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? context.lumen.white(0xB8) : wash,
          borderRadius: BorderRadius.circular(LumenGlass.radiusIconTile),
          border: Border.all(
            color: selected ? context.lumen.white(0xCC) : Colors.transparent,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x243C3078),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              destination.icon,
              size: 15,
              color: selected
                  ? context.lumen.accentInk
                  : context.lumen.inkMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                destination.labelIn(context.l10n),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? context.lumen.ink : context.lumen.inkMuted,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // The active row is a rule plus a weight change — not a filled pill. It
      // reads as position, which is what it means. The hover/pressed wash sits
      // UNDER the selected state: only unselected rows answer it.
      final wash = _pressed
          ? colors.surface3
          : _hovered
          ? colors.surface2
          : Colors.transparent;
      row = AnimatedContainer(
        duration: duration,
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
                destination.labelIn(context.l10n),
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
    }

    return InkWell(
      // Key preserved from the drawer implementation — navigation tests and
      // anything else keyed on a destination keep working.
      key: ValueKey('nav-${destination.route}'),
      onTap: widget.onTap,
      // The wash is painted by the row's own decoration (above) — ink on the
      // ancestor Material would be buried under the rail's fill.
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
    final glass = colors.glass;
    final role = ref.watch(sessionControllerProvider).value?.role ?? '';
    final avatar = glass
        ? GlassPane(
            kind: GlassKind.action,
            radius: LumenGlass.radiusIconTile,
            shadow: false,
            child: const SizedBox(
              width: 32,
              height: 32,
              child: Icon(Icons.person_outline, size: 16, color: Colors.white),
            ),
          )
        : Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.surface3,
              border: Border.all(color: colors.lineStrong),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Icon(Icons.person_outline, size: 14, color: colors.ink2),
          );

    return Padding(
      padding: EdgeInsets.fromLTRB(glass ? 18 : 16, 10, 8, 10),
      child: Row(
        children: [
          avatar,
          SizedBox(width: glass ? 10 : 9),
          Expanded(
            child: Text(
              role.isEmpty ? 'Signed in' : _humanRole(role),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: glass ? 12.5 : 12,
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
