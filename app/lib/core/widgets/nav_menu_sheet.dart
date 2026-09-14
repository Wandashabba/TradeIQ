import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_controller.dart';
import '../brand_media.dart';
import '../theme/lumen_glass.dart';
import '../theme/lumen_palette.dart';
import '../theme/theme_mode_controller.dart';
import '../theme/tiq_colors.dart';
import 'glass.dart';
import 'nav_destinations.dart';

/// The Menu slot's bottom sheet: the FULL destination list (the bar itself
/// carries only the "what needs me now" four), grouped by the same three
/// verbs as the desktop sidebar, plus the housekeeping the sidebar's footer
/// and app-bar actions provide — theme toggle and sign-out.
Future<void> showNavMenuSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const NavMenuSheet(),
  );
}

/// The sheet body — public so tests can pump it directly and exercise the
/// [headerImage] arm without waiting on curation.
class NavMenuSheet extends StatelessWidget {
  const NavMenuSheet({super.key, this.headerImage = BrandMedia.menuHeader});

  /// Optional decorative banner across the top of the sheet, defaulting to
  /// the [BrandMedia.menuHeader] slot — null (no band, today's layout
  /// exactly) until a human curates an image; see
  /// `tool/generate_brand_media/README.md`. A path set without its pubspec
  /// asset entry degrades to nothing — the errorBuilder collapses the band
  /// instead of showing an error box.
  final String? headerImage;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lumen = context.lumen;
    final glass = colors.glass;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: glass
          // The glass sheet recipe app_theme gives every other sheet: an
          // opaque surface1 ground (its words must clear AA whatever the scrim
          // covers), a white rim and the panel shadow.
          ? BoxDecoration(
              color: colors.surface1,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(LumenGlass.radiusScore),
              ),
              border: Border.all(color: lumen.panelRim),
              boxShadow: [
                BoxShadow(
                  color: lumen.shadow,
                  blurRadius: LumenGlass.shadowPanel.blurRadius,
                  offset: LumenGlass.shadowPanel.offset,
                ),
              ],
            )
          : BoxDecoration(
              color: colors.surface1,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.lineStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (headerImage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    glass ? LumenGlass.radiusControl : 12,
                  ),
                  child: Image.asset(
                    headerImage!,
                    width: double.infinity,
                    height: 88,
                    fit: BoxFit.cover,
                    semanticLabel: '',
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final group in NavGroup.values) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(2, 10, 2, 7),
                        child: Text(
                          group.heading,
                          style: glass
                              ? LumenGlass.kickerStyle(
                                  color: lumen.kicker,
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
                      _DestinationGrid(destinations: destinationsIn(group)),
                    ],
                  ],
                ),
              ),
            ),
            Divider(height: 17, color: colors.line),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _HousekeepingRow(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Two columns of bordered destination tiles — the sidebar's list, reshaped
/// for a thumb instead of a pointer.
class _DestinationGrid extends StatelessWidget {
  const _DestinationGrid({required this.destinations});

  final List<NavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < destinations.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(child: _DestinationTile(destinations[i])),
                const SizedBox(width: 8),
                Expanded(
                  child: i + 1 < destinations.length
                      ? _DestinationTile(destinations[i + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DestinationTile extends StatelessWidget {
  const _DestinationTile(this.destination);

  final NavDestination destination;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final glass = colors.glass;
    final row = Row(
      children: [
        Icon(
          destination.icon,
          size: 16,
          color: glass ? context.lumen.accentInk : colors.ink2,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            destination.label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: colors.ink1,
            ),
          ),
        ),
      ],
    );
    void go() {
      context.go(destination.route);
      Navigator.of(context).pop();
    }

    if (glass) {
      // A tile of glass. The ink well sits INSIDE the pane — outside it, the
      // ripple would paint beneath the fill and never be seen.
      return GlassPane(
        kind: GlassKind.tile,
        // Twelve-plus tiles in one sheet: no blur per tile.
        blur: false,
        radius: LumenGlass.radiusControl,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: ValueKey('nav-sheet-${destination.route}'),
            borderRadius: BorderRadius.circular(LumenGlass.radiusControl),
            onTap: go,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: row,
            ),
          ),
        ),
      );
    }

    return InkWell(
      key: ValueKey('nav-sheet-${destination.route}'),
      borderRadius: BorderRadius.circular(10),
      onTap: go,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: colors.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: row,
      ),
    );
  }
}

/// Theme toggle + sign out, side by side under the destinations. Sign-out
/// only fires the session controller — the router redirect does the rest.
class _HousekeepingRow extends StatelessWidget {
  const _HousekeepingRow();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Expanded(
          child: Consumer(
            builder: (context, ref, _) {
              final mode = ref.watch(themeModeProvider);
              final dark = mode == ThemeMode.dark;
              return _HousekeepingButton(
                icon: dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                label: dark ? 'Light theme' : 'Dark theme',
                color: colors.ink2,
                onTap: () => ref.read(themeModeProvider.notifier).toggle(),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Consumer(
            builder: (context, ref, _) => _HousekeepingButton(
              icon: Icons.logout,
              label: 'Sign out',
              color: colors.ink2,
              onTap: () {
                final session = ref.read(sessionControllerProvider.notifier);
                Navigator.of(context).pop();
                session.logout();
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _HousekeepingButton extends StatelessWidget {
  const _HousekeepingButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final row = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: colors.ink1,
          ),
        ),
      ],
    );

    if (colors.glass) {
      // Housekeeping is secondary: a glass pill, never the dark action.
      return GlassPane(
        kind: GlassKind.pill,
        radius: LumenGlass.radiusControl,
        shadow: false,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(LumenGlass.radiusControl),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
              child: row,
            ),
          ),
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: colors.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: row,
      ),
    );
  }
}
