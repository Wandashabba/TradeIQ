import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../../clients/data/clients_repository.dart';
import 'chat_screen.dart';

/// Whether this tenant is in the assistant rollout.
///
/// Reads `GET /clients/me`, which is the same call the config screen already
/// makes, so this is usually a cache hit rather than an extra round trip.
final assistantEnabledProvider = FutureProvider<bool>((ref) async {
  final config = await ref.watch(clientsRepositoryProvider).getConfig();
  return config.assistantEnabled;
});

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
class AssistantGate extends ConsumerWidget {
  const AssistantGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(assistantEnabledProvider).when(
          data: (enabled) =>
              enabled ? const AssistantChatScreen() : const _NotEnabled(),
          error: (_, __) => const AssistantChatScreen(),
          loading: () => const ManagerScaffold(
            title: 'Ask TradeIQ',
            body: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        );
  }
}

class _NotEnabled extends StatelessWidget {
  const _NotEnabled();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ManagerScaffold(
      title: 'Ask TradeIQ',
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_outlined, size: 28, color: colors.ink4),
              const SizedBox(height: 14),
              Text(
                'Not switched on for your organisation yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.ink1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                // Names who can act, because "contact your administrator" sends
                // people to the wrong place — a client admin cannot turn this
                // on, by design.
                'Ask TradeIQ answers questions about your sales, stock, shelf '
                'and competitors. It is being rolled out gradually — speak to '
                'your TradeIQ contact to be included.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, height: 1.5, color: colors.ink3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
