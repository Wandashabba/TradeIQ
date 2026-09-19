import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/torch_scope.dart';
import '../../../core/theme/torchlight/console_skin.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/state/skeleton.dart';
import '../../../l10n/l10n.dart';
import '../../clients/data/clients_repository.dart';
import 'ask_first_run.dart';
import 'chat_screen.dart';

/// The entry point, gated on the rollout flag.
///
/// **This gate is a courtesy, not the security boundary.** The server 404s
/// `/assistant/*` for a tenant outside the rollout regardless of what the app
/// does, and it answers 404 rather than 403 specifically so the kill switch is
/// indistinguishable from the feature never having shipped. This screen exists
/// so a manager who finds the menu item gets a sentence instead of a dead
/// screen — not to enforce anything.
///
/// **It fails toward the chat, not away from it.** If `/clients/me` errors we
/// show the composer anyway: the request will be refused server-side with a
/// message, which is a better outcome than telling someone their feature is
/// switched off because one unrelated call timed out.
///
/// It watches `clientConfigProvider` — the provider the config screen already
/// uses — rather than issuing its own `/clients/me`. A second provider over the
/// same endpoint would be a second round trip and, worse, a second cache: the
/// two could disagree about the flag after an admin changed something.
class AssistantGate extends ConsumerWidget {
  const AssistantGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(clientConfigProvider);
    final config = state.value;
    if (config != null) {
      return config.assistantEnabled
          ? const AssistantChatScreen()
          : const _GateFrame(child: AskNotEnabled());
    }
    // Read before `loading`, and not through `when`: a provider that failed
    // is retried, and while it retries it is *both* erroring and loading. A
    // `when` would hold the skeleton on screen through every retry — a
    // manager watching a grey shape because one unrelated call timed out.
    if (state.hasError) return const AssistantChatScreen();
    // The skeleton geometry of one empty transcript, not a centred spinner:
    // the shape a manager is about to read, held still.
    return const _GateFrame(child: _GateSkeleton());
  }
}

/// The chrome the gate's own two states wear, so the header does not appear
/// to arrive late.
class _GateFrame extends ConsumerWidget {
  const _GateFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ConsoleTorchlightRoute(
      child: Builder(
        builder: (context) => TorchScope(
          skin: context.skin,
          phase: 'gate',
          navRenders: false,
          tabbedRoute: true,
          // Nothing is armed here, in any skin: the count is zero plus the
          // nav, and the nav is not rendering.
          claims: const <TorchClaim>[],
          child: TorchShell(
            profile: TorchShellProfile.console,
            header: TorchAppHeader(
              title: context.l10n.askTitle,
              trailing: consoleSkinCycleButton(context, ref),
            ),
            children: <Widget>[child],
          ),
        ),
      ),
    );
  }
}

class _GateSkeleton extends StatelessWidget {
  const _GateSkeleton();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Skeleton(
      label: context.l10n.askLoading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SkeletonLine(role: skin.text.display, widthFactor: 0.7),
          SizedBox(height: skin.space.intraBlock),
          SkeletonLine(role: skin.text.body, widthFactor: 0.9),
          SizedBox(height: skin.space.blockGap),
          const SkeletonRows(count: 4),
        ],
      ),
    );
  }
}
