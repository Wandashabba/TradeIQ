import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session_controller.dart';

/// Wraps every agent screen with a consistent AppBar.
/// On the root /audit screen there is no back button.
/// On sub-screens a back arrow navigates to /audit.
class AgentScaffold extends ConsumerWidget {
  const AgentScaffold({
    super.key,
    required this.title,
    required this.body,
    this.floatingActionButton,
  });

  final String title;
  final Widget body;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final isRoot = location == '/audit';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: isRoot
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to outlets',
                onPressed: () => context.go('/audit'),
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () =>
                ref.read(sessionControllerProvider.notifier).logout(),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
      body: body,
    );
  }
}
