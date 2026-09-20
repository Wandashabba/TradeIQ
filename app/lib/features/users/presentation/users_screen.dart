import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show Icons, TextCapitalization;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/design/torch_scope.dart';
import '../../../core/format/person_label.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/console_frame.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../data/users_repository.dart';
import 'user_password_screen.dart';

/// USERS — who can sign in, in what role, and the one switch that changes it.
///
/// ```text
///   Users                                         [ ⟳ ]
///   Deactivating a user revokes sign-in immediately.
///   ┌── ACTIVE ────────┬── INACTIVE ─────────────┐
///   │               7  │                      2  │
///   └──────────────────┴─────────────────────────┘
///   ── Users                                 9 ───
///   [TM] Thandi Mokoena                    Active
///        Field agent · thandi@acme.test         ›
///   …
///   [ Add user ]
///   [ nav pill ]
/// ```
///
/// ## A row names a person
///
/// Every row is a [PersonRow]: initials on the `well` and never a photograph
/// (POPIA), the name as the title, the role and the sign-in address as the
/// reason line — and an account that was never given a name reads by its
/// address rather than by a UUID.
///
/// **Status is a word and a mark**, not a fill: `Active` is the on-target
/// circle and `Inactive` is the Oatmeal square, because deactivating somebody
/// is a decision and not a fault. The word is what a screen reader hears, and
/// it reaches the row's one semantics node through `trailingLabel`.
///
/// ## Why the verbs are in a sheet
///
/// Three verbs — reset a password, change a name, switch sign-in off — and one
/// of them is a toggle. A `Wrap` of them under every row is a worklist that
/// scrolls three times as far, and a toggle in a row's trailing slot is the
/// one arrangement `SoftRow` warns about. They live in the sheet the row
/// opens, where each keeps its own node.
///
/// ## The amber, counted
///
/// A tab root: Night paints the nav's active tab, and this route declines its
/// one content grant — nothing on a roster is armed. The sheets are where the
/// commits are, and a sheet extinguishes the route beneath it. Day and Veld
/// paint zero.
class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(usersListProvider);
    final role = ref.watch(sessionControllerProvider).value?.role;
    // Managers may list users, but creating and changing them (POST and
    // PATCH /users) is admin-only on the server, so only admins get controls.
    final canEdit = role == 'admin';

    return users.when(
      loading: () => _frame(
        context,
        ref,
        phase: 'loading',
        canEdit: canEdit,
        children: <Widget>[
          Skeleton(
            label: 'users',
            child: const SkeletonRows(count: 5, rowHeight: 80),
          ),
        ],
      ),
      error: (error, stack) => _frame(
        context,
        ref,
        phase: 'error',
        canEdit: canEdit,
        children: <Widget>[
          TorchErrorRegion(
            name: 'users',
            child: ErrorState(
              message: TorchErrorMessage.sanitise(error),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('users-retry'),
                label: 'Try again',
                onPressed: () => ref.invalidate(usersListProvider),
              ),
            ),
          ),
        ],
      ),
      data: (list) => _loaded(context, ref, list, canEdit: canEdit, role: role),
    );
  }

  /// The frame every phase is drawn in — **including the create control.**
  ///
  /// The control lives here and not in `_loaded` on purpose. Adding a user is
  /// `POST /users`; it does not depend on whether `GET /users` came back.
  /// Before the migration this was a `floatingActionButton` on the scaffold,
  /// outside the async section, and it survived every phase. Building it
  /// inside `_loaded` quietly took it away from the reader who needs it most:
  /// an admin on a bad connection whose roster 500s and who is then offered
  /// nothing but "Try again".
  ///
  /// `canEdit` still gates it — a non-admin never saw it and still does not.
  /// The amber is unchanged: a [TorchSecondaryButton] claims nothing.
  Widget _frame(
    BuildContext context,
    WidgetRef ref, {
    required String phase,
    required bool canEdit,
    required List<Widget> children,
  }) {
    return ConsoleFrame(
      phase: phase,
      active: ConsoleSlot.menu,
      header: TorchAppHeader(
        title: 'Users',
        facts: <String>[
          canEdit
              ? 'Deactivating a user revokes sign-in immediately.'
              : 'Only admins can add or change users.',
        ],
        trailing: TorchIconButton(
          key: const ValueKey<String>('users-refresh'),
          icon: Icons.refresh,
          semanticLabel: 'Refresh the user list',
          onPressed: () => ref.invalidate(usersListProvider),
        ),
      ),
      children: <Widget>[
        ...children,
        if (canEdit) ...<Widget>[
          const SizedBox(height: TiqSpace.s7),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TorchSecondaryButton(
              key: const ValueKey<String>('user-create'),
              label: 'Add user',
              onPressed: () => showCreateUserSheet(context),
            ),
          ),
        ],
      ],
    );
  }

  Widget _loaded(
    BuildContext context,
    WidgetRef ref,
    List<AppUser> list, {
    required bool canEdit,
    required String? role,
  }) {
    final gutter = context.skin.space.gutter;
    final active = list.where((u) => u.active).length;

    return _frame(
      context,
      ref,
      phase: list.isEmpty ? 'empty' : 'loaded',
      canEdit: canEdit,
      children: <Widget>[
        if (list.isNotEmpty) ...<Widget>[
          // A measured zero renders 0 and keeps its place: "nobody is
          // deactivated" is a fact a reader needs, and a tile that vanished
          // would change the cluster's shape between clients.
          StatCluster(
            key: const ValueKey<String>('users-counts'),
            semanticsLabel: 'Who can sign in',
            tiles: <StatTile>[
              StatTile(eyebrow: 'Active', value: active),
              StatTile(eyebrow: 'Inactive', value: list.length - active),
            ],
          ),
          SizedBox(height: context.skin.space.blockGap),
        ],

        SectionRule('Users', count: list.isEmpty ? null : list.length),
        const SizedBox(height: TiqSpace.s5),

        if (list.isEmpty)
          const EmptyState(
            key: ValueKey<String>('users-empty'),
            scope: EmptyScope.inPanel,
            headline: 'No users yet.',
            body: 'Add a user to give someone access to this client.',
          )
        else
          TorchBleed(
            extra: gutter * 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < list.length; i++)
                  _UserRow(
                    key: ValueKey<String>('user-${list[i].id}'),
                    user: list[i],
                    canEdit: canEdit,
                    actorRole: role,
                    last: i == list.length - 1,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The role in words. The raw key is what authorisation checks against, so it
/// is shown too — in the sheet, in mono, where a person can quote it back.
String roleWord(String role) => switch (role) {
  'field_agent' => 'Field agent',
  'manager' => 'Manager',
  'admin' => 'Administrator',
  _ => role,
};

class _UserRow extends StatelessWidget {
  const _UserRow({
    super.key,
    required this.user,
    required this.canEdit,
    required this.actorRole,
    required this.last,
  });

  final AppUser user;
  final bool canEdit;
  final String? actorRole;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final word = user.active ? 'Active' : 'Inactive';

    return PersonRow(
      // Named, the name is the title and "Field agent · address" the reason
      // line. Unnamed, the address is promoted — never a UUID.
      name: nonBlankName(user.displayName),
      role: roleWord(user.role),
      outlet: user.email,
      unknownLabel: user.email,
      // Hue, silhouette and word in one token. NOT `deactivated: true`: an
      // inactive account is one an admin has to be able to switch back on, and
      // `deactivated` makes the row unreachable.
      trailing: StatusChip(
        level: user.active ? StatusLevel.onTarget : StatusLevel.held,
        label: word,
      ),
      trailingLabel: word,
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      onTap: () => showUserSheet(
        context,
        user: user,
        canEdit: canEdit,
        actorRole: actorRole,
      ),
    );
  }
}

/// ONE USER'S VERBS, in the one modal container.
///
/// **Two panes, one sheet.** Editing a name used to pop this sheet and open
/// another; `showTorchSheet` asserts on that, and it is right to — two scrims
/// is two dimmings of the same screen and the back gesture stops meaning
/// anything. Unify §1.10's answer is that a sheet which needs a sheet
/// cross-fades its own content, which is what [TorchSheetSwap] is for.
Future<void> showUserSheet(
  BuildContext context, {
  required AppUser user,
  required bool canEdit,
  required String? actorRole,
}) {
  return showTorchSheet<void>(
    context,
    builder: (_) =>
        _UserSheet(user: user, canEdit: canEdit, actorRole: actorRole),
  );
}

/// Which pane of the user sheet is showing.
enum _UserPane { verbs, editName }

class _UserSheet extends ConsumerStatefulWidget {
  const _UserSheet({
    required this.user,
    required this.canEdit,
    required this.actorRole,
  });

  final AppUser user;
  final bool canEdit;
  final String? actorRole;

  @override
  ConsumerState<_UserSheet> createState() => _UserSheetState();
}

class _UserSheetState extends ConsumerState<_UserSheet> {
  /// The id the name pane's commit claims under. The verbs pane has no
  /// commit at all — every action on it is a ghost or a toggle.
  static const String editNameClaimId = 'edit-name-save';

  _UserPane _pane = _UserPane.verbs;
  late bool _active = widget.user.active;
  bool _saving = false;
  TorchErrorMessage? _failure;

  late final TextEditingController _nameCtrl = TextEditingController(
    text: widget.user.displayName ?? '',
  );
  String? _nameError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _setActive(bool next) async {
    // Optimistic: the toggle moves on the tap, and stands back up if the
    // PATCH fails. A switch that waits for a round trip in a shop reads as a
    // switch that does not work.
    setState(() {
      _active = next;
      _saving = true;
      _failure = null;
    });
    try {
      await ref.read(usersRepositoryProvider).setActive(widget.user.id, next);
      ref.invalidate(usersListProvider);
      if (mounted) setState(() => _saving = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _active = !next;
        _saving = false;
        _failure = TorchErrorMessage.sanitise(error);
      });
    }
  }

  Future<void> _saveName() async {
    // The server trims before it measures, so surrounding spaces don't count.
    if (_nameCtrl.text.trim().length > displayNameMaxLength) {
      setState(
        () => _nameError = 'Use $displayNameMaxLength characters or fewer.',
      );
      return;
    }
    final next = nonBlankName(_nameCtrl.text);
    // Nothing changed: close without a request.
    if (next == nonBlankName(widget.user.displayName)) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await ref
          .read(usersRepositoryProvider)
          .updateDisplayName(widget.user.id, next);
      ref.invalidate(usersListProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      // Stay open so the typed name is not lost; say why in plain words.
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failure = TorchErrorMessage.sanitise(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final editing = _pane == _UserPane.editName;

    return TorchSheet(
      title: editing ? 'Edit name' : user.label,
      subtitle: editing ? user.email : roleWord(user.role),
      claims: editing && !_saving
          ? const <TorchClaim>[TorchClaim.primaryCommit(editNameClaimId)]
          : const <TorchClaim>[],
      child: TorchSheetSwap(
        paneKey: _pane.name,
        child: editing ? _editNamePane() : _verbsPane(),
      ),
    );
  }

  Widget _verbsPane() {
    final skin = context.skin;
    final user = widget.user;
    final maySetPassword = staffMaySetPasswordFor(widget.actorRole, user.role);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // The address they sign in with, and the role key authorisation
        // checks against: both machine-facing, both in the identifier face.
        _Fact(label: 'Signs in as', value: user.email),
        _Fact(label: 'Role key', value: user.role),

        SizedBox(height: skin.space.blockGap),

        if (widget.canEdit) ...<Widget>[
          TorchToggle(
            key: ValueKey<String>('active-${user.id}'),
            label: 'Can sign in',
            value: _active,
            onChanged: _saving ? null : _setActive,
            onWord: 'Active',
            offWord: 'Inactive',
            disabledReason: _saving ? 'Saving.' : null,
          ),
          const SizedBox(height: TiqSpace.s3),
          Text(
            'Switching this off revokes sign-in immediately.',
            style: skin.text.meta.style(color: skin.palette.ink3),
          ),
          const SizedBox(height: TiqSpace.s5),
          TorchSecondaryButton(
            key: ValueKey<String>('edit-name-${user.id}'),
            label: 'Edit name',
            onPressed: () => setState(() {
              _pane = _UserPane.editName;
              _failure = null;
            }),
          ),
          const SizedBox(height: TiqSpace.s3),
        ],

        // Reset password (#400): an admin for anyone, a manager for field
        // agents — the same rule the server applies, so the console never
        // offers a door that answers 403.
        if (maySetPassword)
          TorchSecondaryButton(
            key: ValueKey<String>('reset-password-${user.id}'),
            label: 'Reset password',
            semanticLabel: 'Reset the password for ${user.label}',
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/users/${user.id}/password', extra: user);
            },
          ),

        if (!widget.canEdit && !maySetPassword)
          const EmptyState(
            key: ValueKey<String>('user-read-only'),
            scope: EmptyScope.inline,
            headline: 'Nothing to change here.',
            body: 'Only an administrator can add or change users.',
          ),

        if (_failure != null) ...<Widget>[
          SizedBox(height: skin.space.intraBlock),
          TorchErrorRegion(
            name: 'user',
            child: ErrorState(
              key: ValueKey<String>('active-error-${user.id}'),
              scope: ErrorScope.inline,
              message: _failure!,
            ),
          ),
        ],
      ],
    );
  }

  Widget _editNamePane() {
    final skin = context.skin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TorchTextField(
          key: const ValueKey<String>('edit-name-field'),
          label: 'Name',
          controller: _nameCtrl,
          error: _nameError,
          help: 'Leave blank to clear the name; the address is shown instead.',
          textCapitalization: TextCapitalization.words,
          onChanged: (_) {
            if (_nameError != null) setState(() => _nameError = null);
          },
          onSubmitted: (_) => _saving ? null : _saveName(),
        ),
        if (_failure != null) ...<Widget>[
          SizedBox(height: skin.space.intraBlock),
          TorchErrorRegion(
            name: 'edit name',
            child: ErrorState(
              key: const ValueKey<String>('edit-name-error'),
              scope: ErrorScope.inline,
              message: _failure!,
            ),
          ),
        ],
        SizedBox(height: skin.space.blockGap),
        TorchPrimaryButton(
          key: const ValueKey<String>('edit-name-save'),
          claimId: editNameClaimId,
          label: 'Save the name',
          busy: _saving,
          onPressed: _saving ? null : _saveName,
          blockedReason: _saving ? 'Saving.' : null,
        ),
        const SizedBox(height: TiqSpace.s2),
        TorchSecondaryButton(
          key: const ValueKey<String>('edit-name-cancel'),
          label: 'Cancel',
          onPressed: _saving
              ? null
              : () => setState(() {
                  _pane = _UserPane.verbs;
                  _failure = null;
                  _nameError = null;
                }),
        ),
      ],
    );
  }
}

