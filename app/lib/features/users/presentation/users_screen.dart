import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/manager_scaffold.dart';
import '../data/users_repository.dart';

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
      body: users.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load users: $err'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(usersListProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) => _UserCard(user: list[index]),
        ),
      ),
    );
  }
}

class _UserCard extends ConsumerWidget {
  const _UserCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: SwitchListTile(
        key: ValueKey<String>('active-${user.id}'),
        title: Text(user.email),
        subtitle: Text(user.role),
        value: user.active,
        onChanged: (v) async {
          await ref.read(usersRepositoryProvider).setActive(user.id, v);
          ref.invalidate(usersListProvider);
        },
      ),
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
