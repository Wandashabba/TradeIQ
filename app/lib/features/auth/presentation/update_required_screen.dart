import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/app_version.dart';
import '../../../core/theme/torchlight/entry_skin.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../l10n/l10n.dart';
import 'account_frame.dart';

/// `/update-required` — the server has refused this build (#400).
///
/// Reached only from the router, and only while [appUpdateRequired] is set,
/// which only a 426 carrying `code: app_update_required` sets. The server's
/// floor is off by default (`MIN_APP_VERSION` unset), so this screen does not
/// appear until an operator deliberately raises it.
///
/// Plain on purpose. It says which version this is, which one is needed when
/// the server said, that nothing on the phone is deleted, and offers one
/// action. "Try again" clears the state and goes home; if the build is still
/// too old, the next request brings the screen straight back. It does not sign
/// the user out — the session is fine, only the build is stale.
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const EntryTorchlightRoute(child: _UpdateRequired());
}

class _UpdateRequired extends StatelessWidget {
  const _UpdateRequired();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ValueListenableBuilder<AppUpdateRequired?>(
      valueListenable: appUpdateRequired,
      builder: (context, gate, _) {
        final minimum = gate?.minimumVersion;
        return AccountFrame(
          phase: 'update-required',
          title: l10n.updateTitle,
          primaryArmed: true,
          skinCycle: const EntrySkinCycle(),
          primary: TorchPrimaryButton(
            key: const ValueKey<String>('update-try-again'),
            label: l10n.updateTryAgain,
            claimId: AccountFrame.primaryClaimId,
            onPressed: () {
              appUpdateRequired.value = null;
              context.go('/');
            },
          ),
          children: <Widget>[
            AccountText(l10n.updateBody),
            const SizedBox(height: TiqSpace.s5),
            AccountText(
              minimum == null
                  ? l10n.updateVersionNoMinimum(appVersion)
                  : l10n.updateVersions(appVersion, minimum),
            ),
            const SizedBox(height: TiqSpace.s5),
            AccountText(l10n.updateNothingLost, muted: true),
          ],
        );
      },
    );
  }
}
