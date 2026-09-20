import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../../auth/session_controller.dart';
import '../../theme/theme_mode_controller.dart';
import '../../theme/torchlight/tiq_skin.dart';
import '../nav_destinations.dart';
import 'button/buttons.dart';
import 'row/row.dart';
import 'section_rule.dart';
import 'sheet.dart';

/// THE MENU — the console's overflow, as the one modal container.
///
/// Every destination that does not fit the four slots, grouped by the verb it
/// serves, and under them the housekeeping that has nowhere else to live on a
/// phone: the app's brightness, the password, and the way out.
///
/// It reads [managerDestinations] rather than keeping a second list — a
/// destination added there appears here, in the rail and in the router guard
/// at once, which is the property the old nav had and the one worth keeping.
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
/// ## Amber: none
///
/// A menu commits nothing. The sheet declares no claims, and while it is up
/// every amber on the route beneath it is extinguished (unify §1.10), so the
/// nav tab under the scrim drops to its ink form.
Future<void> showTorchMenuSheet(BuildContext context) {
  return showTorchSheet<void>(
    context,
    builder: (sheetContext) => const _MenuSheet(),
  );
}

/// The sheet's body — public to the library so a test can pump it directly
/// rather than through a nav bar and a scrim.
@visibleForTesting
class MenuSheetBody extends StatelessWidget {
  const MenuSheetBody({super.key});

  @override
  Widget build(BuildContext context) => const _MenuSheet();
}

class _MenuSheet extends ConsumerWidget {
  const _MenuSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mode = ref.watch(themeModeProvider);
    final dark = mode == ThemeMode.dark;

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
          for (final group in NavGroup.values) ...<Widget>[
            SectionRule(navGroupName(l10n, group)),
            const SizedBox(height: TiqSpace.s3),
            for (final destination in destinationsIn(group))
              SoftRow(
                key: ValueKey<String>('menu-${destination.route}'),
                density: SoftRowDensity.compact,
                title: destination.labelIn(l10n),
                trailing: const SoftRowChevron(),
                onTap: () => leaveFor(destination.route),
              ),
            const SizedBox(height: TiqSpace.s6),
          ],
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
          SizedBox(height: context.skin.space.blockGap),
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
