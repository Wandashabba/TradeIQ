import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../../../core/widgets/worklist.dart';
import '../data/users_repository.dart';

/// Users as a worklist: who can sign in, in what role, and the one switch that
/// changes it.
class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(usersListProvider);
    return ManagerScaffold(
      title: 'Users',
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add user',
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const _CreateUserDialog(),
        ),
        child: const Icon(Icons.person_add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Deactivating a user revokes sign-in immediately.',
            style: TextStyle(fontSize: 12, color: AppColors.ink3),
          ),
          const SizedBox(height: 12),
          AsyncSection<List<AppUser>>(
            value: users,
            label: 'users',
            onRetry: () => ref.invalidate(usersListProvider),
            builder: (list) {
              final active = list.where((u) => u.active).length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TriageStrip(
                    counts: [
                      (
                        label: 'Active',
                        count: active,
                        level: StatusLevel.good,
                      ),
                      (
                        label: 'Inactive',
                        count: list.length - active,
                        level: StatusLevel.neutral,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _UserList(users: list),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _UserList extends StatelessWidget {
  const _UserList({required this.users});

  final List<AppUser> users;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      title: '${users.length} ${users.length == 1 ? 'user' : 'users'}',
      subtitle: 'Sign-in and role',
      padded: false,
      child: users.isEmpty
          ? const EmptyState(
              message: 'No users yet',
              hint: 'Add a user to give someone access to this client.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [for (final u in users) _UserRow(user: u)],
            ),
    );
  }
}

class _UserRow extends ConsumerWidget {
  const _UserRow({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return WorklistRow(
      title: user.email,
      // The role string is what the API stores and what authorisation checks
      // against, so it is shown verbatim in mono — not prettified.
      meta: Row(
        children: [Flexible(child: CodeToken(user.role))],
      ),
      level: user.active ? StatusLevel.good : StatusLevel.neutral,
      statusLabel: user.active ? 'Active' : 'Inactive',
      resolved: !user.active,
      actions: [
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Switch(
            key: ValueKey<String>('active-${user.id}'),
            value: user.active,
            onChanged: (v) async {
              await ref.read(usersRepositoryProvider).setActive(user.id, v);
              ref.invalidate(usersListProvider);
            },
          ),
        ),
      ],
    );
  }
}

class _CreateUserDialog extends ConsumerStatefulWidget {
  const _CreateUserDialog();

  @override
  ConsumerState<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends ConsumerState<_CreateUserDialog> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _role = 'field_agent';
  bool _submitting = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _submitting = true);
    try {
      await ref.read(usersRepositoryProvider).createUser(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
            role: _role,
          );
      ref.invalidate(usersListProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create user: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create User'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey<String>('new-email'),
            controller: _emailCtrl,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('new-password'),
            controller: _passwordCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const ValueKey<String>('new-role'),
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Role'),
            items: const [
              DropdownMenuItem(value: 'field_agent', child: Text('field_agent')),
              DropdownMenuItem(value: 'manager', child: Text('manager')),
              DropdownMenuItem(value: 'admin', child: Text('admin')),
            ],
            onChanged: (v) => setState(() => _role = v ?? 'field_agent'),
          ),
        ],
      ),
      actions: [
        FilledButton(
          key: const ValueKey<String>('create-user'),
          onPressed: _submitting ? null : _create,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
