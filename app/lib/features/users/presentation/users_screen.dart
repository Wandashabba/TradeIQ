import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/person_label.dart';
import '../../../core/network/human_error.dart';
import '../../../core/theme/tiq_colors.dart';
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
          Text(
            'Deactivating a user revokes sign-in immediately.',
            style: TextStyle(fontSize: 12, color: context.colors.ink3),
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
    final name = nonBlankName(user.displayName);
    return WorklistRow(
      // The name when there is one; accounts without a name still read by email.
      title: user.label,
      // The role string is what the API stores and what authorisation checks
      // against, so it is shown verbatim in mono — not prettified.
      meta: Row(
        children: [
          // A named user's email moves to the supporting line: it is still
          // what they sign in with, so it stays on the page.
          if (name != null) ...[
            Flexible(
              child: Text(
                user.email,
                key: ValueKey<String>('email-${user.id}'),
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(child: CodeToken(user.role)),
        ],
      ),
      level: user.active ? StatusLevel.good : StatusLevel.neutral,
      statusLabel: user.active ? 'Active' : 'Inactive',
      resolved: !user.active,
      actions: [
        IconButton(
          key: ValueKey<String>('edit-name-${user.id}'),
          tooltip: 'Edit name',
          icon: Icon(Icons.edit_outlined, color: context.colors.ink2),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => _EditNameDialog(user: user),
          ),
        ),
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

/// Sets, changes or clears one user's display name. Styled by the app's dialog
/// theme, which is glass by day and by night.
class _EditNameDialog extends ConsumerStatefulWidget {
  const _EditNameDialog({required this.user});

  final AppUser user;

  @override
  ConsumerState<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends ConsumerState<_EditNameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl =
      TextEditingController(text: widget.user.displayName ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    // The server trims before it measures, so surrounding spaces don't count.
    if ((value ?? '').trim().length > displayNameMaxLength) {
      return 'Use $displayNameMaxLength characters or fewer.';
    }
    return null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final next = nonBlankName(_nameCtrl.text);
    // Nothing changed: close without a request.
    if (next == nonBlankName(widget.user.displayName)) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(usersRepositoryProvider)
          .updateDisplayName(widget.user.id, next);
      ref.invalidate(usersListProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      // Stay open so the typed name is not lost; say why in plain words.
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save the name. ${humanErrorMessage(e)}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AlertDialog(
      title: const Text('Edit name'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.user.email,
              style: TextStyle(fontSize: 12, color: colors.ink3),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey<String>('edit-name-field'),
              controller: _nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: _validate,
              onFieldSubmitted: (_) => _saving ? null : _save(),
              decoration: const InputDecoration(
                labelText: 'Name',
                helperText: 'Leave blank to clear the name; the email is '
                    'shown instead.',
                helperMaxLines: 2,
                errorMaxLines: 2,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const ValueKey<String>('edit-name-error'),
                style: TextStyle(fontSize: 13, color: colors.critText),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey<String>('edit-name-cancel'),
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey<String>('edit-name-save'),
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
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
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _role = 'field_agent';
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
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
            // Optional: left blank, the console shows the email instead.
            displayName: nonBlankName(_nameCtrl.text),
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
            key: const ValueKey<String>('new-name'),
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Name',
              helperText: 'Optional. Shown instead of the email.',
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
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