/// One machine-facing fact: the words left, the identifier right.
class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Padding(
      padding: const EdgeInsets.only(bottom: TiqSpace.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: skin.text.meta.style(color: skin.palette.ink3),
            ),
          ),
          const SizedBox(width: TiqSpace.s3),
          Expanded(
            child: Text(
              value,
              style: skin.text.monoIdent.style(color: skin.palette.ink1),
            ),
          ),
        ],
      ),
    );
  }
}

/// ADD A USER.
Future<void> showCreateUserSheet(BuildContext context) {
  return showTorchSheet<void>(
    context,
    builder: (_) => const _CreateUserSheet(),
  );
}

class _CreateUserSheet extends ConsumerStatefulWidget {
  const _CreateUserSheet();

  @override
  ConsumerState<_CreateUserSheet> createState() => _CreateUserSheetState();
}

class _CreateUserSheetState extends ConsumerState<_CreateUserSheet> {
  static const String commitClaimId = 'create-user';

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  String _role = 'field_agent';
  bool _submitting = false;
  String? _emailError;
  String? _passwordError;
  TorchErrorMessage? _failure;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final emailBlank = _emailCtrl.text.trim().isEmpty;
    // The server's one rule (#400) — creating a user and changing a password
    // must agree, and the console used to say nothing until after the request.
    final passwordShort = _passwordCtrl.text.length < 12;
    if (emailBlank || passwordShort) {
      setState(() {
        _emailError = emailBlank ? 'A user signs in with an address.' : null;
        _passwordError = passwordShort
            ? 'At least 12 characters. Three ordinary words work.'
            : null;
      });
      return;
    }

    setState(() {
      _submitting = true;
      _failure = null;
    });
    try {
      await ref
          .read(usersRepositoryProvider)
          .createUser(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
            role: _role,
            // Optional: left blank, the console shows the address instead.
            displayName: nonBlankName(_nameCtrl.text),
          );
      ref.invalidate(usersListProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _failure = createFailureMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return TorchSheet(
      title: 'Add user',
      subtitle: 'Someone who can sign in to this client.',
      claims: _submitting
          ? const <TorchClaim>[]
          : const <TorchClaim>[TorchClaim.primaryCommit(commitClaimId)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TorchTextField(
            key: const ValueKey<String>('new-name'),
            label: 'Name',
            controller: _nameCtrl,
            help: 'Optional. Shown instead of the address.',
            maximumLength: displayNameMaxLength,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: TiqSpace.s5),
          TorchTextField(
            key: const ValueKey<String>('new-email'),
            label: 'Email',
            controller: _emailCtrl,
            error: _emailError,
            identifier: true,
            autocorrect: false,
            textCapitalization: TextCapitalization.none,
            onChanged: (_) {
              if (_emailError != null) setState(() => _emailError = null);
            },
          ),
          const SizedBox(height: TiqSpace.s5),
          TorchTextField(
            key: const ValueKey<String>('new-password'),
            label: 'Password',
            controller: _passwordCtrl,
            error: _passwordError,
            obscureText: true,
            autocorrect: false,
            textCapitalization: TextCapitalization.none,
            help: 'At least 12 characters. Three ordinary words work.',
            onChanged: (_) {
              if (_passwordError != null) {
                setState(() => _passwordError = null);
              }
            },
          ),
          const SizedBox(height: TiqSpace.s5),
          ChoiceRow<String>(
            key: const ValueKey<String>('new-role'),
            label: 'Role',
            value: _role,
            options: const <ChoiceOption<String>>[
              ChoiceOption<String>(
                value: 'field_agent',
                label: 'Field agent',
                consequence: 'Visits stores and captures work.',
              ),
              ChoiceOption<String>(
                value: 'manager',
                label: 'Manager',
                consequence: 'Reads the console and closes tasks.',
              ),
              ChoiceOption<String>(
                value: 'admin',
                label: 'Administrator',
                consequence: 'Everything a manager can do, plus users and '
                    'scoring config.',
              ),
            ],
            onChanged: (value) => setState(() => _role = value),
          ),

          if (_failure != null) ...<Widget>[
            SizedBox(height: skin.space.intraBlock),
            TorchErrorRegion(
              name: 'create user',
              child: ErrorState(
                key: const ValueKey<String>('create-user-error'),
                scope: ErrorScope.inline,
                message: _failure!,
              ),
            ),
          ],

          SizedBox(height: skin.space.blockGap),
          TorchPrimaryButton(
            key: const ValueKey<String>('create-user'),
            claimId: commitClaimId,
            label: 'Create the user',
            busy: _submitting,
            onPressed: _submitting ? null : _create,
            blockedReason: _submitting ? 'Creating.' : null,
          ),
          const SizedBox(height: TiqSpace.s2),
          TorchSecondaryButton(
            key: const ValueKey<String>('create-user-cancel'),
            label: 'Cancel',
            onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// Why a create failed, in words a person can act on.
///
/// A 400 or 409 carries the server's own sentence — the password rule, a
/// duplicate address — which states the rule and never echoes what was typed
/// (#400). Anything else takes the sanitised copy: a message that is sometimes
/// an exception is a message that will one day carry a host name into a
/// screenshot.
TorchErrorMessage createFailureMessage(Object? error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    final body = error.response?.data;
    if ((status == 400 || status == 409) &&
        body is Map &&
        body['error'] is String) {
      return TorchErrorMessage(
        kind: TorchErrorKind.rejected,
        headline: 'The user was not created.',
        body: body['error'] as String,
        offersRetry: false,
      );
    }
  }
  return TorchErrorMessage.sanitise(error);
}
